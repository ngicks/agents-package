---
name: kvm-in-podman
description: "Run and manage KVM-accelerated VMs with libvirt and virsh in a minimal environment (e.g. inside a container) without systemd: start the daemons by hand, define domains, drive the VM lifecycle, and persist or restore images and definitions. Use when asked to boot a VM, run tests in a VM, or manage qemu/libvirt where no init system set libvirt up."
---

# libvirt/virsh without an init system

How to run VMs through libvirt when nothing has set it up for you — no
systemd units, no distro socket activation. Works the same on a host or
inside a container; a container adds no virtualization level (VMs run at
the same level as host VMs).

## Prerequisites

Minimum, each implied by a step below:

- `/dev/kvm`, readable+writable by the user running qemu. Without it qemu
  falls back to TCG emulation — functional but usually too slow for real work.
- Binaries: `libvirtd` (monolithic daemon), `virtlogd`, `virsh`,
  `qemu-system-<arch>`, `qemu-img`.
- Writable `/run/libvirt`, `/var/lib/libvirt`, `/var/log/libvirt`
  (create them if absent), and permission to run the daemons — simplest as
  root; as a non-root user use `qemu:///session` semantics instead.
- Nothing else for user-mode networking. Optional features pull in extras:
  tap/bridge networking needs `/dev/net/tun` + CAP_NET_ADMIN, the libvirt
  NAT `default` network additionally needs `dnsmasq`, TPM needs `swtpm`,
  virtiofs shares need `virtiofsd`, passt backend needs `passt`.

Check first; if `/dev/kvm` or a binary is missing, report it rather than
working around it silently.

## Start the daemons

```sh
mkdir -p /run/libvirt /var/lib/libvirt /var/log/libvirt
virtlogd -d          # console/log muxer; libvirtd needs it to start guests
libvirtd -d
export LIBVIRT_DEFAULT_URI="qemu+unix:///system?socket=/run/libvirt/libvirt-sock"
virsh list --all     # connectivity check
```

The explicit URI sidesteps client autoprobing, which fails when the build's
compiled-in socket path differs from where the daemon actually listens
(symptom: bare `virsh` says no daemon is running while `libvirtd` is up).

## Prepare a disk

Never boot a base/golden image read-write. Give each VM a qcow2 overlay and
leave the base opened read-only as its backing file (paths must stay valid
from the daemon's point of view):

```sh
qemu-img create -f qcow2 -b /abs/path/base.qcow2 -F qcow2 \
  /var/lib/libvirt/images/<name>.qcow2
```

## Define and run a domain

Minimal headless domain XML (`<name>.xml`):

```xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>NAME</name>
  <memory unit='MiB'>4096</memory>
  <vcpu>4</vcpu>
  <os><type arch='x86_64' machine='q35'>hvm</type></os>
  <cpu mode='host-passthrough'/>
  <devices>
    <!-- needed when qemu is not at a distro-standard path -->
    <emulator>/abs/path/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/NAME.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <interface type='user'><model type='virtio'/></interface>
    <serial type='pty'/><console type='pty'/>
  </devices>
  <!-- user-mode (SLIRP) nics take port forwards only via raw qemu args -->
  <qemu:commandline>
    <qemu:arg value='-netdev'/>
    <qemu:arg value='user,id=fwd0,hostfwd=tcp:127.0.0.1:2222-:22'/>
    <qemu:arg value='-device'/>
    <qemu:arg value='virtio-net,netdev=fwd0'/>
  </qemu:commandline>
</domain>
```

Omit `<graphics>` entirely for headless. Only reference devices the
prerequisites cover: `<interface type='network'>` needs the NAT extras,
`<tpm>` needs swtpm, virtiofs `<filesystem>` needs virtiofsd.

Lifecycle:

```sh
virsh define <name>.xml    # register
virsh start NAME
virsh console NAME         # serial console (exit: Ctrl+])
ssh -p 2222 user@127.0.0.1 # via the hostfwd above
virsh shutdown NAME        # graceful (guest must handle ACPI)
virsh destroy NAME         # hard stop
virsh undefine NAME --nvram
```

One-shot alternative: `virsh create <name>.xml` starts a transient domain
that unregisters itself on shutdown — a good default for throwaway VMs.

## Persist / restore

Treat everything under `/var/lib/libvirt` as disposable state; persist a VM
deliberately by exporting both halves:

```sh
qemu-img convert -O qcow2 /var/lib/libvirt/images/NAME.qcow2 <dest>.qcow2  # flattens backing chain
virsh dumpxml NAME > <dest>.xml
```

Dumped XML embeds absolute paths (disks, nvram) and host-specific bits;
rewrite them for the destination before reuse. Restore = recreate an
overlay backed by the saved image, fix paths, `virsh define`.

## Gotchas

- "Failed to get 'write' lock": another qemu has the image open read-write
  (qemu takes inode-level OFD locks, effective even across containers/mount
  namespaces). Use an overlay or another image; never
  `file.locking=off`.
- Guests on user-mode networking reach the hosting side's loopback services
  via the SLIRP gateway `10.0.2.2`; inbound only via `hostfwd`.
- Put disk-heavy I/O on a real filesystem; overlayfs (e.g. a container's
  root) penalizes large writes.
- Verify acceleration when in doubt: `virsh domcapabilities` or QMP
  `query-kvm` should report KVM usable/enabled.
