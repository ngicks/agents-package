---
name: kvm-in-container
description: "Run and manage KVM-accelerated VMs with libvirt and virsh in a minimal environment (e.g. inside a container) without systemd: start the daemons by hand, define domains, drive the VM lifecycle, and persist or restore images and definitions. Use when asked to boot a VM, run tests in a VM, debug a silent or hung guest, or manage qemu/libvirt where no init system set libvirt up."
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
  In a rootless podman container the device may show owner `nobody:nogroup`
  (host uid outside the container's map) — ignore ownership, only the mode
  bits (`rw` for your uid) matter.
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

## Driver config (qemu.conf)

qemu.conf lives under the build's compiled-in sysconfdir — not always
`/etc/libvirt`. Nixpkgs builds read `/var/lib/libvirt/qemu.conf` and
silently ignore anything written to `/etc/libvirt`. Settings commonly
needed inside a container, each fixing a `virsh create` failure:

```ini
# fixes: Unable to set XATTR trusted.libvirt.security.dac ... Operation not
# permitted (trusted.* xattrs need CAP_SYS_ADMIN on the host)
security_driver = "none"
remember_owner = 0

# fixes: Failed to create v2 cgroup ... Read-only file system
cgroup_controllers = []
```

Write it before starting libvirtd; if the daemon is already running,
restart it to apply. Wrapper builds run under mangled/truncated process
names (seen: `.libvirtd-wrapp`, `.qemu-system-x8`, `passt.avx2`);
if `ps`/`pgrep` are absent, match loosely against `/proc/*/comm`.

## Start the daemons

Run `helper/prep.sh` (relative to this skill's directory) — source it so
the `LIBVIRT_DEFAULT_URI` export lands in your shell:

```sh
. helper/prep.sh
```

The script sets an explicit URI to sidestep client autoprobing, which
fails when the build's compiled-in socket path differs from where the
daemon actually listens (symptom: bare `virsh` says no daemon is running
while `libvirtd` is up).

## Prepare a disk

Never boot a base/golden image read-write. Give each VM a qcow2 overlay and
leave the base opened read-only as its backing file (paths must stay valid
from the daemon's point of view):

```sh
qemu-img create -f qcow2 -b /var/lib/libvirt/isos/base.qcow2 -F qcow2 \
  /var/lib/libvirt/images/NAME.qcow2
```

## Define and run a domain

Minimal headless domain XML (`NAME.xml`):

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
  <!-- user-mode (SLIRP) nics take port forwards only via raw qemu args;
       this adds a SECOND nic carrying the forward — drop the <interface>
       element above if the guest should see only the forwarded nic -->
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

Adjust per guest:

- Machine type: on `q35`, virtio devices sit behind PCIe root ports and
  are exposed modern-only; some guest kernels fail that probe and boot
  with no disks at all (see Gotchas). `machine='pc'` (i440fx) makes
  virtio transitional on plain PCI and is the safe fallback. Install and
  run a guest on the same machine type so its installer-built initramfs
  matches the boot hardware.
- Disk serials: give data disks `<serial>ID</serial>` inside `<disk>` —
  it surfaces as `/dev/disk/by-id/virtio-ID`, and appliance guests
  (e.g. TrueNAS) hide serial-less disks from pool creation. Hard cap
  20 bytes (VIRTIO_BLK_ID_BYTES); longer values are silently truncated.
- Guest agent: add the channel below; guests that ship qemu-ga start it
  automatically once the device exists.

  ```xml
  <channel type='unix'>
    <target type='virtio' name='org.qemu.guest_agent.0'/>
  </channel>
  ```

- Port forwards without raw qemu args: with `passt` installed
  (libvirt ≥ 9.2), replace the `<interface>` + `<qemu:commandline>` pair
  with a natively forwarding interface. Either way NIC changes don't
  hot-apply — destroy and re-create the domain.

  ```xml
  <interface type='user'>
    <backend type='passt'/>
    <model type='virtio'/>
    <portForward proto='tcp' address='127.0.0.1'>
      <range start='2222' to='22'/>
    </portForward>
  </interface>
  ```

  One `<portForward>` element per range; ports below 1024 (80, 443)
  forward fine when the daemons run as the namespace's root —
  `ip_unprivileged_port_start` (default 1024) blocks them otherwise.

Lifecycle:

```sh
virsh define NAME.xml      # register
virsh start NAME
virsh console NAME         # serial console (exit: Ctrl+])
ssh -p 2222 user@127.0.0.1 # via the hostfwd above
virsh shutdown NAME        # graceful (guest must handle ACPI)
virsh destroy NAME         # hard stop
virsh undefine NAME --nvram
```

One-shot alternative: `virsh create NAME.xml` starts a transient domain
that unregisters itself on shutdown — a good default for throwaway VMs.

With the agent channel defined, verify qemu-ga with
`virsh qemu-agent-command NAME '{"execute":"guest-ping"}'` — expect it to
connect well after boot starts (~2 min for heavyweight guests), so retry
before concluding it's dead. `virsh guestinfo NAME --os --hostname` gives
a fuller readout.

## Script the guest via guest-exec

qemu-ga also runs commands inside the guest — often the cleanest way to
bootstrap an appliance guest (mint credentials, read state) without
scraping its console:

```sh
virsh qemu-agent-command NAME '{"execute":"guest-exec","arguments":
  {"path":"/usr/bin/id","arg":["-u"],"capture-output":true}}'
# → {"return":{"pid":1234}}
virsh qemu-agent-command NAME \
  '{"execute":"guest-exec-status","arguments":{"pid":1234}}'
```

Poll the status call until `"exited":true`; `out-data`/`err-data` are
base64-encoded. Example end-to-end: on TrueNAS, guest-exec
`midclt call api_key.create '{"name":"ci","username":"truenas_admin"}'`,
decode the returned key, then call the REST API from the hosting side
through a 443 port forward with `Authorization: Bearer <key>` — no
console interaction at any point.

## Persist / restore

Treat everything under `/var/lib/libvirt` as disposable state; persist a VM
deliberately by exporting both halves:

```sh
qemu-img convert -O qcow2 /var/lib/libvirt/images/NAME.qcow2 DEST.qcow2  # flattens backing chain
virsh dumpxml NAME > DEST.xml
```

Dumped XML embeds absolute paths (disks, nvram) and host-specific bits;
rewrite them for the destination before reuse. Restore = recreate an
overlay backed by the saved image, fix paths, `virsh define`.

## Debug a guest with no serial output

Some guests write only to the VGA console. Tools that need no guest
cooperation:

- `/var/log/libvirt/qemu/NAME.log` holds the full qemu argv — use it to
  map guest PCI addresses to devices (`bus=pci.4` → guest `0000:04:00.0`).
- `virsh screenshot NAME shot.img` captures the VGA console. Requires a
  video device in the XML (`<video><model type='virtio'/></video>` plus a
  `<graphics>` element — a socket-only one works:
  `<graphics type='vnc' socket='/run/libvirt/NAME-vnc.sock'/>`). The
  command prints the actual format — recent qemu emits PNG directly,
  older builds PPM (convert with e.g. ImageMagick); trust the printed
  type over the file extension.
- `virsh send-key NAME KEY_A ...` types into the guest — enough to drive
  an initramfs/BusyBox shell one keystroke at a time (shifted chars:
  `KEY_LEFTSHIFT KEY_X` in one call). Screenshot after each command to
  read the result.

## Gotchas

- A `q35` guest that seems to hang — `virsh dominfo` CPU time frozen,
  `virsh domblkstat` showing reads but zero writes, serial silent — may
  have failed the modern-only virtio probe. Guest dmesg shows
  `virtio-pci ... Unable to change power state from D3cold to D0` then
  `leaving for legacy driver`; kernels without the legacy fallback (seen:
  TrueNAS SCALE 25.10, kernel 6.12) end up with no disks and no
  virtio-serial, so the agent channel is dead too. Only virtio devices
  directly on the root complex survive. Fix: `machine='pc'`.
- "Failed to get 'write' lock": another qemu has the image open read-write
  (qemu takes inode-level OFD locks, effective even across containers/mount
  namespaces). Use an overlay or another image; never
  `file.locking=off`.
- Guest→hosting-side loopback depends on the backend. SLIRP guests live on
  fixed `10.0.2.x` addressing and reach it via the gateway `10.0.2.2`.
  passt instead copies the hosting namespace's addressing onto the guest —
  the guest gets the same IP as the container's eth0 — and traffic the
  guest sends to its gateway address lands on the hosting side's loopback.
  Inbound either way only via `hostfwd` (SLIRP) or `<portForward>` (passt).
- Put disk-heavy I/O on a real filesystem; overlayfs (e.g. a container's
  root) penalizes large writes.
- Verify acceleration when in doubt: `virsh domcapabilities` or QMP
  `query-kvm` should report KVM usable/enabled.

## Exmaples

- TrueNAS on podman container / nix managed environment: see [./example/truenas-in-container-nix/def.xml](./example/truenas-in-container-nix/def.xml)
