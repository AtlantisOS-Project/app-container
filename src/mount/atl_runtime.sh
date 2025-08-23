#!/bin/bash
# /usr/bin/atl-app-runtime.sh
# start the AtlantisOS app-container with systemd-nspawn
# full hardware + desktop integration (GPU, Audio, Wayland/X11, USB, DBus)
set -e

CONTAINER_DIR="/atlantis/app/app-container"
MNT="$CONTAINER_DIR/mnt"

# systemd-nspawn machine name
MACHINE_NAME="atl-app"

# check that the container is mounted
if ! mountpoint -q "$MNT"; then
    echo "[ERROR] App container is not mounted!"
    exit 1
fi

# User-Data
USER_UID=$(id -u)
USER_GID=$(id -g)
XDG_RUNTIME_DIR="/run/user/$USER_UID"

echo "[INFO] Starting App-Container for user $USER_UID (gid $USER_GID)..."

# include GPU, Audio, USB, X11, Wayland, DBus in the container 
EXTRA_BINDS=(
  "--bind=/dev/dri"
  "--bind=/dev/snd"
  "--bind=/dev/bus/usb"
  "--bind=$XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR"
  "--bind=/tmp/.X11-unix:/tmp/.X11-unix"
  "--bind=/usr/share/applications"
  "--bind=/run/dbus:/run/dbus"
  "--bind=/dev/kvm"
)

# Wayland socket
if [ -S "$XDG_RUNTIME_DIR/wayland-0" ]; then
  echo "[INFO] Include Wayland socket..."
  EXTRA_BINDS+=("--bind=$XDG_RUNTIME_DIR/wayland-0:$XDG_RUNTIME_DIR/wayland-0")
fi

# PulseAudio socket
if [ -S "$XDG_RUNTIME_DIR/pulse/native" ]; then
  echo "[INFO] Include PulseAudio socket..."
  EXTRA_BINDS+=("--bind=$XDG_RUNTIME_DIR/pulse/native:$XDG_RUNTIME_DIR/pulse/native")
fi

# PipeWire socket (modern audio/video)
if [ -S "$XDG_RUNTIME_DIR/pipewire-0" ]; then
  echo "[INFO] Include PipeWire socket..."
  EXTRA_BINDS+=("--bind=$XDG_RUNTIME_DIR/pipewire-0:$XDG_RUNTIME_DIR/pipewire-0")
fi

# NVIDIA devices
for dev in /dev/nvidia*; do
  if [ -e "$dev" ]; then
    echo "[INFO] Include NVIDIA device: $dev"
    EXTRA_BINDS+=("--bind=$dev:$dev")
  fi
done

# network mode: use host networking
NET_OPT="--network=host"

# run the container with systemd-nspawn
echo "[INFO] Run the container..."
exec systemd-nspawn \
    -D "$MNT" \
    --boot \
    --machine="$MACHINE_NAME" \
    --capability=all \
    $NET_OPT \
    --bind=/atlantis/etc:/etc \
    --bind=/atlantis/var:/var \
    --bind=/atlantis/home:/home \
    "${EXTRA_BINDS[@]}"

echo "[OK] App-Container is running."
