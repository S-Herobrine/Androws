# androws-brokerd
CC      ?= cc
CFLAGS  ?= -O2 -std=c11 -Wall -Wextra -Wno-unused-result
PREFIX  ?= /usr
BIN      = androws-brokerd

all: $(BIN)

$(BIN): androws-brokerd.c
	$(CC) $(CFLAGS) -o $@ $<

install: $(BIN)
	install -Dm0755 $(BIN) $(DESTDIR)$(PREFIX)/bin/$(BIN)

clean:
	rm -f $(BIN)
