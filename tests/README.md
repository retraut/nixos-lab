# Notification click checks

Run the handler regression tests without touching the desktop:

```sh
node tests/notifications.test.cjs
```

The tests execute the functions extracted from `Notifications.qml` against
notification/model mocks. They cover sender-specific default actions, resident
notifications, synchronous close callbacks, replacement, eviction and Clear All.
They do not verify compositor focus or pointer hit testing.

After manually activating the configuration, open two separate Ghostty windows.
In window A, run the following and focus window B before the delay finishes:

```sh
sleep 3; printf '\033]777;notify;Window A;Notification from terminal A\007'
```

Click the notification body: window A must receive keyboard focus and the entry
must disappear from both the popup and history. Repeat from window B while A is
focused. Also test clicking an entry in the notification center after its popup
times out; the center must close and the originating window must receive focus.
The `×` button must only dismiss, without activating the sender.

Ghostty's native notification action identifies its originating surface:
[Ghostty 1.3.1 implementation](https://github.com/ghostty-org/ghostty/blob/v1.3.1/src/apprt/gtk/class/surface.zig#L1578).
The Hyprland rule permits activation requests for Ghostty and the configured
Ghostty-based launchers, including other explicit activation requests they make.
It does not enable focus-on-activate globally.

Plain `notify-send` does not identify the originating terminal window or provide
a default action automatically. Such notifications are dismissed on click; the
shell no longer guesses a different terminal by its title or focus history.
For a notification from a shell job in Ghostty, use the terminal escape sequence
above so Ghostty can supply the exact surface action.
