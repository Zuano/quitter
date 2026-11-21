# Quitter

macOS menu bar app that quits selected apps after they have been in the background for a configurable number of minutes (a clean quit, like Cmd+Q).

Originally built to close **Epson Scan 2** automatically; pairs with [Epson Scan Opener](https://github.com/Zuano/epson-scan-opener).

## Recommended setting for Epson Scan 2
Set the timeout for Epson Scan 2 **shorter than your scanner's standby time** (e.g. 10 minutes if the scanner goes to standby after ~13 minutes). If the scanner falls asleep first, Epson Scan 2 shows an error dialog and ignores the quit request, so it stays open.

## Build
1. Open `Quitter.xcodeproj` in Xcode (macOS 13+).
2. Create `Signing.local.xcconfig` next to the project with `DEVELOPMENT_TEAM = <your Team ID>` (or pick your team in Xcode).
3. Build & run, then add apps and timeouts in the settings.

## License
MIT
