# VR Stack Control v0.6.85 (Quest 3 on CachyOS: WiVRn + WayVR + SlimeVR)

VR Stack Control is a lightweight Linux GUI + systemd user service that manages a modular VR stack:

Tracking -> Streaming Server -> VR App

It keeps OpenXR/OpenVR state sane (no stuck SteamVR overrides, no missing OpenVR paths) and launches things in the right order every time.

Made by: David Coates (idea + testing) + ChatGPT (implementation help)

Repo: https://github.com/devnet82-ship-it/wivrn-stack-control
Pages: https://devnet82-ship-it.github.io/wivrn-stack-control/

---

## Links (where to get everything)

WiVRn:
- Project: https://github.com/WiVRn/WiVRn
- Website/docs: https://wivrn.app/
- Releases: https://github.com/WiVRn/WiVRn/releases
- Flathub (optional PC install): https://flathub.org/apps/io.github.wivrn.wivrn

WayVR:
- Project: https://github.com/wayvr/wayvr

SlimeVR:
- SlimeVR Server: https://github.com/SlimeVR/SlimeVR-Server
- AUR slimevr-beta-bin: https://aur.archlinux.org/packages/slimevr-beta-bin

XRizer (OpenVR -> OpenXR for Steam/OpenVR titles):
- Project: https://github.com/Supreeeme/xrizer
- AUR xrizer-git: https://aur.archlinux.org/packages/xrizer-git

---

# 1) Install VR Stack Control (v0.6.85 release zip)

Download v0.6.85 zip from Releases:
https://github.com/devnet82-ship-it/wivrn-stack-control/releases

Install (fish-safe):

```fish
cd ~/Downloads
# Replace this with your exact filename if needed
set ZIP vr-stack-control-v0.6.85-openxrfix9-close-steam-on-wivrn21.zip

rm -rf vr-stack-control-v0.6.85
unzip -o "$ZIP" -d vr-stack-control-v0.6.85
cd vr-stack-control-v0.6.85
chmod +x install.sh uninstall.sh bin/*
./install.sh
systemctl --user daemon-reload
```

Run GUI:

```fish
vr-control --gui
```

Optional tray:

```fish
vr-control tray
vr-control tray-enable
vr-control tray-disable
```

Doctor:

```fish
vr-control doctor
```

---

# 2) Install PC software (CachyOS / KDE / Wayland)

## 2.1 Base packages

```fish
sudo pacman -Syu
sudo pacman -S --needed git base-devel avahi
```

Enable Avahi (WiVRn discovery uses mDNS):

```fish
sudo systemctl enable --now avahi-daemon
```

## 2.2 WiVRn (PC) - normal/stable

If you previously used beta/dev WiVRn:

```fish
sudo pacman -Rns wivrn-full-git 2>/dev/null
```

Install WiVRn stable:

```fish
yay -S --needed wivrn-server wivrn-dashboard
pacman -Q | grep -i wivrn
```

## 2.3 WayVR

```fish
sudo pacman -S --needed wayvr
command -v wayvr
```

## 2.4 SlimeVR (beta)

This guide uses slimevr-beta-bin because it has been reliable for this setup.

```fish
yay -S --needed slimevr-beta-bin
pacman -Q | grep -i slimevr
```

## 2.5 XRizer (recommended for Steam/OpenVR titles)

```fish
yay -S --needed xrizer-git xrizer-common-git lib32-xrizer-git

mkdir -p ~/.local/share/openvr
printf "%s\n" \
"{" \
"  \"jsonid\": \"vrpathreg\"," \
"  \"runtime\": [\"/opt/xrizer\"]," \
"  \"version\": 1" \
"}" \
> ~/.local/share/openvr/openvrpaths.vrpath

set -Ux VR_PATHREG_OVERRIDE "$HOME/.local/share/openvr/openvrpaths.vrpath"
```

---

# 3) Quest 3 WiVRn client (DEFAULT: Quest Store)

You do NOT need ADB for normal use.

1) On Quest 3: open the Store
2) Search: WiVRn
3) Install or Update it
4) Open WiVRn and connect to your PC (same network)

---

# 4) OPTIONAL: ADB setup + Sideloading APK (only for dev/testing)

Only do this if you must sideload a specific build (testing) or you are debugging.

Install ADB tools:

```fish
sudo pacman -S --needed android-tools
adb version
```

Enable Developer Mode:
- Meta Quest phone app -> Devices -> Quest 3 -> Developer Mode ON
- Reboot headset

Enable USB Debugging in headset:
- Settings -> System -> Developer -> USB Debugging ON

Authorize:

```fish
adb kill-server
adb start-server
adb devices
```

If you see "unauthorized": accept the USB debugging prompt in-headset and tick "Always allow".

Optional: GitHub Actions APK method (only if matching a dev PC build):

```fish
sudo pacman -S --needed github-cli
gh auth login
gh workflow list --repo WiVRn/WiVRn
gh run list --repo WiVRn/WiVRn --workflow "Build" --branch master --limit 10
# pick a RUN id that has apk-Release artifact
set RUN 21321590049
gh run view $RUN --repo WiVRn/WiVRn
gh run download $RUN --repo WiVRn/WiVRn --name apk-Release
unzip -o *.zip
adb install -r *.apk
```

---

# 5) Daily use (VR Stack Control)

Open the GUI:

```fish
vr-control --gui
```

Select XR Runtime:
- WiVRn: Quest streaming (no SteamVR)
- SteamVR: Steam Link / legacy OpenVR paths

Start/Stop from GUI or:

```fish
systemctl --user start vr-stack-control.service
systemctl --user stop vr-stack-control.service
journalctl --user -fu vr-stack-control.service
```

