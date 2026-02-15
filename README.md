# VR Stack Control v0.6.85

## Install

```bash
pkill -9 -f "vr-control --gui" 2>/dev/null || true
pkill -9 -f yad 2>/dev/null || true

cd ~/Downloads
unzip -o vr-stack-control-v0.6.53.zip
cd vr-stack-control-v0.6.53
bash install.sh
```

## Run

```bash
vr-control --gui
```

## What’s new

- Tracking backend ON/OFF toggle (start stack with or without tracking software like SlimeVR)
- `vr-control --gui` now opens the GTK GUI
- Profiles page: create / rename / delete / edit profiles
- Removed the old “Actions” tab (Start/Stop + settings cover most use-cases)
- Apps & Settings page includes inline “why this matters” help text

Note: Tray integration was removed in v0.6.30. Closing the window exits normally.

## v0.6.53 change

- Apps & Settings now shows **Detected paths (read-only)** so you can verify where OpenXR / SteamVR / XRizer are found.


## Tracking backend toggle

You can enable/disable tracking independently of the rest of the stack.

- ON: tracking starts first (before the server and VR app)
- OFF: the stack starts without tracking

Config keys (in `~/.config/vr-stack/stack.conf`):


# WI VRN + WAYVR + SLIMEVR ON CACHYOS (QUEST 3)
COMPLETE FIRST-TIME SETUP GUIDE

This is the exact process that was followed to get a fully working
WiVRn + WayVR + SlimeVR setup on CachyOS using a Quest 3.

Nothing here is theoretical.
Every command listed below was actually run.

Follow every step in order.
Do not skip steps.


WHAT YOU END UP WITH

- Quest 3 connects wirelessly to the PC
- WayVR runs without OpenXR errors
- SlimeVR body tracking works
- No duplicate launches
- Correct OpenXR runtime every time

Final stack order:

SlimeVR (SolarXR IPC)
WiVRn OpenXR runtime
WiVRn server
Quest WiVRn APK
WayVR


REQUIREMENTS

- CachyOS (Wayland session)
- Meta Quest 3
- USB cable (one-time setup)
- PC and Quest on the same Wi-Fi
- Internet access


## PART 1 — INSTALL PC SOFTWARE

Run exactly:

```bash
yay -S wivrn-full-git
sudo pacman -S wayvr slimevr android-tools github-cli
```

This installs:

- WiVRn server (working AUR build)
- WayVR compositor
- SlimeVR server
- ADB (for Quest)
- GitHub CLI (for APK download)


VERIFY COMMANDS EXIST (DO NOT SKIP)

```bash
command -v wayvr
command -v wivrn-server
command -v slimevr
```

If any command is missing, stop and fix it before continuing.


## PART 2 — QUEST DEVELOPER MODE + ADB

Enable developer mode (phone):

Meta Quest app
Devices → Quest 3
Developer Mode → ON

Reboot the headset.


Enable USB debugging (headset):

Settings → System → Developer
Enable USB Debugging


Connect Quest to PC:

```bash
adb kill-server
adb start-server
adb devices
```

Inside the headset:
- Accept USB debugging
- Tick Always allow

Verify again:

```bash
adb devices
```

Expected output:

XXXXXXXXXXXX    device

If not, stop and fix before continuing.


## PART 3 — DOWNLOAD AND INSTALL QUEST APK

Login to GitHub CLI:

```bash
gh auth login
gh auth status
```

You must see:
Logged in to github.com


Download WiVRn Quest APK (GitHub Actions build)

Example run ID used:
21321590049

```bash
gh run download 21321590049 --repo WiVRn/WiVRn --name apk-Release
```

Extract:

```bash
unzip -o *.zip
ls *.apk
```

You must see exactly one APK.


Install APK to Quest:

Inside headset:
Settings → Apps → WiVRn → Uninstall
Reboot headset

Install:

```bash
adb install -r *.apk
```

Expected output:
Success

Verify:

```bash
adb shell pm list packages | grep -i wivrn
```

Expected:
package:org.wivrn.client


REQUIRED QUEST SETTING (SLIMEVR USERS)

Inside Quest WiVRn app:
- Disable Enable body tracking
- Let SlimeVR / SolarXR provide tracking


## PART 4 — FIX OPENXR RUNTIME (CRITICAL STEP)

Run:

```bash
mkdir -p ~/.config/openxr/1
ln -sf /usr/share/openxr/1/openxr_wivrn.json ~/.config/openxr/1/active_runtime.json
```

Verify:

```bash
readlink -f ~/.config/openxr/1/active_runtime.json
```

It must output:
/usr/share/openxr/1/openxr_wivrn.json

If it does not, stop and fix before continuing.


RESULT

At this point you have:

- Correct OpenXR runtime (WiVRn)
- WiVRn server running correctly
- Quest APK matched to the server
- WayVR launching cleanly
- SlimeVR providing trackers properly

This is the exact configuration that worked.



```bash
tracking_enabled='true'
tracking_stop_when_disabled='true'
```
