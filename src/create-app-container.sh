#!/bin/bash
# create-app-container.sh
# script that create the main app-container with two different bases
# "base"  = own minimal base (apps-base.img)
# "system" = system.img as base for app-container
set -e

# get the active system.img
source /atlantis/system/atlantis.conf

echo "[INFO] Active Slot: $ACTIVE_SLOT"
echo "[INFO] System A: $SLOT_A"
echo "[INFO] System B: $SLOT_B"

# configs
CONTAINER_DIR="/atlantis/app/app-container"
BASE_IMG_A="/atlantis/system/system_${ACTIVE_SLOT}.img"      # base = system.img
BASE_IMG_B="/atlantis/app/apps-base.img"   # own minimal base (apps-base.img)
OVERLAY_RW="$CONTAINER_DIR/rw"
OVERLAY_WORK="$CONTAINER_DIR/work"
MOUNTPOINT="$CONTAINER_DIR/mnt"

# standard packages from the config file
APT_PACKAGES=""
SNAP_PACKAGES=""
FLATPAK_PACKAGES=""
# config file
CONFIG_FILE="/atlantis/app/conf/app-install.conf"

# get the packages for snap, apt, flatpak
get_packages() {
	# check for the file
	if [[ ! -f "$CONFIG_FILE" ]]; then
    	echo "[ERROR] Configuration file not found!"
    	exit 1
	fi

	# Read file line by line
	while IFS='=' read -r key value; do
    	# Remove leading and trailing spaces
    	key=$(echo "$key" | xargs)
    	value=$(echo "$value" | xargs)

    	# Check for the key and assign the value
    	case "$key" in
    	    APT)
    	        APT_PACKAGES="$value"
    	        ;;
    	    SNAP)
    	        SNAP_PACKAGES="$value"
    	        ;;
    	    Flatpak)
    	        FLATPAK_PACKAGES="$value"
    	        ;;
    	esac
	done < "$CONFIG_FILE"

	# ouput for the packages
	echo "[INFO] APT Packages: $APT_PACKAGES"
	echo "[INFO] SNAP Packages: $SNAP_PACKAGES"
	echo "[INFO] Flatpak Packages: $FLATPAK_PACKAGES"
}

# check for system.img
use_system_img() {
    if [[ ! -f "$BASE_IMG_A" ]]; then
        echo "[ERROR] $BASE_IMG_A not found."
        exit 1
    fi
    echo "[INFO] Use system.img as a basis ($BASE_IMG_A)"
}

# create the main app-container
create_container() {
    local base="$1"

    echo "[INFO] Creating App-Container with base: $base"

    # setup working dirs
    mkdir -p "$OVERLAY_RW/upper" "$OVERLAY_WORK/work" "$MOUNTPOINT"
	
    # mount overlay
    echo "[INFO] Mounting app-container..."
    mount -t overlay overlay -o \
        lowerdir=$base,upperdir=$OVERLAY_RW/upper,workdir=$OVERLAY_WORK/work \
        "$MOUNTPOINT"

    # setup chroot essentials
    echo "[INFO] Mounting essentials..."
    mount --bind /dev "$MOUNTPOINT/dev"
    mount --bind /proc "$MOUNTPOINT/proc"
    mount --bind /sys "$MOUNTPOINT/sys"
    mount --bind /atlantis/etc "$MOUNTPOINT/etc"
	mount --bind /atlantis/var "$MOUNTPOINT/var"
	mount --bind /atlantis/home "$MOUNTPOINT/home"
	
	echo "[INFO] Installing extra packages..."
    # install APT packages 
    if [ -n "$APT_PACKAGES" ]; then
        echo "[INFO] Installing APT packages..."
        chroot "$MOUNTPOINT" apt update
        chroot "$MOUNTPOINT" apt install -y $APT_PACKAGES
    fi

    # enable Snap
    if echo "$APT_PACKAGES" | grep -qw "snapd"; then
    	echo "[INFO] Snapd installed. Start snap."
    	chroot "$MOUNTPOINT" systemctl enable snapd.service || true
	fi
	# install Ssnaps
	if [ -n "$SNAP_PACKAGES" ]; then
    	echo "[INFO] Installing Snap packages..."
    	chroot "$MOUNTPOINT" snap install $SNAP_PACKAGES || echo "[INFO] Snapd will run after container boot!"
	fi

    # install Flatpaks
    if [ -n "$FLATPAK_PACKAGES" ]; then
        echo "[INFO] Installing Flatpak packages..."
        chroot "$MOUNTPOINT" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        chroot "$MOUNTPOINT" flatpak update -y
        chroot "$MOUNTPOINT" flatpak install -y $FLATPAK_PACKAGES
    fi

    # cleanup
    echo "[INFO] Running cleanup..."
    chroot "$MOUNTPOINT" apt autoremove -y
    chroot "$MOUNTPOINT" apt autoclean -y
    chroot "$MOUNTPOINT" flatpak uninstall --unused -y
    chroot "$MOUNTPOINT" rm -rf /var/cache/apt/* /tmp/*

    # unmount
    echo "[INFO] Unmount the app-container..."
    umount "$MOUNTPOINT/dev" "$MOUNTPOINT/proc" "$MOUNTPOINT/sys" "$MOUNTPOINT/etc" "$MOUNTPOINT/var" "$MOUNTPOINT/home"
    umount "$MOUNTPOINT"

    echo "[INFO] Container created successfully!"
}


# main function
case "$1" in
    --base)
    	./create-app-base.sh
        create_container "$BASE_IMG_B" # app-base.img
        ;;
    --system)
        create_container "$BASE_IMG_A" # system.img
        ;;
    *)
        echo "[INFO] Usage: $0 --base | --system"
        exit 1
        ;;
esac

