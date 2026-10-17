# Contributing

DesktopLine is a small AppKit app. Keep it small and keep the desktop calm.

## Build

Use an existing Xcode or Command Line Tools installation on macOS:

```sh
zsh build.sh
./桌面一句.app/Contents/MacOS/DesktopLine --self-test
```

The build targets macOS 14 or later on the current host architecture. Set
`DESKTOPLINE_ARCH=arm64` or `DESKTOPLINE_ARCH=x86_64` to compile another slice.
Cross-compilation does not replace running it on that architecture.

## Behavior to preserve

- Locked desktop text passes all mouse events through to the desktop.
- No window chrome, opaque background, outline, or window shadow.
- Normal application windows cover the text.
- Closing preferences locks the overlay and releases its editing controls.
- Older settings files migrate without discarding a user's sentence or position.
- Loading a position preset preserves the current sentence and color.
- Use full-screen coordinates for stored anchors; Dock visibility must not move them.
- No network requests, telemetry, background polling, or third-party runtime.

Run the checks after changing placement, settings migration, or preset behavior.
For interface changes, also inspect the two preference tabs and desktop overlay
on an actual Mac. Multi-display layouts and lock-screen alignment need real
visual checks; passing a geometry test alone does not prove pixel-perfect alignment.

Do not commit application bundles, generated archives, personal settings,
installation ledgers, or credentials. Keep screenshot and quote credits intact.
