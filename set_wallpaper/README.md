# Set Wallpaper

Windows only. Sets the desktop wallpaper from the collection in the dotfiles repo (`../dotfiles/assets/wallpapers`) or from any image path.

```powershell
just wallpaper                         # first image in the collection
just wallpaper -Name file.jpg          # a specific one
just wallpaper -Random                 # any from the collection
just wallpaper -Path D:\pics\x.png     # any image on disk
```
