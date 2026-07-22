#!/bin/sh
# Start the libvirt daemons where no init system has set them up.
# Source it (`. helper/prep.sh`) so LIBVIRT_DEFAULT_URI persists in the shell.
# Safe to re-run: already-running daemons just print
# "Unable to obtain pidfile" and are left as-is.

mkdir -p /run/libvirt /var/lib/libvirt /var/log/libvirt /var/lib/libvirt/images

virtlogd -d          # console/log muxer; libvirtd needs it to start guests
libvirtd -d

export LIBVIRT_DEFAULT_URI="qemu+unix:///system?socket=/run/libvirt/libvirt-sock"

virsh list --all     # connectivity check
