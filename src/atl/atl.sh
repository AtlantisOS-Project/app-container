#!/bin/bash
# /usr/bin/atl
# atl is the high-level management tool for the AtlantisOS system, the app container, and all additional components.

set -e

CONTAINER_NAME="atl-app"
CONTAINER_PATH="/atlantis/app/app-container"
WHITE_LIST="/atlantis/atl/app/system-whitelist.conf"
BLACK_LIST="/atlantis/atl/app/system-blacklist.conf"
CONFIG_ATL="/atlantis/atl/atl.conf"
MOUNTPOINT="$CONTAINER_PATH/mnt"
# add infos from atl.conf
source "$CONFIG_ATL"
# get the active system.img
source /atlantis/system/atlantis.conf
# the mount directory for installing direct in the system.img
MNT_DIR="mnt/system"

# check if cmd are in the black- or the whitelist
in_list() {
    local cmd="$1"
    local list="$2"
    grep -qx "$cmd" "$list" 2>/dev/null
}

# run a command in the container
run_in_container() {
    systemd-run --quiet --wait -M "$CONTAINER_NAME" --pipe "$@"
}

# check if the system using a app-container
check_container() {
	if [[ "$SYSTEM_MODE" == "blank" ]]; then
		echo "[WARNING] This system does not use an App-Container."
		echo "[WARNING] Commands are not executed."
		exit 0
	fi
}

# show the info about atl
show_help() {
    cat <<EOF
AtlantisOS Tool (atl) - System & App Container Management

Usage:
  atl <command> [arguments]

Container Management:
  atl status             - Display container status
  atl --start            - Start container (requires mounted container)
  atl --start-full       - Mount and start container
  atl --stop             - Stop container
  atl --stop-full        - Stop and unmount container
  atl --reboot           - Restart container (stop + remount + start)
  atl --reboot-full      - Full reboot (stop + unmount + mount + start)
  atl --container-mount  - Mount the app-container
  atl --container-umount - Unmount the app-container
  atl apps               - Display all installed apps in the container
  atl help               - Display this help page

Updates (App-Container):
  atl update             - Update apps inside the container (apt/snap/flatpak)
  atl upgrade-full       - Perform a full container base upgrade (e.g. Ubuntu noble → plucky)
  atl upgrade-full --dangerous
                         - Perform upgrade ignoring upgrade lock

System (Host):
  atl system-update      - Update host system
  atl system-upgrade     - Upgrade host system distribution
  atl install <pkg>      - Install package(s) into inactive system.img
  atl install <pkg> --dangerous
                         - Install even if system lock is set
  atl upgrade-lock <y|n> - Set upgrade lock for container
  atl system-lock <y|n>  - Set system lock for host updates
  atl set-standard-exe   - Set default execution target for commands
  	--system			 - Hostsystem as standard
  	--container			 - App-Container as standard
  atl set-default-system-mode
  						 - Setting a new system mode

Notes:
- Commands in the whitelist run directly on the host system.
- Commands in the blacklist or unknown commands run inside the container.
- Use 'atl --start-full' if the container is not mounted yet.
- The upgrade lock (atl.conf: CON_UPGRADE_LOCK) may prevent container upgrades.
- Use '--dangerous' to ignore locks (upgrade/system).
- Setting a new system mode is not recommended due to the high risk to the stability and functionality of the system.
- Use 'atl set-default-system-mode --ignore-security --dangerous --force-ignore-security-flags' to force a new system mode.
EOF
}

# function that start the container
start_container() {
	CONTAINER_DIR="/atlantis/app/app-container"
	MNT="$CONTAINER_DIR/mnt"

	# check that the container is mounted
	if ! mountpoint -q "$MNT"; then
    	echo "[INFO] Mounting App-Container..."
    	/usr/bin/app-container-mount.sh
	fi
	echo "[INFO] Starting App-Container..."
	/usr/bin/atl-app-runtime.sh
	echo "[OK] App-Container started."
}

# function that moun the inactive system.img


# function that controll the upgrades in the app-container
container_upgrade() {
    local dangerous="$1"

    echo "[INFO] Active upgrade lock: $CON_UPGRADE_LOCK"
    case "$CON_UPGRADE_LOCK" in
        y|Y|j|J)
        	# ignore the upgrade lock
            if [ "$dangerous" = "--dangerous" ]; then
                echo "[WARNING] Upgrade lock is set, but --dangerous was used!"
                echo "[WARNING] Proceeding anyway..."
                run_in_container do-release-upgrade
                exit 0
            fi
            # upgrade lock → no upgrade
            echo "[INFO] No upgrades are currently available."
            echo "[WARNING] When manually removing the upgrade lock, compatibility issues may arise between the app container and the system."
            exit 0
            ;;
        n|N)
            echo "[INFO] Upgrades can be performed."
            run_in_container do-release-upgrade
            exit 0
            ;;
        *)
            echo "[ERROR] Upgrade lock is in an undefined state."
            echo "[WARNING] When manually removing the upgrade lock, compatibility issues may arise between the app container and the system."
            exit 0
            ;;
    esac
}


