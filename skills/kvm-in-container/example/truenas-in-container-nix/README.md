## Example: TrueNAS in podman nix managed image

- port is forwarded
  - 80 -> 10080
  - 443 -> 10443
  - 1000 -> 11000
- forward to host's port: `-p 127.0.0.1:10080:10080/tcp -p 127.0.0.1:10443:10443/tcp -p 127.0.0.1:11000:11000/tcp`
