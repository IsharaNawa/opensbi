#!/usr/bin/bash
set -e
OPENSBI_DIR=~/Research/repos/opensbi
OPENSBI_FIRM_PATH=~/Research/repos/opensbi/build/platform/generic/firmware
cd $OPENSBI_DIR
lsblk
echo "Building OpenSBI for RISC-V platform..."
sudo wipefs -a /dev/sde
sudo dd if=$OPENSBI_FIRM_PATH/fw_payload.bin of=/dev/sde bs=512 seek=34 conv=fsync status=progress
echo "OpenSBI firmware written to /dev/sde."
sudo hexdump -C /dev/sde | head -n 20
echo "First 20 lines of /dev/sde:"
echo "You can now use this SD card with your RISC-V platform."

# not a safe script, be careful with dd and wipefs commands