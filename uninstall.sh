#!/usr/bin/env bash
set -euo pipefail
rm -f "$HOME/.local/bin/vr-control"
rm -f "$HOME/.local/bin/vr-control-gui"
rm -f "$HOME/.local/bin/vr-stack-run.sh"

rm -f "$HOME/.local/share/applications/vr-control-panel.desktop"

rm -f "$HOME/.config/systemd/user/vr-stack-control.service"

echo "Uninstalled VR Stack Control"
