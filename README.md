# VR Stack Control (v0.6.85)

Linux GUI + systemd user service for running a modular VR stack:

**tracking → server → headset app → VR app**

Built to keep OpenXR and OpenVR switching reliable (especially when SteamVR likes to stick).

## Credits
- David Coates — idea, testing, real-world setup notes
- ChatGPT — implementation help + iteration

## Why this exists
VR on Linux can break when OpenXR and OpenVR state gets stuck:
- SteamVR leaves an OpenXR override behind
- OpenVR paths go missing or duplicate
- switching between WiVRn and SteamVR does not snap back

VR Stack Control makes switching predictable:
- WiVRn mode clears the user OpenXR override and makes sure Steam and SteamVR are closed
- SteamVR mode sets the user OpenXR override to SteamVR (when you choose SteamVR)
- OpenVR paths can be repaired and normalized when needed
- One button start and stop with correct ordering

---

## Install VR Stack Control (Release zip)

## Where to get the beta builds (WiVRn + SlimeVR)

These are the “beta/dev” sources we used on CachyOS for Quest 3.

### WiVRn (PC) — dev build
- Upstream repo: https://github.com/WiVRn/WiVRn
- Docs/site: https://wivrn.github.io/
- AUR (dev): https://aur.archlinux.org/packages/wivrn-full-git

### WiVRn (Quest / headset app)
**Option A (recommended):** WiVRn APK releases
- Releases: https://github.com/WiVRn/WiVRn-APK/releases
- Repo: https://github.com/WiVRn/WiVRn-APK

