# Complete SD Card Build Process for Rocket90MHZ

## Overview
This document provides a complete step-by-step guide to create a bootable SD card for the Rocket90MHZ FPGA configuration running on the Genesys2 board.

---

## Current Configuration Summary

### Hardware Configuration
- **Platform**: Genesys2 FPGA board
- **CPU**: Rocket90MHZ (90 MHz, single core)
- **Timer**: 90 kHz timebase
- **Memory**: 1 GB DRAM at 0x80000000
- **Storage**: SD card via SPI (mmc_spi)

### Software Stack
- **Bootloader**: OpenSBI v1.7 + U-Boot 2025.10-rc2
- **Kernel**: Linux 6.15.9 (RISC-V 64-bit)
- **Rootfs**: Debian GNU/Linux 13 (trixie)

---

## Linux Kernel Configuration

### Base Configuration
- **Defconfig**: `defconfig` (arch/riscv/configs/defconfig)
- **Architecture**: RISC-V 64-bit
- **Compiler**: riscv64-linux-gnu-gcc 13.3.0

### Critical Driver Modifications
The following drivers were **manually enabled** beyond the default defconfig:

1. **SiFive UART Driver** (for serial console):
   ```
   CONFIG_SERIAL_SIFIVE=y
   CONFIG_SERIAL_SIFIVE_CONSOLE=y
   ```

2. **SiFive SPI Driver** (for SD card interface):
   ```
   CONFIG_SPI_SIFIVE=y
   CONFIG_SPI_DEBUG=y
   ```

3. **MMC over SPI Driver** (for SD card):
   ```
   CONFIG_MMC_SPI=y
   CONFIG_MMC_DEBUG=y
   ```

### How to Reproduce Kernel Config
```bash
cd /home/ishara/Research/repos/vivado-risc-v/linux-stable

# Start with default config
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- defconfig

# Enable required drivers
./scripts/config --enable CONFIG_SERIAL_SIFIVE
./scripts/config --enable CONFIG_SERIAL_SIFIVE_CONSOLE
./scripts/config --enable CONFIG_SPI_SIFIVE
./scripts/config --enable CONFIG_SPI_DEBUG
./scripts/config --enable CONFIG_MMC_SPI
./scripts/config --enable CONFIG_MMC_DEBUG

# Apply and build
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- olddefconfig
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)
```

---

## Complete Build Process (Step-by-Step)

### Prerequisites
- RISC-V cross-compiler: `riscv64-linux-gnu-gcc`
- SD card (8 GB or larger)
- Debian rootfs tarball at: `/home/ishara/Research/repos/vivado-risc-v/debian-riscv64/rootfs.tar.gz`

---

### Step 1: Create/Modify U-Boot Device Tree

**File**: `/home/ishara/Research/repos/u-boot/arch/riscv/dts/Rocket90MHZ.dts`

**Purpose**: Defines hardware configuration for U-Boot (memory map, peripherals, clocks)

**Key settings**:
- timebase-frequency: 90000 (90 kHz)
- clock-frequency: 90000000 (90 MHz)
- memory: 1 GB at 0x80000000
- #address-cells = <2>, #size-cells = <2> (for 64-bit addressing)

**Action**: Ensure the DTS file exists with correct configuration (already created)

---

### Step 2: Create/Modify U-Boot Configuration

**File**: `/home/ishara/Research/repos/u-boot/configs/Rocket90MHZ_defconfig`

**Purpose**: U-Boot build configuration

**Key settings**:
- `CONFIG_DEFAULT_DEVICE_TREE="Rocket90MHZ"`
- Boot command to load kernel from SD card FAT32 partition
- Console: ttySIF0 (SiFive UART)

**Action**: Ensure the defconfig exists (already created)

---

### Step 3: Update U-Boot Build Script

**File**: `/home/ishara/Research/repos/u-boot/setup_genesys2.sh`

**Modification**: Change defconfig to Rocket90MHZ_defconfig

```bash
#!/usr/bin/bash
set -e

UBOOT_DIR=~/Research/repos/u-boot

cd $UBOOT_DIR

make distclean
make CROSS_COMPILE=riscv64-linux-gnu- Rocket90MHZ_defconfig
make CROSS_COMPILE=riscv64-linux-gnu- -j16
```

**Action**: Script is already updated

---

### Step 4: Build U-Boot

**Command**:
```bash
cd /home/ishara/Research/repos/u-boot
./setup_genesys2.sh
```

**Output**:
- `u-boot.bin` - U-Boot binary
- `arch/riscv/dts/Rocket90MHZ.dtb` - Device tree blob

**Build time**: ~2-5 minutes

---

### Step 5: Build OpenSBI with U-Boot Payload

**Script**: `/home/ishara/Research/repos/opensbi/genesys2_sbi.sh`

**Command**:
```bash
cd /home/ishara/Research/repos/opensbi
./genesys2_sbi.sh
```

