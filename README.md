# Evidence: clicking a notification goes to its window

Screenshots and the live harness behind the "clicking a notification does not go
to the window" fix (branch `fix/notification-focus-follow`).

- `1-banner.png`: workspace 8 on screen; Ghostty window G (hidden on workspace 7) posts a notification.
- `2-before-window-stays-hidden.png`: `dev` build. Ghostty is frontmost, but workspace 8 stays and G stays hidden (the follow was cancelled and suppressed).
- `3-before-focus-on-remembered-tile.png`: `dev` build. Workspace 7 is shown, but focus goes to R (its remembered tile), not G.
- `4-after-window-shown-and-focused.png`: fixed build. Workspace 7 is shown and G is focused.
- `5-after-race-recovered.png`: fixed build, in a run where the race fired; the follow retried and G is shown and focused.

`harness/live-notify.sh <variant>` runs a built `spaceman-agent` from `<variant>/` against an
isolated `SPACEMAN_APPLICATION_SUPPORT` with disposable windows only. Stop any other window
manager (including an installed Spaceman) first.
