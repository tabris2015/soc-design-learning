#!/usr/bin/env bash
# Install a udev rule for the DE25-Nano's on-board USB-Blaster III, so Quartus
# Programmer and jtagd can use it without root.
#
# The rule matches Altera's vendor ID rather than one product ID: the DE25-Nano
# enumerates as 09fb:6026, not the 6022 often quoted for the USB-Blaster III,
# and other Blaster variants use other IDs. The Blaster III is an FT4232H whose
# last two channels are serial ports (the HPS console among them), so the rule
# also keeps ModemManager from probing them with AT commands.
set -euo pipefail

RULE_FILE=/etc/udev/rules.d/51-usb-blaster-iii.rules

echo "==> Writing ${RULE_FILE}"
sudo tee "$RULE_FILE" >/dev/null <<'EOF'
# Altera USB-Blaster III (DE25-Nano on-board programmer, 09fb:6026) and other Altera cables
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", MODE="0664", GROUP="plugdev", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
SUBSYSTEM=="tty", ATTRS{idVendor}=="09fb", GROUP="dialout", MODE="0660", ENV{ID_MM_DEVICE_IGNORE}="1"
EOF

echo "==> Reloading udev"
sudo udevadm control --reload-rules
sudo udevadm trigger

if id -nG "$USER" | tr ' ' '\n' | grep -qx plugdev; then
    echo "OK: $USER is in plugdev"
else
    echo "==> Adding $USER to plugdev (log out/in required)"
    sudo usermod -aG plugdev "$USER"
fi

echo
echo "Done. Plug the board's USB-C (USB-Blaster III) port in, then: lsusb -d 09fb:"
