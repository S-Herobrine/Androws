# Where apps come from

This is the part of Androws that cannot be solved by engineering, so it is written
down plainly rather than promised away.

## Google Play Store: cannot be preinstalled, can be added by you

The Play Store and Google Play services are not open source and are not
redistributable. Shipping them inside an image requires a Mobile Application
Distribution Agreement with Google, which requires the device to pass Google's
compatibility test suite and be certified. An independent project cannot sign that
agreement, and bundling the binaries without it is straightforward copyright
infringement. No custom ROM ships them for this reason; they are always a separate
package the user flashes.

Androws follows the same pattern. Three options, in the order most people should try
them:

| Option | What you get | What it costs |
|---|---|---|
| **Aurora Store** | A different client that downloads the same apps from Google's servers | No Play services, so apps needing them still fail |
| **microG** | Open reimplementation of Play services APIs | Many apps work, some still detect the difference |
| **Your own GApps package** | The real Play Store and services | ~180 MiB, which a 1 GB device does not have; needs `normal` profile hardware |

`tools/add-gapps.sh` installs a GApps package *you* supply into the Droid runtime, the
same way the build takes a GSI you supply. It does not download one for you.

## Microsoft Store: not possible, and not for licensing reasons

The Microsoft Store is a UWP application. UWP depends on the Windows runtime, AppX
deployment, and the Windows kernel's app container model. Wine implements Win32, not
UWP. There is no version of Androws, or of Wine, or of any compatibility layer, that
runs the Microsoft Store. Anyone claiming otherwise is describing something else.

What actually works for Windows software:

* **Direct installers.** Download an `.exe` or `.msi` and run it. This is how most
  Windows software outside the Store is distributed anyway.
* **Winetricks and Bottles** for the runtimes that installers expect.
* **The WineHQ application database** tells you, per program and per version, whether
  it runs and how well, before you spend storage on it.

## Microsoft services do work, through the other side

Outlook, OneDrive, Word, Excel, PowerPoint, Teams and Edge all ship as Android apps,
and Android apps are a first-class citizen here. On a 1 GB device the Android versions
are also far smaller than the Windows ones. Microsoft 365 in the browser is the other
route and costs nothing but the browser.

So the honest summary: **Microsoft services yes, Microsoft Store no. Google apps yes if
you install them yourself, Google Play Store not preinstalled.**
