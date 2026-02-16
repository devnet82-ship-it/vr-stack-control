# VR Stack Control v0.6.85 (WiVRn / WayVR / SlimeVR) — Quest 3 on CachyOS

**VR Stack Control** is a lightweight Linux GUI + systemd user service that keeps a modular VR stack sane:

**Tracking → Streaming Server → VR App**

It fixes common Linux VR issues:
- OpenXR runtime getting “stuck” on SteamVR
- missing / duplicated OpenVR paths
- launching in the correct order every time
- profiles for different setups (WiVRn vs SteamVR, tracking on/off, app choice)

**Made by:** David Coates (idea + testing) + ChatGPT (implementation help)

Repo: https://github.com/devnet82-ship-it/wivrn-stack-control
Pages: https://devnet82-ship-it.github.io/wivrn-stack-control/

---

## Official / Download links (beta + stable)

### WiVRn
- Main project + docs: https://github.com/WiVRn/WiVRn
- Website/docs: https://wivrn.app/
- Releases: https://github.com/WiVRn/WiVRn/releases
- Flathub (optional PC install): https://flathub.org/apps/io.github.wivrn.wivrn

### SlimeVR
- SlimeVR Server (upstream): https://github.com/SlimeVR/SlimeVR-Server
- AUR slimevr-beta-bin (what this guide uses): https://aur.archlinux.org/packages/slimevr-beta-bin

### WayVR
- WayVR (upstream): https://github.com/wayvr/wayvr

### XRizer (OpenVR → OpenXR for Steam/OpenVR titles)
- XRizer (upstream): https://github.com/Supreeeme/xrizer
- AUR xrizer-git: https://aur.archlinux.org/packages/xrizer-git

---

# 1) Install VR Stack Control (v0.6.85 release zip)

Download v0.6.85 zip from Releases:
- https://github.com/devnet82-ship-it/wivrn-stack-control/releases

Install (fish-safe):

```fish
cd ~/Downloads
# replace filename if yours differs
set ZIP vr-stack-control-v0.6.85-openxrfix9-close-steam-on-wivrn21.zip

rm -rf vr-stack-control-v0.6.85
unzip -o "$ZIP" -d vr-stack-control-v0.6.85
cd vr-stack-control-v0.6.85

chmod +x install.sh uninstall.sh bin/*
./install.sh
systemctl --user daemon-reload
```

Run the GUI:

```fish
vr-control --gui
```

Optional tray:

```fish
vr-control tray          # start tray now
vr-control tray-enable   # autostart tray on login
vr-control tray-disable  # disable tray autostart
```

Doctor output:

```fish
vr-control doctor
```

---

# 2) Install the PC apps (CachyOS / KDE / Wayland)

This guide now uses **stable WiVRn** on the PC.

## 2.1 Base packages

```fish
sudo pacman -Syu
sudo pacman -S --needed git base-devel android-tools avahi github-cli
```

Enable Avahi (WiVRn discovery uses mDNS):

```fish
sudo systemctl enable --now avahi-daemon
systemctl status avahi-daemon --no-pager
```

## 2.2 WiVRn (PC) — stable

If you previously installed the dev/beta package, remove it first:

```fish
sudo pacman -Rns wivrn-full-git 2>/dev/null
```

Install WiVRn stable (AUR packages):

```fish
yay -S --needed wivrn-server wivrn-dashboard
```

Verify:

```fish
pacman -Q | grep -i wivrn
command -v wivrn-server; and wivrn-server --help >/dev/null
command -v wivrn-dashboard
```

## 2.3 WayVR

Stable:

```fish
sudo pacman -S --needed wayvr
command -v wayvr
```

If you specifically want **wayvr-git** and it prompts for cargo provider, pick **1) rust**:

```fish
# optional alternative:
# yay -S --needed wayvr-git
# when asked for cargo provider, choose 1) rust
```

## 2.4 SlimeVR (beta) — recommended for this stack

Install:

```fish
yay -S --needed slimevr-beta-bin
pacman -Q | grep -i slimevr
command -v slimevr
```

## 2.5 XRizer (OpenVR compatibility for Steam/OpenVR titles)

Install:

```fish
yay -S --needed xrizer-git xrizer-common-git lib32-xrizer-git
```

Create OpenVR path registry (fish-safe):

