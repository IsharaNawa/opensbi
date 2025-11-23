#!/usr/bin/bash
set -e
OPENSBI_DIR=~/Research/repos/opensbi
cd $OPENSBI_DIR
make distclean
make PLATFORM=generic FW_DEBUG=1 \
    CROSS_COMPILE=riscv64-linux-gnu- \
    FW_PAYLOAD_PATH=~/Research/repos/u-boot/u-boot.bin \
    FW_FDT_PATH=~/Research/repos/u-boot/arch/riscv/dts/chipyard.fpga.genesys2.GENESYS2FPGATestHarness.RocketGENESYS2Config.dtb \
    -j16
echo "OpenSBI build completed."
strings build/platform/generic/firmware/fw_payload.elf | grep chipyard

cp ~/Research/repos/opensbi/build/platform/generic/firmware/fw_payload.bin ~/Research/repos/u-boot/u-boot-sbi.bin
riscv64-linux-gnu-objdump -h  ~/Research/repos/opensbi/build/platform/generic/firmware/fw_payload.elf | grep dtb
echo "You can now use this binary with your RISC-V platform."
cd -
echo "Returning to the previous directory."
echo "Script execution finished."