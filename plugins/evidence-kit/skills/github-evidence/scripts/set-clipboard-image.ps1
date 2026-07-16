param([Parameter(Mandatory=$true)][string]$Path)
# Put a PNG on the Windows clipboard as an image so it can be pasted (Ctrl+V)
# into a GitHub comment box. MUST run with -Sta: powershell.exe -Sta -File this.ps1 -Path C:\...png
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$img = $null
try {
  $img = [System.Drawing.Image]::FromFile($Path)   # throws if missing/locked/not-an-image
  [System.Windows.Forms.Clipboard]::SetImage($img)  # copies the data, so disposing after is safe
  Write-Output ("clipboard-image-set " + $img.Width + "x" + $img.Height)
}
catch { Write-Error ("set-clipboard-image failed: " + $_.Exception.Message); exit 1 }
finally { if ($img) { $img.Dispose() } }   # release the FromFile lock on $Path