```fish
mkdir -p ~/.local/share/openvr
printf "%s\n" \
"{" \
"  \"jsonid\": \"vrpathreg\"," \
"  \"runtime\": [" \
"    \"/opt/xrizer\"" \
"  ]," \
"  \"version\": 1" \
"}" \
> ~/.local/share/openvr/openvrpaths.vrpath
```

Set it permanently (fish universal variable):

```fish
set -Ux VR_PATHREG_OVERRIDE "$HOME/.local/share/openvr/openvrpaths.vrpath"
echo $VR_PATHREG_OVERRIDE
```

---

# 3) Firewall / ports (if you use one)

WiVRn typically needs:
- **5353/UDP** (mDNS discovery)
- **9757/TCP + 9757/UDP** (streaming/control)

Example (ufw):

```fish
sudo ufw allow 5353/udp
sudo ufw allow 9757/tcp
sudo ufw allow 9757/udp
```

Example (firewalld):

```fish
sudo firewall-cmd --permanent --add-port=5353/udp
sudo firewall-cmd --permanent --add-port=9757/tcp
sudo firewall-cmd --permanent --add-port=9757/udp
sudo firewall-cmd --reload
```

---

# 4) Quest 3 ADB setup (one-time)

You may hit:
- “device unauthorized” → you must accept the USB debugging prompt in the headset

Install ADB tools:

```fish
sudo pacman -S --needed android-tools
adb version
```

Enable Developer Mode:
- Meta Quest phone app → Devices → Quest 3 → **Developer Mode ON**
- Reboot headset

Enable USB Debugging in headset:
- Settings → System → Developer → **USB Debugging ON**

Authorize:

```fish
adb kill-server
adb start-server
adb devices
```

In the headset prompt:
- Accept USB debugging
- Tick “Always allow”

Verify you get `device`:

```fish
adb devices
```

---

# 5) WiVRn Quest app — how we got the APK (the exact method we used)

There are two ways:

## Option A (recommended for stable PC WiVRn): Meta Store client
Use the WiVRn client from the Quest store so it matches stable server builds.

## Option B (when you need a matching GitHub build): GitHub Actions APK artifact

This was the big blocker originally because:
- Browser didn’t show artifacts easily
- Some runs had jobs but no downloadable artifacts
- Store/release builds didn’t match the PC build we were on

The fix was: **use the “Build” workflow artifacts**.

### 5.1 Install GitHub CLI (gh) + login

```fish
sudo pacman -S --needed github-cli
gh auth login
gh auth status
```

### 5.2 List workflows (find “Build”)

```fish
gh workflow list --repo WiVRn/WiVRn
```

### 5.3 List recent runs of the Build workflow (branch master)

```fish
gh run list --repo WiVRn/WiVRn --workflow "Build" --branch master --limit 10
```

Pick a run ID and confirm it has artifacts:

```fish
set RUN 21321590049
gh run view $RUN --repo WiVRn/WiVRn
```

### 5.4 Download the Release APK artifact (key step)

```fish
gh run download $RUN --repo WiVRn/WiVRn --name apk-Release
unzip -o *.zip
ls -la *.apk
```

### 5.5 Install the APK to the Quest (ADB)

First uninstall old/store WiVRn (to avoid incompatible update):
- Quest: Settings → Apps → WiVRn → Uninstall
- Reboot headset

Then install:

```fish
adb install -r *.apk
```

---

# 6) Using VR Stack Control (daily flow)

1) Open GUI:

```fish
vr-control --gui
```

2) Select **XR Runtime: WiVRn**
- In v0.6.85, WiVRn mode ensures Steam/SteamVR are closed so WiVRn doesn’t get hijacked.

3) Choose tracking option (SlimeVR on/off) in your profile.

4) Start the stack from the GUI **Start** button,
or from terminal:

```fish
systemctl --user start vr-stack-control.service
```

Stop:

```fish
systemctl --user stop vr-stack-control.service
```

Logs:

```fish
journalctl --user -fu vr-stack-control.service
```

Doctor:

```fish
vr-control doctor
```

---

# 7) Troubleshooting

## ADB “device unauthorized”
- Unplug/replug USB
- In headset, accept the USB debugging dialog and tick “Always allow”
- Then:

```fish
adb kill-server
adb start-server
adb devices
```

## WayVR reinstall (fish-safe)

```fish
# stable
sudo pacman -S --needed wayvr

# or AUR git version (optional)
# yay -S --needed wayvr-git
```

If you removed a local copy and want to be sure you’re using the packaged one:

```fish
rm -f ~/.local/bin/wayvr 2>/dev/null
command -v wayvr
```

