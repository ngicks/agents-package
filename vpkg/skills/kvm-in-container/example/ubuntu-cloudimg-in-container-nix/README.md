## Example: Ubuntu cloud image, controlled via serial console

Boots the stock `ubuntu-24.04-server-cloudimg-amd64.img` in a podman/nix
environment and proves the guest is controllable over the serial console
alone — no SSH, no guest agent, no graphics.

- Files
  - `prep-image.sh`: creates the qcow2 overlay, serves the seed over HTTP.
  - `seed/`: NoCloud `meta-data` / `user-data` / `vendor-data`
    (sets password `ubuntu` for user `ubuntu`, enables ssh password auth).
  - `def.xml`: the domain definition.
  - `console_drive.py`: logs in and runs commands through the console pty.

### Credentials without a seed disk

Cloud images ship no default login, and this environment has no
genisoimage/mkisofs/mtools to build a cidata ISO or vfat seed disk.
Instead the seed is plain files over loopback HTTP:

- `prep-image.sh` runs `python3 -m http.server 8000 --bind 127.0.0.1`
  inside `seed/`.
- `def.xml` passes `-smbios 'type=1,serial=ds=nocloud;s=http://10.0.2.2:8000/'`;
  cloud-init reads the datasource hint from the SMBIOS serial and fetches
  the seed through the SLIRP host alias `10.0.2.2`.
- Only the first boot of a fresh overlay needs the server; afterwards the
  credentials are baked into the overlay.

### Pitfalls this example encodes

- `machine='pc'`, not q35: on q35 the virtio disk lands behind a
  pcie-root-port, the noble kernel logs
  `Unable to change power state from D3cold to D0` and drops to initramfs
  with no disk (SKILL.md Gotchas). i440fx boots clean.
- The nic is raw qemu args only (no `<interface>` element) so one SLIRP nic
  carries both the ssh hostfwd (`127.0.0.1:2222` → 22) and the `10.0.2.2`
  route to the seed. A raw `-device` needs an explicit `bus=pci.0,addr=...`
  or it collides with slots libvirt already allocated.

### Run

```sh
./prep-image.sh
virsh define def.xml && virsh start ubuntu-console
python3 console_drive.py "$(virsh ttyconsole ubuntu-console)"
```

Expected tail (first boot takes ~1–2 min for cloud-init to apply the seed):

```
CONSOLE-OK ubuntu-console 6.8.0-117-generic
uid=1000(ubuntu) gid=1000(ubuntu) groups=1000(ubuntu),4(adm),...
```

Interactive alternative: `virsh console ubuntu-console` (exit: Ctrl+]),
or `ssh -p 2222 ubuntu@127.0.0.1`. The guest agent channel is defined but
the cloud image does not ship qemu-ga enabled — install
`qemu-guest-agent` in the guest before relying on `guest-exec`.
