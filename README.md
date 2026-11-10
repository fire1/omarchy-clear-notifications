# Notifications menu for Omarchy

A bar widget for [Omarchy](https://omarchy.org) that puts a notification bell
between your other status icons. Click it for a dropdown to clear, dismiss,
replay history, invoke the last toast, or silence popups.

## Install

```bash
omarchy plugin add https://github.com/fire1/omarchy-clear-notifications.git --enable
```

Then place it on the bar if it is not already there:

```bash
omarchy bar put fire1.clear-notifications --after omarchy.keyboard-layout
```

## Use

| Input | Action |
| --- | --- |
| Left-click | Open the notifications menu |
| Right-click | Clear all active notifications |
| Middle-click | Toggle silence (do not disturb) |

Menu actions:

- **Clear all** — dismiss every active toast
- **Dismiss newest** — clear only the top notification
- **Show history** — replay recent notifications
- **Invoke last** — run the default action on the newest toast
- **Silence notifications** — hide new popups until turned off

## Remove

```bash
omarchy plugin remove fire1.clear-notifications --yes
```

## Requirements

- Omarchy with the built-in `omarchy.notifications` shell service
- No extra packages

## License

MIT
