#!/bin/sh

qemu-img create \
  -F qcow2 -b /var/lib/libvirt/isos/ready/TrueNAS-SCALE-25.10.4-golden.qcow2 \
  -f qcow2 /var/lib/libvirt/images/test-truenas.qcow2

