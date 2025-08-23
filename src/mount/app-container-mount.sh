#!/bin/bash
# /usr/bin/app-container-mount.sh
# automount container script
set -e

# get the active system.img
source /atlantis/system/atlantis.conf
SYSTEM_IMAGE="system_${ACTIVE_SLOT}.img"
APP_BASE="/atlantis/app/app-base.img"
APP_BASE_CONF="/atlantis/app/conf/app-base.conf"
CONTAINER_DIR="/atlantis/app/app-container"
OVERLAY_RW="$CONTAINER_DIR/rw"
OVERLAY_WORK="$CONTAINER_DIR/work"
MOUNTPOINT="$CONTAINER_DIR/mnt"
MNT_BASE="/mnt/atlantis-base"

echo "[INFO] Creating needed directories..."
# creating needed dirs
mkdir -p "$MOUNTPOINT"
mkdir -p $OVERLAY_RW/upper $OVERLAY_WORK/work

# if already mounted: unmount
umount -R "$MOUNTPOINT" 2>/dev/null || true

# check for app-base
if [[ ! -f "$APP_BASE_CONF" ]]; then
    echo "[INFO] System as app-base."
    # mounting overlay
    echo "[INFO] Mounting App-Container..."
	mount -t overlay overlay -o \
    	lowerdir="/atlantis/system/$SYSTEM_IMAGE",upperdir=$OVERLAY_RW,workdir=$OVERLAY_WORK \
    	"$MOUNTPOINT"
else
	echo "[INFO] Extra app-base.img."
	echo "[INFO] Mounting app-base..."
	mount -o loop,ro "$APP_BASE" "$MNT_BASE"

	echo "[INFO] Mounting app-container..."
	# mounting overlay
	mount -t overlay overlay -o \
		lowerdir=$MNT_BASE,upperdir=$OVERLAY_RW/upper,workdir=$OVERLAY_WORK/work \
    	"$MOUNTPOINT"
fi

# chroot relevant bind mounts
echo "[INFO] Chroot relevant bind mounts..."
mount --bind /dev "$MOUNTPOINT/dev"
mount --bind /proc "$MOUNTPOINT/proc"
mount --bind /sys "$MOUNTPOINT/sys"
mount --bind /atlantis/etc "$MOUNTPOINT/etc"
mount --bind /atlantis/var "$MOUNTPOINT/var"
mount --bind /atlantis/home "$MOUNTPOINT/home"

# sync desktop entries
#/usr/local/bin/atl sync-desktop

echo "[OK] App-Container mounted."

