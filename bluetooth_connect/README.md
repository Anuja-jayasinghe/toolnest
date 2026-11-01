# Bluetooth Connect

Windows only. Connects or disconnects an already-paired Bluetooth device from a small popup list, instead of clicking through Settings. Pair a new device once in Settings > Bluetooth & devices.

```powershell
just bluetooth                              # popup: Enter connects, Ctrl+D disconnects, Esc closes
just bluetooth -Top soundcore               # same, with matching devices listed first
just bluetooth -Name soundcore              # connect by part of the name
just bluetooth -Name soundcore -Disconnect
```

It toggles the device's audio and input services through Windows' `BluetoothSetServiceState`. Tested on earbuds; keyboards, mice and controllers may connect on their own or not respond. Windows' own "connected" flag is unreliable, so the picker does not show state.

The dotfiles repo binds Win+K to this picker with AutoHotkey.
