#!/bin/bash
# create-app-base.sh
# create and config the base container for the apps
set -e

# configuration
WORKDIR="/tmp/atlantis-apps-base"
APPS_BASE="/atlantis/app/apps-base.img"
EXCLUDE_LIST="/atlantis/app/conf/apps-exclude.txt"

# create the app-base.img
echo "[INFO] Creating apps-base.img..."
# setup working dir
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
	
# init base for the container 
echo "[INFO] Init container base..."
# ubuntu 24.04
debootstrap --variant=minbase noble "$WORKDIR" http://archive.ubuntu.com/ubuntu
# update system and install some basics
echo "[INFO] Install basic tools..."
chroot "$WORKDIR" apt-get update && apt-get upgrade
chroot "$WORKDIR" apt-get clean

rm -rf "$WORKDIR"/var/lib/apt/lists/* "$WORKDIR"/var/cache/* "$WORKDIR"/tmp/*

if [[ ! -f "$EXCLUDE_LIST" ]]; then
	echo "boot" > "$EXCLUDE_LIST"
    echo "proc" >> "$EXCLUDE_LIST"
    echo "sys" >> "$EXCLUDE_LIST"
    echo "dev" >> "$EXCLUDE_LIST"
    echo "run" >> "$EXCLUDE_LIST"
fi
# create a squashfs image
echo "[INFO] Creating squashfs image..."
mkdir -p "$(dirname "$APPS_BASE")"
mksquashfs "$WORKDIR" "$APPS_BASE" -e $(cat "$EXCLUDE_LIST")

# create app-base.conf
echo "[INFO] Creating app-base.conf..."
echo "APP_BASE=${APPS_BASE}" > /atlantis/app/conf/app-base.conf

echo "[OK] apps-base.img successfully created under: $APPS_BASE"