# function that starting the main system updater
# Currently, these are only dummy functions.
system_update() {
	echo "[INFO] Starting Systemupdater..."
	# More code will follow here later.
}

# function that starting the main system updater, but with the option to upgrade
# Currently, these are only dummy functions.
system_upgrade() {
	echo "[INFO] Starting Systemupdater..."
	# More code will follow here later.
}

# install app in the inactive system image
install_system() {
	local application="$1"
	local dangerous="$2"
	if [[ $SYSTEM_LOCK == 'n' || $SYSTEM_LOCK == 'N' || "$dangerous" == "--dangerous" ]]; then
		mkdir -p "$MNT_DIR"
		SYSTEM_IMAGE=""
		# get the inactive slot
		case "$ACTIVE_SLOT" in
			a)
				# active = a → inactive b
				SYSTEM_IMAGE="system_b.img"
				echo "[INFO] Mounting system.img..."
				sudo mount "$SYSTEM_IMAGE" "$MNT_DIR"
				;;
			b)
				# active = b → inactive a
				SYSTEM_IMAGE="system_a.img"
				echo "[INFO] Mounting system.img..."
				sudo mount "$SYSTEM_IMAGE" "$MNT_DIR"
				;;
		esac		
		# add mount binds
		echo "[INFO] Adding mount binds..."
		sudo mount --bind /dev "$MNT_DIR/dev"
		sudo mount --bind /proc "$MNT_DIR/proc"
		sudo mount --bind /sys "$MNT_DIR/sys"
		
		# installing all tools from input
		echo "[INFO] Installing..."
		sudo chroot "$MNT_DIR" bash -c "
		export DEBIAN_FRONTEND=noninteractive
		apt update
		apt install -y $application"
		echo "[OK] $application installed"
		# unmount 
		echo "[INFO] Unmount everything..."
		sudo umount "$MNT_DIR/dev"
		sudo umount "$MNT_DIR/proc"
		sudo umount "$MNT_DIR/sys"
		sudo umount "$MNT_DIR"

		# cleanup
		echo "[INFO] Running cleanup..."
		rmdir "$MNT_DIR"

		echo "[OK] System image created: $SYSTEM_IMG"
	fi
}

# function that set a new lock for system/upgrade
set_new_lock() {
    local typ="$1"
    local status="$2"
    local dangerous="$3"
    
    if [[ "$dangerous" == "--dangerous" ]]; then
        case "$typ" in
            upgrade)
                sed -i "s/^CON_UPGRADE_LOCK=.*/CON_UPGRADE_LOCK=$status/" "$CONFIG_ATL"
                ;;
            system)
                sed -i "s/^SYSTEM_LOCK=.*/SYSTEM_LOCK=$status/" "$CONFIG_ATL"
                ;;
            standard)
                sed -i "s/^EXE_STANDARD=.*/EXE_STANDARD=$status/" "$CONFIG_ATL"
                ;;
        esac
    else
        case "$typ" in
            standard)
                sed -i "s/^EXE_STANDARD=.*/EXE_STANDARD=$status/" "$CONFIG_ATL"
                ;;
            *)
                echo "[ERROR] Unknown command!" 
                echo "[INFO] Use 'atl help' to find a complete list of available commands for atl."
                ;;
        esac
        exit 0
    fi
}

# function that set a new system mode
set_system_mode() {
	local status="$1"
	local ignore="$2"
	local dangerous="$3"
	local force="$4"
	
	if [[ "$ignore" == "--ignore-security" && "$dangerous" == "--dangerous" && "$force" == "--force-ignore-security-flags" ]]; then
		echo "[DANGER] This may cause damage to the system!"
		echo "[DANGER] By manually changing the system mode, it is likely that some functions will not work correctly, will malfunction, or will not work at all!"
		echo "[DANGER] Changing the system mode does not guarantee that the system will function, and no assistance will be provided to repair this system!"
		echo "[DANGER] Would you like to force a new system mode?"
		read -n1 -s answer
    	case "$answer" in 
        	force)
				sed -i "s/^SYSTEM_MODE=.*/SYSTEM_MODE=$status/" "$CONFIG_ATL"
				echo "[OK] New system mode set!"
				echo "[INFO] System Mode: $status"
				;;
			* )
				echo "[INFO] No new system mode set!"
				;;
		esac
	fi
}