**What the script does**:
- Cleans previous builds (`make distclean`)
- Builds OpenSBI with U-Boot payload and DTB
- Includes debug symbols (`FW_DEBUG=1`)
- Copies output to `~/Research/repos/u-boot/u-boot-sbi.bin`

**Output**:
- `build/platform/generic/firmware/fw_payload.bin` (OpenSBI + U-Boot combined)
- `u-boot/u-boot-sbi.bin` (copy of fw_payload.bin)

**Build time**: ~1-2 minutes

**Size**: ~2.5 MB

---

### Step 6: Configure Linux Kernel

**Command**:
```bash
cd /home/ishara/Research/repos/vivado-risc-v/linux-stable

# Start with default config
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- defconfig

# Enable critical drivers
./scripts/config --enable CONFIG_SERIAL_SIFIVE
./scripts/config --enable CONFIG_SERIAL_SIFIVE_CONSOLE
./scripts/config --enable CONFIG_SPI_SIFIVE
./scripts/config --enable CONFIG_SPI_DEBUG
./scripts/config --enable CONFIG_MMC_SPI
./scripts/config --enable CONFIG_MMC_DEBUG

# Apply config changes
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- olddefconfig
```

**Action**: Only needed if starting from scratch or changing kernel config

---

### Step 7: Build Linux Kernel

**Command**:
```bash
cd /home/ishara/Research/repos/vivado-risc-v/linux-stable

make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)
```

**Output**:
- `arch/riscv/boot/Image` (uncompressed kernel image, ~19 MB)

**Build time**: ~10-30 minutes (depending on CPU cores)

---

### Step 8: Prepare SD Card

**Script**: `/home/ishara/Research/repos/opensbi/make_sdcard.sh`

**Before running**:
1. Insert SD card and identify device (e.g., /dev/sdg)
2. Update `DISK` variable in script:
   ```bash
   DISK=/dev/sdg  # Change to your SD card device
   ```

**Command**:
```bash
cd /home/ishara/Research/repos/opensbi
./make_sdcard.sh
```

**What the script does**:

1. **Unmount** any existing partitions on the SD card

2. **Clear** old partition table and MBR

3. **Write** OpenSBI+U-Boot payload to sector 34:
   - Source: `build/platform/generic/firmware/fw_payload.bin`
   - Location: Starting at sector 34 (0x4400 bytes offset)

4. **Create partition table**:
   - Partition 1: 8 MiB - 128 MiB (FAT32, bootable)
   - Partition 2: 128 MiB - end (ext4)

5. **Format partitions**:
   - Boot partition: FAT32 with label "BOOT"
   - Root partition: ext4 with label "rootfs" and specific UUID

6. **Copy boot files** to partition 1:
   - `Image` (kernel, 19 MB)
   - `Rocket90MHZ.dtb` (device tree, 7.8 KB)

7. **Extract rootfs** to partition 2:
   - Debian GNU/Linux 13 (trixie) from tarball

8. **Verify** and display partition layout

**Build time**: ~5-10 minutes (mostly rootfs extraction)

---

## SD Card Layout

```
┌──────────────────────────────────────────────────────────────┐
│ Sector 0-33: MBR + Gap (17 KB)                              │
├──────────────────────────────────────────────────────────────┤
│ Sector 34+: OpenSBI + U-Boot (fw_payload.bin, ~2.5 MB)      │
├──────────────────────────────────────────────────────────────┤
│ 8 MiB - 128 MiB: Partition 1 (FAT32, label: BOOT)           │
│   - Image (kernel, 19 MB)                                    │
│   - Rocket90MHZ.dtb (7.8 KB)                                 │
├──────────────────────────────────────────────────────────────┤
│ 128 MiB - End: Partition 2 (ext4, label: rootfs)            │
│   - Debian root filesystem                                   │
│   - /swapfile (256 MB)                                       │
└──────────────────────────────────────────────────────────────┘
```

---

## Boot Flow

1. **FPGA Boot ROM** → Loads OpenSBI from flash sector 34
2. **OpenSBI** → Initializes machine mode, loads U-Boot
3. **U-Boot** → Initializes DRAM, detects SD card via SPI
4. **U-Boot** → Loads kernel Image and DTB from FAT32 partition
5. **U-Boot** → Boots kernel with bootargs: `root=/dev/mmcblk0p2 rootwait rw console=ttySIF0,115200 earlycon`
6. **Linux Kernel** → Initializes drivers, mounts rootfs
7. **systemd** → Boots to multi-user target

---

## Complete Build Sequence (Quick Reference)

### If starting from scratch:

