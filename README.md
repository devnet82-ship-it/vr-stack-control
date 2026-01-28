# VR Stack Control

**Current version:** v0.3.2

A small, modular **Linux VR stack launcher + control panel** that manages your VR session using **systemd --user**.

It’s designed for stacks like:

- **Tracking**: SlimeVR (or any other tracker)
- **Server**: WiVRn (or any other streaming/server component)
- **VR app**: WayVR (or any OpenXR client)

…but it’s not hard-coded to any one setup — you pick what to run from the GUI.

## What this does

- **Tabbed GUI** (Control / Apps / Profiles / Debug)

- Starts your chosen apps in the right order: **Tracking → Server → VR app**
- Stops everything cleanly (no orphan processes)
- Optional **autostart on login** (enable/disable from the GUI)
- Shows useful debug info and can generate a “debug bundle”

## What this does NOT do

- It **does not** install or ship SlimeVR / WiVRn / WayVR / APKs / AppImages.
- It **does not** change your system globally (no root services).
- It **does not** require SteamVR/Monado — it just launches what you choose.

## Requirements

- Linux desktop with a user session (Wayland or X11)
- `systemd --user` (standard on Arch/CachyOS/Fedora/etc.)
- `yad` (GUI)
- `ripgrep` (`rg`) for scanning `.desktop` apps

Optional:
- `xclip` for “Copy debug bundle to clipboard”

### Arch/CachyOS install deps

```bash
sudo pacman -S --needed yad ripgrep
# optional:
sudo pacman -S --needed xclip
```

## Install (casual repo style)

Clone and run:

```bash
git clone <your-repo-url>
cd vr-stack-control
./install.sh
```

Then open your app launcher and run **“VR Control Panel”**.

## Usage

## Tray icon (optional)

Launch **“VR Tray (VR Stack Control)”** from your app launcher to get a tray icon with quick actions:

- Open Control Panel
- Start/Stop/Restart VR
- Toggle autostart
- Show logs
- Quest + WiVRn status
- Start/Stop Quest+WiVRn watcher

## Profiles

Profiles are stored in:

- `~/.config/vr-stack/profiles/*.conf`

The currently active profile is a symlink:

- `~/.config/vr-stack/stack.conf -> ~/.config/vr-stack/profiles/<profile>.conf`

This makes switching setups (different trackers, different servers) fast and reproducible.

## Quest + WiVRn auto-detect (optional)

- Quest detection uses **ADB** (`android-tools`)
- WiVRn “connected” detection is heuristic by scanning recent logs (configurable regex)

Arch/CachyOS optional deps:

```bash
sudo pacman -S --needed android-tools libnotify
```


- **Set Tracking app…** pick a tracker (or “None”)
- **Set Server app…** pick a server (or “None”)
- **Set VR app…** pick your OpenXR client (or “None”)
- **Save config** to write `~/.config/vr-stack/stack.conf`
- **Start VR / Stop VR** controls the systemd user service

### Autostart on login

In the GUI, choose **Toggle autostart**.
Under the hood it runs:

```bash
systemctl --user enable vr-stack-control.service
# or disable
systemctl --user disable vr-stack-control.service
```

## Files installed to your home directory

- `~/bin/vr-control-gui.sh`
- `~/bin/vr-stack-run.sh`
- `~/.config/systemd/user/vr-stack-control.service`
- `~/.local/share/applications/vr-control-panel.desktop`
- `~/.config/vr-stack/stack.conf` (created/edited by you)

## Logs

- Service logs:  
  ```bash
  journalctl --user -u vr-stack-control.service -f
  ```
- Runner log:
  `~/.local/share/vr-stack.log`

## Uninstall

```bash
./uninstall.sh
```

## License

MIT (see `LICENSE`).


## Tray icon service

The tray icon can run as a **systemd --user** service:

- Start: `systemctl --user start vr-stack-tray.service`
- Stop: `systemctl --user stop vr-stack-tray.service`
- Autostart: `systemctl --user enable vr-stack-tray.service`
- Disable autostart: `systemctl --user disable vr-stack-tray.service`

The Control Panel also includes tray controls.