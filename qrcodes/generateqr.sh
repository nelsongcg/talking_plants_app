#!/usr/bin/env bash
set -euo pipefail

# 1) Make sure qrencode is installed
if ! command -v qrencode &>/dev/null; then
  echo "Error: qrencode CLI not found. Install it (e.g. brew install qrencode)" >&2
  exit 1
fi

# 2) List your device⇄token pairs here (one per line):
pairs=(
  "08:D1:F9:71:47:6C D2CF3267-88A0-4009-A175-58450131FD42"
  # add more lines like:
  # "AA:BB:CC:DD:EE:FF 01234567-89AB-CDEF-0123-456789ABCDEF"
)

# 3) Loop and generate
for entry in "${pairs[@]}"; do
  device=${entry%% *}   # everything before the first space
  token=${entry#* }     # everything after the first space

  echo "Generating QR for ${device}..."
  qrencode \
    -o "${device}.png" \
    "plantpet://claim?d=${device}&t=${token}"
done

echo "Done. QR codes are in: $(pwd)"