```bash
# 1. Build U-Boot
cd /home/ishara/Research/repos/u-boot
./setup_genesys2.sh

# 2. Build OpenSBI with U-Boot payload
cd /home/ishara/Research/repos/opensbi
./genesys2_sbi.sh

# 3. Configure kernel (only if needed)
cd /home/ishara/Research/repos/vivado-risc-v/linux-stable
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- defconfig
./scripts/config --enable CONFIG_SERIAL_SIFIVE
./scripts/config --enable CONFIG_SERIAL_SIFIVE_CONSOLE
./scripts/config --enable CONFIG_SPI_SIFIVE
./scripts/config --enable CONFIG_SPI_DEBUG
./scripts/config --enable CONFIG_MMC_SPI
./scripts/config --enable CONFIG_MMC_DEBUG
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- olddefconfig

# 4. Build kernel
cd /home/ishara/Research/repos/vivado-risc-v/linux-stable
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)

# 5. Create SD card (update DISK variable first!)
cd /home/ishara/Research/repos/opensbi
# Edit make_sdcard.sh to set DISK=/dev/sdX
./make_sdcard.sh
```

### If only kernel changed:

```bash
# 1. Rebuild kernel
cd /home/ishara/Research/repos/vivado-risc-v/linux-stable
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)

# 2. Update SD card (DISK variable must be correct!)
cd /home/ishara/Research/repos/opensbi
./make_sdcard.sh
```

### If only U-Boot/DTB changed:

```bash
# 1. Rebuild U-Boot
cd /home/ishara/Research/repos/u-boot
./setup_genesys2.sh

# 2. Rebuild OpenSBI with new U-Boot
cd /home/ishara/Research/repos/opensbi
./genesys2_sbi.sh

# 3. Recreate SD card
./make_sdcard.sh
```

---

## Files Referenced by make_sdcard.sh

The script uses these paths (all verified to exist):

### Input Files:
1. `/home/ishara/Research/repos/opensbi/build/platform/generic/firmware/fw_payload.bin`
   - OpenSBI + U-Boot combined binary (2.5 MB)
   
2. `/home/ishara/Research/repos/vivado-risc-v/linux-stable/arch/riscv/boot/Image`
   - Linux kernel image (19 MB)
   
3. `/home/ishara/Research/repos/u-boot/arch/riscv/dts/Rocket90MHZ.dtb`
   - Device tree blob (7.8 KB)
   
4. `/home/ishara/Research/repos/vivado-risc-v/debian-riscv64/rootfs.tar.gz`
   - Debian root filesystem tarball

### Output:
- SD card device (e.g., /dev/sdg) with bootable Linux system

---

## Verification Steps

After running `make_sdcard.sh`, verify:

```bash
# Check partition table
lsblk -f /dev/sdg

# Expected output:
# sdg                                                            
# ├─sdg1 vfat   FAT32 BOOT   [UUID] 
# └─sdg2 ext4   1.0   rootfs 68d82fa1-1bb5-435f-a5e3-862176586eec

# Check boot partition contents
sudo mount /dev/sdg1 /mnt
ls -lh /mnt
# Should show: Image (19M), Rocket90MHZ.dtb (7.8K)
sudo umount /mnt

# Check rootfs
sudo mount /dev/sdg2 /mnt
ls /mnt
# Should show: bin, boot, dev, etc, home, lib, ... (standard Linux directories)
sudo umount /mnt
```

---

## Known Issues & Solutions

### Issue 1: Long boot time (~1.5 hours)
- **Cause**: 90 kHz timebase (11x slower than standard 1 MHz)
- **Solution**: Accept slow boot or increase timebase to 1 MHz in DTB

### Issue 2: Slow SD card I/O (~519 KiB/s)
- **Cause**: SPI-based MMC (mmc_spi driver) instead of native MMC controller
- **Solution**: This is hardware limitation, cannot be fixed in software

### Issue 3: Emergency shell if BOOT label missing
- **Cause**: systemd waits for `/dev/disk/by-label/BOOT`
- **Solution**: Script now adds `-n BOOT` flag when formatting (fixed in Step 4)

---

## Troubleshooting

### SD card not detected by U-Boot
- Check SPI driver in U-Boot config
- Verify SD card is properly inserted
- Try different SD card

### Kernel hangs at "Starting kernel..."
- Check `CONFIG_SERIAL_SIFIVE=y` in kernel config
- Verify DTB has correct console configuration

### Kernel can't find root device
- Check partition 2 has correct UUID: `68d82fa1-1bb5-435f-a5e3-862176586eec`
- Verify bootargs: `root=/dev/mmcblk0p2`

### System boots to emergency shell
- Press Ctrl-D to continue boot
- Or set root password and login to debug
- Check if BOOT partition has label "BOOT"

---

## Summary

**Minimum steps to create bootable SD card from current state:**

1. Verify all binaries are built (U-Boot, OpenSBI, kernel)
2. Insert SD card and identify device
3. Update `DISK` variable in `make_sdcard.sh`
4. Run `./make_sdcard.sh`
5. Insert SD card into FPGA board and boot

**Total time**: ~5-10 minutes (if all binaries pre-built)

**Full rebuild from scratch**: ~30-60 minutes
