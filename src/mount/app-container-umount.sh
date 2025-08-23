#!/bin/bash
# /usr/bin/app-container-umount.sh
# stop the container and unmount it
set -e

MNT_DIR="/atlantis/app/app-container/mnt"
UPPER_DIR="/atlantis/app/app-container/overlay"
WORK_DIR="/atlantis/app/app-container/work"

# stop the app-container via machinctl
echo "[INFO] Stop the App-Container"
if machinectl show atl-app >/dev/null 2>&1; then
    machinectl poweroff atl-app || true
    sleep 2
fi

# unmount of the filesystem
echo "[INFO] Unmount Container-Filesystem..."
# unlink nested mounts
mountpoint -q "$MNT_DIR/proc"   && umount -lf "$MNT_DIR/proc"
mountpoint -q "$MNT_DIR/sys"    && umount -lf "$MNT_DIR/sys"
mountpoint -q "$MNT_DIR/dev"    && umount -lf "$MNT_DIR/dev"
mountpoint -q "$MNT_DIR/etc"   && umount -lf "$MNT_DIR/etc"
mountpoint -q "$MNT_DIR/var"    && umount -lf "$MNT_DIR/var"
mountpoint -q "$MNT_DIR/home"    && umount -lf "$MNT_DIR/home"

# unmount the overlay
if mountpoint -q "$MNT_DIR"; then
    umount -lf "$MNT_DIR"
    echo "[OK] App-Container unmounted."
else
    echo "[INFO] No active mount founded."
fi

# cleanup for the work dir 
echo "[INFO] Running cleanup..."
if [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"/*
fi

echo "[OK] Unmounting finished."
