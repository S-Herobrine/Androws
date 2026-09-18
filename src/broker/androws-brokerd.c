/*
 * androws-brokerd - the Androws runtime arbiter
 * Author: Saeed x Claude
 * License: MIT
 *
 * Androws targets 512 MB of RAM. Two guest runtimes (Droid and Win) cannot both be
 * resident. This daemon enforces one rule: exactly one runtime is thawed at a time.
 * The other is frozen with the cgroup v2 freezer and squeezed into zram by lowering
 * memory.high, which turns a ~300 MB world into ~15 MB of resident cost.
 *
 * It also watches /proc/pressure/memory and freezes early rather than letting the
 * kernel OOM killer pick a victim for us.
 *
 * No dependencies beyond libc. Speaks a line protocol on a unix socket:
 *
 *   FOCUS droid | FOCUS win | FOCUS none   -> OK <name>
 *   PROFILE low | normal | gaming          -> OK <name>
 *   STATE                                  -> STATE profile=<p> droid=<s>:<kb> win=<s>:<kb> psi=<n>
 *   PING                                   -> PONG
 *   QUIT                                   -> OK bye   (daemon exits)
 *
 * The profile decides how hard the arbiter squeezes. On a 512 MB machine the
 * background runtime is frozen the moment it loses focus. On a 2 GB machine it is
 * left warm and only touched under pressure. In gaming the background runtime is
 * frozen and reclaimed hard so the foreground keeps every page it can hold.
 */

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

#define CG_ROOT      "/sys/fs/cgroup/androws"
#define SOCK_PATH    "/run/androws/broker.sock"
#define PSI_PATH     "/proc/pressure/memory"

#define MB(x) ((unsigned long)(x) * 1024UL * 1024UL)

/* A profile is the whole memory policy in one struct. Everything the arbiter does
 * differently between a 512 MB netbook and a 4 GB gaming box lives here. */
struct profile {
	const char   *name;
	unsigned long hot_high;    /* memory.high for the runtime in front       */
	unsigned long bg_high;     /* memory.high for the runtime behind         */
	int           bg_freeze;   /* freeze the background runtime on switch?   */
	double        psi_trip;    /* 10s "some" pressure that forces a squeeze  */
	const char   *reclaim;     /* how much to claw back per pressure tick    */
};

static struct profile profiles[] = {
	/* name      hot_high   bg_high  freeze  psi   reclaim  */
	{ "low",     MB(360),   MB(24),   1,     25.0, "16M\n" },
	{ "normal",  MB(1200),  MB(320),  0,     40.0, "32M\n" },
	{ "gaming",  MB(3072),  MB(16),   1,     60.0, "64M\n" },
};
#define N_PROFILES ((int)(sizeof(profiles) / sizeof(profiles[0])))

enum rt_id { RT_DROID = 0, RT_WIN = 1, RT_COUNT = 2 };

struct runtime {
	const char *name;
	char        cgroup[128];
	int         thawed;
	int         present;
};

static struct runtime rts[RT_COUNT] = {
	{ .name = "droid" },
	{ .name = "win"   },
};

static volatile sig_atomic_t running = 1;
static int current_focus = -1;   /* index of the hot runtime, -1 for none */
static struct profile *prof = &profiles[0];   /* low until told otherwise */

static void on_signal(int sig) { (void)sig; running = 0; }

static void logline(const char *fmt, ...)
{
	va_list ap;
	fprintf(stderr, "brokerd: ");
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
	fputc('\n', stderr);
}

/* ---------- small cgroup helpers ---------- */

static int cg_write(const char *cgroup, const char *file, const char *val)
{
	char path[256];
	int fd, n;

	snprintf(path, sizeof(path), "%s/%s", cgroup, file);
	fd = open(path, O_WRONLY | O_CLOEXEC);
	if (fd < 0)
		return -1;
	n = (int)write(fd, val, strlen(val));
	close(fd);
	return n < 0 ? -1 : 0;
}

static long cg_read_long(const char *cgroup, const char *file)
{
	char path[256], buf[64];
	int fd;
	ssize_t n;

	snprintf(path, sizeof(path), "%s/%s", cgroup, file);
	fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		return -1;
	n = read(fd, buf, sizeof(buf) - 1);
	close(fd);
	if (n <= 0)
		return -1;
	buf[n] = '\0';
	return strtol(buf, NULL, 10);
}

