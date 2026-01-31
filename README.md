# VR Stack Control v0.6.21

This release replaces your old `vr-control --gui` YAD UI with a GTK GUI.

## Install

```bash
pkill -9 -f "vr-control --gui" 2>/dev/null || true
pkill -9 -f yad 2>/dev/null || true

cd ~/Downloads
unzip -o vr-stack-control-v0.6.21.zip
cd vr-stack-control-v0.6.21
bash install.sh
```

## Run

```bash
vr-control --gui
```

## What’s new

- `vr-control --gui` now opens the GTK GUI
- Profiles page: create / rename / delete / edit profiles
- Removed the old “Actions” tab (Start/Stop + settings cover most use-cases)
- Apps & Settings page includes inline “why this matters” help text

Note: Tray integration was removed in v0.6.21. Closing the window exits normally.
