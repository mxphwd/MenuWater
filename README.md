Lightweight menu bar water reminder for macOS.

Built for those who keep forgets to drink water during the day.

Features:
+ Built natively for Apple Silicon
+ Very lightweight (500KB)
+ ~~Option to auto start at login~~

Built and tested on macOS 26 Golden Gate. Xcode distribution target is set to macOS 14.6 Sonoma or higher, and is tested on Sonoma. Although it is built as universal package (both Apple Silicon and Intel), it is not tested on Intel-based Macs and therefore your usage may vary.

Before start using MenuWater, navigate to **Options** under the drop down menu to set you age and gender. The daily goal will be set according to how much a person your age should be drinking a day.

## Setup guide

1. Download the [latest release](https://github.com/mxphwd/MenuWater/releases/).
2. Extract the .zip file and move the .app file to Applications folders or whichever folder you are comfortable running the application in.
3. Double-click the .app file to open.
4. Click "OK" to dismiss the warning.
5. Open **System Settings** and navigate to **Privacy & Security**
6. Scroll down to find the section stating ""MenuWater" was blocked to protect your Mac".
7. Click **Open Anyway**
8. Authenticate using Touch ID or your Mac password.

## Known issues

+ There is a known bug that, in certain cases, having the "Start at login" option on may result in MenuWater crashing, leaving the icon visible on the menu bar but not open when clicked on. You can relaunch MenuWater by force quitting the application from the Force Quit menu(Opt+Cmd+Esc). The start at login option is therefore disabled by default to prevent this problem.
+ Users on macOS 27 Golden Gate using [HiddenBar](https://github.com/dwarvesf/hidden) may experience the menu bar icon disappearing as HiddenBar hides selected applications, even if MenuWater is specifically selected to be not hidden. This is a problem caused by new behavior macOS handles menu bar combined with updated HiddenBar to still provide the hiding feature. Although not tested, users on macOS 26 Tahoe or older will probably have no problem with this.

Feel free to add more issues as you find them

## Update log

**v1.0.1**
+ Full-screen mode added.
