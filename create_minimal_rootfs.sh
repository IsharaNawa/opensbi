#!/bin/bash
# Create a minimal rootfs for fast boot on Chipyard FPGA

set -e

WORK_DIR="$PWD/minimal_rootfs_build"
ROOTFS_IMG="minimal_rootfs.ext4"
ROOTFS_SIZE="200M"  # Small 200MB image

echo "=== Creating Minimal RootFS for Chipyard ==="
echo "Working directory: $WORK_DIR"

# Clean and create working directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/rootfs"

cd "$WORK_DIR"

echo "[1/6] Creating minimal directory structure..."
mkdir -p rootfs/{bin,sbin,etc,proc,sys,dev,tmp,lib,lib64,usr/{bin,sbin,lib},root,home,var/log,run}

echo "[2/6] Installing BusyBox (provides basic utilities)..."
# Check if busybox-static is available
if ! command -v busybox &> /dev/null; then
    echo "ERROR: busybox not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y busybox-static
fi

# Copy busybox
cp $(which busybox) rootfs/bin/busybox
cd rootfs/bin
for cmd in $(./busybox --list); do
    ln -sf busybox "$cmd" 2>/dev/null || true
done
cd ../..

echo "[3/6] Creating minimal init system..."
cat > rootfs/sbin/init << 'EOF'
#!/bin/sh
# Minimal init script

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /tmp
mount -t tmpfs tmpfs /run

# Set hostname
hostname chipyard

# Print boot message
echo ""
echo "========================================="
echo "  Chipyard Minimal Linux"
echo "  Kernel: $(uname -r)"
echo "  Boot time: $(cut -d' ' -f1 /proc/uptime)s"
echo "========================================="
echo ""

# Start a shell
exec /bin/sh
EOF

chmod +x rootfs/sbin/init

echo "[4/6] Creating essential config files..."

# /etc/inittab (for BusyBox init)
cat > rootfs/etc/inittab << 'EOF'
::sysinit:/etc/init.d/rcS
::respawn:-/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
EOF

# /etc/init.d/rcS
mkdir -p rootfs/etc/init.d
cat > rootfs/etc/init.d/rcS << 'EOF'
#!/bin/sh
# System initialization script
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs dev /dev
mount -t tmpfs tmpfs /tmp
EOF
chmod +x rootfs/etc/init.d/rcS

# /etc/fstab
cat > rootfs/etc/fstab << 'EOF'
proc            /proc   proc    defaults        0 0
sysfs           /sys    sysfs   defaults        0 0
devtmpfs        /dev    devtmpfs defaults      0 0
tmpfs           /tmp    tmpfs   defaults        0 0
EOF

# /etc/passwd
cat > rootfs/etc/passwd << 'EOF'
root:x:0:0:root:/root:/bin/sh
EOF

# /etc/group
cat > rootfs/etc/group << 'EOF'
root:x:0:
EOF

# /etc/shadow
cat > rootfs/etc/shadow << 'EOF'
root::10933:0:99999:7:::
EOF
chmod 640 rootfs/etc/shadow

# /etc/hostname
echo "chipyard" > rootfs/etc/hostname

# Create device nodes (minimal set)
echo "[5/6] Creating device nodes..."
sudo mknod -m 666 rootfs/dev/null c 1 3
sudo mknod -m 666 rootfs/dev/zero c 1 5
sudo mknod -m 666 rootfs/dev/random c 1 8
sudo mknod -m 666 rootfs/dev/urandom c 1 9
sudo mknod -m 622 rootfs/dev/console c 5 1
sudo mknod -m 666 rootfs/dev/tty c 5 0
sudo mknod -m 660 rootfs/dev/ttyS0 c 4 64

echo "[6/6] Creating ext4 filesystem image..."
# Create empty image file
dd if=/dev/zero of="$ROOTFS_IMG" bs=1M count=200

# Format as ext4 with minimal features for fast boot
mkfs.ext4 -F -L "rootfs" -O ^has_journal "$ROOTFS_IMG"

# Mount and copy files
MOUNT_DIR=$(mktemp -d)
sudo mount -o loop "$ROOTFS_IMG" "$MOUNT_DIR"
sudo cp -a rootfs/* "$MOUNT_DIR/"
sudo umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"

echo ""
echo "=== Minimal RootFS Created Successfully ==="
echo "Image: $WORK_DIR/$ROOTFS_IMG"
echo "Size: $(du -h $ROOTFS_IMG | cut -f1)"
echo ""
echo "To use this rootfs:"
echo "1. Copy to SD card partition 2:"
echo "   sudo dd if=$WORK_DIR/$ROOTFS_IMG of=/dev/sdX2 bs=1M"
echo ""
echo "2. Or mount and extract:"
echo "   sudo mount /dev/sdX2 /mnt"
echo "   sudo rm -rf /mnt/*"
echo "   sudo mount -o loop $ROOTFS_IMG /tmp/mnt"
echo "   sudo cp -a /tmp/mnt/* /mnt/"
echo "   sudo umount /tmp/mnt /mnt"
echo ""
echo "Expected boot time: < 30 seconds (vs 16+ minutes with full Debian)"
