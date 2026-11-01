# Connect or disconnect an already-paired Bluetooth device from a small popup list, or by name.
#   just bluetooth                              popup list
#   just bluetooth -Top soundcore               popup list with devices matching "soundcore" first
#   just bluetooth -Name soundcore              connect the first device whose name contains "soundcore"
#   just bluetooth -Name soundcore -Disconnect  disconnect it
# In the popup, Enter connects, Ctrl+D disconnects, Esc closes. Pair new devices once in Settings > Bluetooth & devices.
#   just bluetooth -List                        write the paired device names to a cache file (used by the Win+K popup)
param([string]$Name, [switch]$Disconnect, [string[]]$Top, [switch]$List)

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Bt {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DeviceInfo {
        public int Size; public ulong Address; public uint ClassOfDevice;
        public int Connected, Remembered, Authenticated;
        public ushort s1, s2, s3, s4, s5, s6, s7, s8;       // stLastSeen
        public ushort u1, u2, u3, u4, u5, u6, u7, u8;       // stLastUsed
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 248)] public string Name;
    }
    [DllImport("bthprops.cpl", SetLastError = true)]
    static extern uint BluetoothSetServiceState(IntPtr radio, ref DeviceInfo dev, ref Guid service, uint flags);
    public static uint Set(ulong address, Guid service, bool enable) {
        var d = new DeviceInfo();
        d.Size = Marshal.SizeOf(typeof(DeviceInfo));
        d.Address = address;
        return BluetoothSetServiceState(IntPtr.Zero, ref d, ref service, enable ? 1u : 0u);
    }
}
'@

# Paired devices: instance ids look like BTHENUM\DEV_F4B1C2D3E4F5\...
$devices = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -match '^BTHENUM\\DEV_([0-9A-F]{12})' -and $_.FriendlyName } |
    ForEach-Object {
        $addr = [Convert]::ToUInt64(($_.InstanceId -replace '^BTHENUM\\DEV_([0-9A-F]{12}).*', '$1'), 16)
        [pscustomobject]@{ Name = $_.FriendlyName; Address = $addr }
    } | Sort-Object Address -Unique | Sort-Object Name
if (-not $devices) { Write-Host 'No paired Bluetooth devices found.'; Start-Sleep 3; exit 1 }

if ($List) {
    $cache = Join-Path $env:LOCALAPPDATA 'toolnest\bluetooth-devices.txt'
    New-Item -ItemType Directory -Force (Split-Path $cache) | Out-Null
    Set-Content $cache $devices.Name -Encoding utf8
    exit 0
}

$disconnect = $Disconnect
if ($Name) { $pick = $devices | Where-Object Name -like "*$Name*" | Select-Object -First 1 }
else {
    # Devices matching -Top go first, so Win+K then Enter hits the favourite. Windows' own "connected" flag is
    # unreliable, so the action is chosen with the key instead of being guessed.
    $rank = { param($d) $i = 0; foreach ($t in $Top) { if ($d.Name -like "*$t*") { return $i }; $i++ }; return 999 }
    $devices = @($devices | Sort-Object @{ Expression = { & $rank $_ } }, Name)

    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $bg = [Drawing.Color]::FromArgb(40, 42, 54); $fg = [Drawing.Color]::FromArgb(248, 248, 242)
    $form = [Windows.Forms.Form]@{ Text = 'Bluetooth'; StartPosition = 'CenterScreen'; FormBorderStyle = 'FixedToolWindow'
        ClientSize = [Drawing.Size]::new(340, 40 + 28 * $devices.Count + 24); TopMost = $true; BackColor = $bg; KeyPreview = $true }
    $list = [Windows.Forms.ListBox]@{ Dock = 'Fill'; BackColor = $bg; ForeColor = $fg; BorderStyle = 'None'
        Font = [Drawing.Font]::new('Segoe UI', 12); ItemHeight = 28; DrawMode = 'OwnerDrawFixed' }
    $list.Add_DrawItem({ param($s, $e)
        if ($e.Index -lt 0) { return }
        $sel = ($e.State -band [Windows.Forms.DrawItemState]::Selected) -ne 0
        $brush = [Drawing.SolidBrush]::new($(if ($sel) { [Drawing.Color]::FromArgb(68, 71, 90) } else { $bg }))
        $e.Graphics.FillRectangle($brush, $e.Bounds)
        [Windows.Forms.TextRenderer]::DrawText($e.Graphics, $s.Items[$e.Index], $s.Font, [Drawing.Point]::new($e.Bounds.X + 8, $e.Bounds.Y + 3), $fg)
    })
    $devices.Name | ForEach-Object { [void]$list.Items.Add($_) }
    $list.SelectedIndex = 0
    $hint = [Windows.Forms.Label]@{ Dock = 'Bottom'; Height = 24; Text = '  Enter connect   Ctrl+D disconnect   Esc close'
        ForeColor = [Drawing.Color]::FromArgb(98, 114, 164); BackColor = $bg; Font = [Drawing.Font]::new('Segoe UI', 9) }
    $form.Controls.AddRange(@($list, $hint))
    $script:chosen = $null
    $accept = { if ($list.SelectedItem) { $script:chosen = $list.SelectedItem; $form.Close() } }
    $list.Add_DoubleClick($accept)
    $form.Add_KeyDown({ param($s, $e)
        if ($e.KeyCode -eq 'Escape') { $form.Close() }
        elseif ($e.KeyCode -eq 'Return') { $e.SuppressKeyPress = $true; & $accept }
        elseif ($e.KeyCode -eq 'D' -and $e.Control) { $script:disconnect = $true; & $accept }
    })
    $form.Add_Shown({ $form.Activate(); $list.Focus() })
    [void]$form.ShowDialog()
    if (-not $script:chosen) { exit 0 }
    $disconnect = $script:disconnect
    $pick = $devices | Where-Object Name -eq $script:chosen | Select-Object -First 1
}
if (-not $pick) { Write-Host "No paired device matches '$Name'."; Start-Sleep 3; exit 1 }

# Audio sink, hands-free and HID services; toggling them off/on makes Windows drop or make the link.
$services = '0000110b-0000-1000-8000-00805f9b34fb', '0000111e-0000-1000-8000-00805f9b34fb', '00001124-0000-1000-8000-00805f9b34fb' | ForEach-Object { [guid]$_ }
if ($disconnect) {
    foreach ($s in $services) { [void][Bt]::Set($pick.Address, $s, $false) }
    Write-Host "Disconnected $($pick.Name)"
} else {
    foreach ($s in $services) { [void][Bt]::Set($pick.Address, $s, $false); [void][Bt]::Set($pick.Address, $s, $true) }
    Write-Host "Connecting $($pick.Name)..."
}
Start-Sleep 2
