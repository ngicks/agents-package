#!/bin/sh
# Overlay on the Ubuntu cloud image + NoCloud seed served over HTTP.
# The cloud image has no default login; without ISO/vfat tools (genisoimage,
# mkisofs, mtools all absent in this environment) a seed disk cannot be built,
# so serve the seed files over loopback HTTP instead and let the SMBIOS serial
# in def.xml (ds=nocloud;s=http://10.0.2.2:8000/) point cloud-init at it.
# The server is only needed for the first boot of a fresh overlay.

qemu-img create \
  -F qcow2 -b /var/lib/libvirt/isos/ready/ubuntu-24.04-server-cloudimg-amd64.img \
  -f qcow2 /var/lib/libvirt/images/ubuntu-console.qcow2 20G

cd "$(dirname "$0")/seed" && python3 -m http.server 8000 --bind 127.0.0.1 &