**Option B (what we did):** GitHub Actions “Build” artifact using \`gh\`
- Actions page: https://github.com/WiVRn/WiVRn/actions

### SlimeVR (PC) — beta build
- SlimeVR site: https://slimevr.dev/
- Server repo: https://github.com/SlimeVR/SlimeVR-Server
- AUR (beta): https://aur.archlinux.org/packages/slimevr-beta-bin

### WayVR
- Repo: https://github.com/wlx-team/wayvr
- AUR: https://aur.archlinux.org/packages/wayvr  (or dev: https://aur.archlinux.org/packages/wayvr-git)

### OpenVR compatibility (XRizer)
- Repo: https://github.com/Supreeeme/xrizer
- AUR: https://aur.archlinux.org/packages/xrizer-git
- AUR 32-bit: https://aur.archlinux.org/packages/lib32-xrizer-git

### VR Stack Control
- Repo: https://github.com/devnet82-ship-it/wivrn-stack-control
- Releases: https://github.com/devnet82-ship-it/wivrn-stack-control/releases

---


Download the v0.6.85 zip from GitHub Releases, then:

```bash
cd ~/Downloads
unzip -o vr-stack-control-v0.6.85*.zip -d vr-stack-control-v0.6.85
cd vr-stack-control-v0.6.85/*
chmod +x install.sh uninstall.sh bin/*
./install.sh
systemctl --user daemon-reload
```

## Run

```bash
vr-control --gui
```

## Tray (optional)
- Start tray once: `vr-control tray`
- Autostart tray: `vr-control tray-enable`
- Disable tray: `vr-control tray-disable`

## Doctor (sanity check)

```bash
vr-control doctor
```

Expected in WiVRn mode:
- OpenXR runtime name: Monado
- OpenXR library includes libopenxr_wivrn
- SteamVR processes: not running

---

# Quest 3 on CachyOS (Wayland)
## WiVRn (BETA) + SlimeVR (BETA) + WayVR using VR Stack Control

This is the setup that worked on CachyOS + Quest 3.
Use beta or dev builds for WiVRn and SlimeVR for this stack.

Final stack order (managed by VR Stack Control):
SlimeVR (beta) → WiVRn server → Quest WiVRn app → WayVR → game

## Requirements
- CachyOS (Wayland session)
- Meta Quest 3 (Developer Mode enabled)
- USB cable for one time ADB setup
- PC and headset on the same network
- Internet access (for AUR and GitHub artifacts)

---

## 1) Install PC software (beta and dev builds)

### 1.1 Install an AUR helper (if you do not have one)
If `yay` is missing:

```bash
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### 1.2 Remove stable packages (if installed)

```bash
sudo pacman -Rns wivrn-dashboard wivrn-server slimevr 2>/dev/null || true
```

### 1.3 Install WiVRn dev build + SlimeVR beta build

```bash
yay -S --needed wivrn-full-git slimevr-beta-bin
```

### 1.4 Install the rest

```bash
sudo pacman -S --needed wayvr android-tools github-cli
```

Verify:

```bash
command -v wivrn-server
command -v wayvr
command -v slimevr
```

---

## 2) OpenVR compatibility for SteamVR games (XRizer)

WiVRn warns if OpenVR compatibility is missing. Install XRizer:

```bash
yay -S --needed xrizer-git xrizer-common-git lib32-xrizer-git
```

Set VR_PATHREG_OVERRIDE in fish (universal):

```fish
set -Ux VR_PATHREG_OVERRIDE $HOME/.local/share/openvr/openvrpaths.vrpath
```

---

## 3) Set system OpenXR runtime to WiVRn (recommended)

VR Stack Control clears the user override when you select WiVRn.
To make WiVRn the default fallback, set the system runtime to WiVRn:

```bash
sudo mkdir -p /etc/openxr/1
sudo ln -sf /usr/share/openxr/1/openxr_wivrn.json /etc/openxr/1/active_runtime.json
```

---

## 10) ADB setup (Quest 3)

This was a real blocker during setup: first ADB was missing, then the device was unauthorized, then it became device.

### 10.1 Install ADB tools

```bash
sudo pacman -S --needed android-tools
adb version
```

### 10.2 Start ADB server and authorize Quest

```bash
adb kill-server
adb start-server
adb devices
```

On the Quest headset:
- Enable Developer Mode (Meta phone app)
- Plug USB
- Accept the USB debugging prompt
- Check Always allow

You want to end with:

```text
List of devices attached
2G0YC5ZG4F08WM  device
```

---

## 11) GitHub CLI (gh) install + authentication

### 11.1 Install gh

```bash
sudo pacman -S --needed github-cli
```

### 11.2 Authenticate

```bash
gh auth login
gh auth status
```

---

## 12) Get the correct WiVRn Quest APK (the journey, correctly)

This was the biggest blocker because:
- Artifacts were not visible in the browser
- wrong workflow runs (docs or debugging PR runs)
- Release APK Only runs had jobs but no downloadable artifacts
- stable releases do not match wivrn-full-git

We needed the **Build** workflow artifacts.

### 12.1 List workflows

```bash
gh workflow list --repo WiVRn/WiVRn
```

You should see something like:
- Build (ID shown in the list)
- Release APK Only
- others

### 12.2 List Build runs (this matters)

Try master first (what was used during setup). If it returns nothing, try main.

```bash
gh run list --repo WiVRn/WiVRn --workflow "Build" --branch master --limit 10
gh run list --repo WiVRn/WiVRn --workflow "Build" --branch main --limit 10
```

Example run used during setup:
- 21321590049

### 12.3 View the run and confirm artifacts

```bash
gh run view 21321590049 --repo WiVRn/WiVRn
```

You should see artifacts like:
- apk-Release
- apk-Debug

### 12.4 Download the Quest Release APK artifact (key step)

```bash
gh run download 21321590049 --repo WiVRn/WiVRn --name apk-Release
```

### 12.5 Extract

```bash
unzip -o *.zip
ls -la *.apk
```

### 12.6 Install the APK to Quest (ADB)

First uninstall the old or store WiVRn on the Quest (avoid incompatible update):

On Quest:
- Settings → Apps → WiVRn → Uninstall
- Reboot headset

Then on PC:

```bash
adb install -r *.apk
```

Reboot Quest again after install.

---

## 13) Run everything using VR Stack Control

Open the GUI:

```bash
vr-control --gui
```

In the GUI:
- Select **WiVRn (Native / Quest streaming)**
- Enable SlimeVR autostart in your profile if you want tracking every time
- Start the stack

Service commands (optional):

```bash
systemctl --user start vr-stack-control.service
systemctl --user stop vr-stack-control.service
journalctl --user -fu vr-stack-control.service
```

---

# Troubleshooting

## Steam or SteamVR opens when switching back to WiVRn
- In VR Stack Control select **WiVRn (Native / Quest streaming)** again.
- WiVRn mode should close Steam and SteamVR automatically.
- If Steam is still running, close it manually and retry.

## WiVRn does not connect / headset does not appear
- Make sure Quest and PC are on the same network.
- Open the WiVRn app on the headset and connect to the PC.
- Check logs:

```bash
journalctl --user -fu vr-stack-control.service
```

## OpenXR runtime looks wrong / games start in the wrong runtime
Run doctor:

```bash
vr-control doctor
```

Expected in WiVRn mode:
- OpenXR runtime name: Monado
- OpenXR library includes libopenxr_wivrn

Expected in SteamVR mode:
- OpenXR runtime name: SteamVR
- OpenXR library points into your SteamVR folder

If it is stuck on SteamVR when you want WiVRn:
- Ensure `~/.config/openxr/1/active_runtime.json` is missing (WiVRn mode clears it)
- Ensure system OpenXR runtime is set to WiVRn (see Part 3)

## ADB shows "unauthorized"
- Put the headset on, re-plug USB, accept the prompt, tick Always allow.
- Then run:

```bash
adb kill-server
adb start-server
adb devices
```

## SlimeVR trackers not working
- Ensure you installed **slimevr-beta-bin** (not stable slimevr).
- Start the stack with SlimeVR enabled in your profile.
- If WiVRn has a body tracking option, turn it off when using SlimeVR to avoid conflicts.

## OpenVR / Steam games do not see VR (XRizer)
- Install XRizer packages (Part 2).
- Ensure VR_PATHREG_OVERRIDE is set in fish:

```fish
set -Ux VR_PATHREG_OVERRIDE $HOME/.local/share/openvr/openvrpaths.vrpath
```
