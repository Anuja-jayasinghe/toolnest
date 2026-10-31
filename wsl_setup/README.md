# WSL Setup

Windows only. Installs WSL with Ubuntu, then configures the distro. Not part of the automatic PC setup.

```powershell
just wsl-setup -Install   # from an elevated terminal; reboot afterwards and create the Linux user
just wsl-setup            # then, from a normal terminal, configure the distro
```
