#!/usr/bin/env bash
set -e

APP_DIR="$PWD"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
CONFIG_DIR="$HOME/.config/vr-stack"
SYSTEMD_DIR="$HOME/.config/systemd/user"

mkdir -p "$BIN_DIR" "$DESKTOP_DIR" "$CONFIG_DIR" "$SYSTEMD_DIR"

install -m 0755 "$APP_DIR/bin/vr-control" "$BIN_DIR/vr-control"
install -m 0755 "$APP_DIR/bin/vr-control-gui" "$BIN_DIR/vr-control-gui"

if [ -f "$APP_DIR/bin/vr-stack-run.sh" ]; then
  install -m 0755 "$APP_DIR/bin/vr-stack-run.sh" "$BIN_DIR/vr-stack-run.sh"
fi

if [ -f "$APP_DIR/systemd/vr-stack-control.service" ]; then
  install -m 0644 "$APP_DIR/systemd/vr-stack-control.service" "$SYSTEMD_DIR/vr-stack-control.service"
fi

install -m 0644 "$APP_DIR/desktop/vr-control-panel.desktop" "$DESKTOP_DIR/vr-control-panel.desktop"

if [ -f "$APP_DIR/config/stack.conf.example" ] && [ ! -f "$CONFIG_DIR/stack.conf" ]; then
  cp -n "$APP_DIR/config/stack.conf.example" "$CONFIG_DIR/stack.conf"
fi

systemctl --user daemon-reload >/dev/null 2>&1 || true
update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true

echo "Installed to:"
echo "  $BIN_DIR/vr-control"
echo "  $BIN_DIR/vr-control-gui"
echo "Launch with: vr-control --gui"