# managment
case "$1" in
	# atl help
    help|-h|-help|--help)
        show_help
        exit 0
        ;;
    # show status about the container
    status)
        machinectl status "$CONTAINER_NAME" || echo "[INFO] Container not running."
        exit 0
        ;;
    # start the container
    --start)
    	check_container
        if ! mountpoint -q "$MNT"; then
    		echo "[ERROR] App-Container not mounted."
    		echo "[INFO] Use 'atl --start-full'."
    	else
    		echo "[INFO] Starting App-Container..."
			/usr/bin/atl-app-runtime.sh
		fi 
        exit 0
        ;;
    # moun the container and start it
    --start-full)
    	check_container
    	start_container
    	exit 0
    	;;
    # stop the container
    --stop)
        check_container
        machinectl stop "$CONTAINER_NAME"
        exit 0
        ;;
    # stop and unmount the container
    --stop-full)
    	check_container
    	if ! mountpoint -q "$MNT"; then
    		echo "[INFO] App-Container already unmounted."
    	else
    		echo "[INFO] Unmounting App-Container..."
    		/usr/bin/app-container-umount.sh
		fi 	
		exit 0
		;;
    # reboot the container
    --reboot)
        check_container
        machinectl stop "$CONTAINER_NAME"
        umount "$CONTAINER_PATH" || true
        /usr/local/bin/app-container-mount
        machinectl start "$CONTAINER_NAME"
        exit 0
        ;;
    # reboot the container with mount and unmount
    --reboot-full)
    	check_container
    	if ! mountpoint -q "$MNT"; then
    		echo "[INFO] App-Container already unmounted."
    	else
    		echo "[INFO] Unmounting App-Container..."
    		/usr/bin/app-container-umount.sh
		fi 
		sleep 5
		start_container
		exit 0
		;;
    # mount the app-container
    --container-mount)
    	check_container
    	if ! mountpoint -q "$MNT"; then
    		echo "[INFO] Mounting App-Container..."
    		/usr/bin/app-container-mount.sh
		fi  
		exit 0
		;;
	# unmount the container
	--container-umount)
		check_container
		if ! mountpoint -q "$MNT"; then
    		echo "[INFO] App-Container already unmounted."
    	else
    		echo "[INFO] Unmounting App-Container..."
    		/usr/bin/app-container-umount.sh
		fi 	
		exit 0
		;;
    # show all apps, that installed in the container
    apps)
        check_container
        echo "=== Installed Apps (APT): ==="
        run_in_container dpkg-query -W -f='${binary:Package}\n' | sort
        echo
        echo "=== Installed Apps (Snap): ==="
        run_in_container snap list
        echo
        echo "=== Installed Apps (Flatpak): ==="
        run_in_container flatpak list
        exit 0
        ;;
    # update all apps in the container
    update)
        check_container
        run_in_container apt update 
        run_in_container apt upgrade -y
        run_in_container snap refresh
        run_in_container flatpak update -y
        run_in_container apt autoremove
        run_in_container apt autoclean
        run_in_container flatpak uninstall --unused -y
        exit 0
        ;;
    # upgrade all apps in the container
    upgrade-full)
        check_container
        container_upgrade "$2"
        exit 0
        ;;

    # running a update on the main system
    # will be implemented later with the updater
    system-update)
        system_update
        exit 0
        ;;
    # running a upgrade on the main system
    # will be implemented later with the updater
    system-upgrade)
        system_upgrade
        exit 0
        ;;    
    # install app direct in the inactive system.img
    install)
    	INSTALL="$2"
    	install_system "$INSTALL" "$3"
    	exit 0
    	;;
    # config upgrade lock
    upgrade-lock)
    	STATUS="$2"
    	check_container
    	set_new_lock upgrade "$STATUS" "$3"
    	exit 0
    	;;
    # config system lock
    system-lock)
    	STATUS="$2"
    	set_new_lock system "$STATUS" "$3"
    	exit 0
    	;;
    # set the standard target for run commands
    set-standard-exe)
    	STATUS="$2"
    	check_container
    	set_new_lock standard "$STATUS"
    	exit 0
    	;;	
   	# set new system mode → system with app-container/no app-container
   	set-default-system-mode)
   		STATUS="$2"
   		IGNORE="$3"
   		DANGEROUS="$4"
   		FORCE="$5"
   		set_system_mode "$STATUS" "$IGNORE" "$DANGEROUS" "$FORCE"
   		exit 0
   		;;
esac

# this checks every other command and executes it either in the app container or on the main system
CMD="$1"
shift || true
# check in the whitelist
if in_list "$CMD" "$WHITE_LIST"; then
    exec "$CMD" "$@"
# check in the blacklist
elif in_list "$CMD" "$BLACK_LIST"; then
    run_in_container "$CMD" "$@"
# other commands
# if system exe are the standard
elif [[ "$EXE_STANDARD" == "system" ]]
	exec "$CMD" "$@"
else
    # default: run the command in the container
    run_in_container "$CMD" "$@"
fi