static int cg_ensure(struct runtime *rt)
{
	if (mkdir(rt->cgroup, 0755) < 0 && errno != EEXIST) {
		logline("cannot create %s: %s", rt->cgroup, strerror(errno));
		rt->present = 0;
		return -1;
	}
	rt->present = 1;
	/* Swap must be allowed or a frozen runtime cannot be pushed into zram. */
	cg_write(rt->cgroup, "memory.swap.max", "max");
	return 0;
}

/* ---------- freeze / thaw ---------- */

static int focus(const char *name);

static void rt_freeze(struct runtime *rt)
{
	char high[32];

	if (!rt->present || !rt->thawed)
		return;

	snprintf(high, sizeof(high), "%lu\n", prof->bg_high);

	/* Order matters. Lowering memory.high first pushes anonymous pages into zram
	 * while the tasks can still run; freezing afterwards keeps them there. Doing
	 * it the other way round leaves the pages hot and the freeze saves nothing. */
	cg_write(rt->cgroup, "memory.high", high);
	usleep(120 * 1000);

	/* In a profile with room to spare the background runtime stays runnable; it
	 * just loses its claim on memory. Freezing it there would cost more in wake
	 * latency than it saves. */
	if (!prof->bg_freeze) {
		logline("backgrounded %s under %s, left warm", rt->name, prof->name);
		return;
	}

	cg_write(rt->cgroup, "cgroup.freeze", "1\n");
	rt->thawed = 0;
	logline("froze %s, resident now %ld kB", rt->name,
		cg_read_long(rt->cgroup, "memory.current") / 1024);
}

static void rt_thaw(struct runtime *rt)
{
	char high[32];

	if (!rt->present)
		return;

	snprintf(high, sizeof(high), "%lu\n", prof->hot_high);
	cg_write(rt->cgroup, "cgroup.freeze", "0\n");
	cg_write(rt->cgroup, "memory.high", high);

	rt->thawed = 1;
	logline("thawed %s", rt->name);
}

static int focus(const char *name)
{
	int i, target = -1;

	if (strcmp(name, "none") != 0) {
		for (i = 0; i < RT_COUNT; i++)
			if (strcmp(rts[i].name, name) == 0)
				target = i;
		if (target < 0)
			return -1;
	}

	/* Freeze everything else first so the thaw never races the reclaim. */
	for (i = 0; i < RT_COUNT; i++)
		if (i != target)
			rt_freeze(&rts[i]);
	if (target >= 0)
		rt_thaw(&rts[target]);
	current_focus = target;

	return 0;
}

/* ---------- pressure watch ---------- */

/* Returns the 10-second "some" average from /proc/pressure/memory, or -1. */
static double psi_some_avg10(void)
{
	char buf[256], *p;
	int fd;
	ssize_t n;

	fd = open(PSI_PATH, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		return -1.0;
	n = read(fd, buf, sizeof(buf) - 1);
	close(fd);
	if (n <= 0)
		return -1.0;
	buf[n] = '\0';

	p = strstr(buf, "avg10=");
	if (!p)
		return -1.0;
	return strtod(p + 6, NULL);
}

static void pressure_check(void)
{
	double psi = psi_some_avg10();
	int i, acted = 0;

	if (psi < prof->psi_trip)
		return;

	for (i = 0; i < RT_COUNT; i++) {
		if (!rts[i].present)
			continue;
		if (rts[i].thawed && i != current_focus) {
			/* Warm background runtimes are exactly what pressure is for:
			 * this is the moment they get put away, whatever the profile
			 * would have done on a quiet system. */
			int keep = prof->bg_freeze;
			prof->bg_freeze = 1;
			rt_freeze(&rts[i]);
			prof->bg_freeze = keep;
			acted = 1;
		} else if (!rts[i].thawed) {
			/* Already frozen: lean on it a little harder. */
			cg_write(rts[i].cgroup, "memory.reclaim", prof->reclaim);
			acted = 1;
		}
	}

	if (acted)
		logline("pressure avg10=%.1f, squeezed background runtimes", psi);
}

/* ---------- socket server ---------- */

static int set_profile(const char *name)
{
	int i;

	for (i = 0; i < N_PROFILES; i++) {
		if (strcmp(profiles[i].name, name) != 0)
			continue;
		prof = &profiles[i];
		logline("profile %s: hot %lu MiB, background %lu MiB, freeze %s, psi %.0f",
			prof->name, prof->hot_high >> 20, prof->bg_high >> 20,
			prof->bg_freeze ? "yes" : "no", prof->psi_trip);
		/* Re-apply immediately so a profile switch is felt now, not on the
		 * next app launch. */
		if (current_focus >= 0)
			focus(rts[current_focus].name);
		return 0;
	}
	return -1;
}

static void handle(int fd, const char *line)
{
	char out[256];
	int n = 0;

	if (strncmp(line, "FOCUS ", 6) == 0) {
		char name[32];
		snprintf(name, sizeof(name), "%.31s", line + 6);
		name[strcspn(name, " \r\n")] = '\0';
		n = focus(name) == 0 ? snprintf(out, sizeof(out), "OK %s\n", name)
				     : snprintf(out, sizeof(out), "ERR unknown runtime\n");
	} else if (strncmp(line, "PROFILE ", 8) == 0) {
		char name[32];
		snprintf(name, sizeof(name), "%.31s", line + 8);
		name[strcspn(name, " \r\n")] = '\0';
		n = set_profile(name) == 0 ? snprintf(out, sizeof(out), "OK %s\n", name)
					   : snprintf(out, sizeof(out), "ERR unknown profile\n");
	} else if (strncmp(line, "STATE", 5) == 0) {
		n = snprintf(out, sizeof(out),
			     "STATE profile=%s droid=%s:%ld win=%s:%ld psi=%.1f\n",
			     prof->name,
			     rts[0].thawed ? "hot" : "cold",
			     rts[0].present ? cg_read_long(rts[0].cgroup, "memory.current") / 1024 : 0L,
			     rts[1].thawed ? "hot" : "cold",
			     rts[1].present ? cg_read_long(rts[1].cgroup, "memory.current") / 1024 : 0L,
			     psi_some_avg10());
	} else if (strncmp(line, "PING", 4) == 0) {
		n = snprintf(out, sizeof(out), "PONG\n");
	} else if (strncmp(line, "QUIT", 4) == 0) {
		n = snprintf(out, sizeof(out), "OK bye\n");
		running = 0;
	} else {
		n = snprintf(out, sizeof(out), "ERR bad command\n");
	}

	if (n > 0)
		(void)!write(fd, out, (size_t)n);
}

static int serve_socket(void)
{
	struct sockaddr_un addr;
	int fd;

	fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
	if (fd < 0)
		return -1;

	memset(&addr, 0, sizeof(addr));
	addr.sun_family = AF_UNIX;
	snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", SOCK_PATH);
	unlink(SOCK_PATH);

	if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0 || listen(fd, 8) < 0) {
		close(fd);
		return -1;
	}
	chmod(SOCK_PATH, 0660);
	return fd;
}

int main(int argc, char **argv)
{
	struct pollfd pfd;
	int srv, i;

	(void)argc; (void)argv;
	signal(SIGINT, on_signal);
	signal(SIGTERM, on_signal);
	signal(SIGPIPE, SIG_IGN);

	mkdir("/run/androws", 0755);

	/* /etc/androws/profile is one word, written by androws-profile. */
	{
		FILE *f = fopen("/etc/androws/profile", "r");
		char name[32] = "low";
		if (f) {
			if (fscanf(f, "%31s", name) != 1)
				snprintf(name, sizeof(name), "low");
			fclose(f);
		}
		if (set_profile(name) < 0)
			logline("unknown profile '%s' on disk, staying on low", name);
	}

	mkdir(CG_ROOT, 0755);
	for (i = 0; i < RT_COUNT; i++) {
		snprintf(rts[i].cgroup, sizeof(rts[i].cgroup), "%s/%s", CG_ROOT, rts[i].name);
		cg_ensure(&rts[i]);
	}

	srv = serve_socket();
	if (srv < 0) {
		logline("cannot listen on %s: %s", SOCK_PATH, strerror(errno));
		return 1;
	}
	logline("ready, arbitrating droid and win on " CG_ROOT);

	pfd.fd = srv;
	pfd.events = POLLIN;

	while (running) {
		int r = poll(&pfd, 1, 2000);   /* 2s tick doubles as the pressure timer */

		if (r < 0 && errno != EINTR)
			break;
		if (r == 0) {
			pressure_check();
			continue;
		}
		if (pfd.revents & POLLIN) {
			char buf[256];
			int c = accept(srv, NULL, NULL);
			ssize_t n;

			if (c < 0)
				continue;
			n = read(c, buf, sizeof(buf) - 1);
			if (n > 0) {
				buf[n] = '\0';
				handle(c, buf);
			}
			close(c);
		}
	}

	close(srv);
	unlink(SOCK_PATH);
	logline("stopped");
	return 0;
}
