# WeChat Desktop Message Sender
# Usage:
#   Send text:   powershell -STA -NoProfile -ExecutionPolicy Bypass -File send_wechat.ps1 -Recipient "name" -Message "text"
#   Send image:  powershell -STA -NoProfile -ExecutionPolicy Bypass -File send_wechat.ps1 -Recipient "name" -ImagePath "C:\path\to\image.jpg"
#   Send file:   powershell -STA -NoProfile -ExecutionPolicy Bypass -File send_wechat.ps1 -Recipient "name" -FilePath "C:\path\to\file.txt"

param(
    [Parameter(Mandatory=$true)]
    [string]$Recipient,

    [Parameter(Mandatory=$false)]
    [string]$Message,

    [Parameter(Mandatory=$false)]
    [string]$ImagePath,

    [Parameter(Mandatory=$false)]
    [string]$FilePath
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

# P/Invoke for reliable window activation
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@

# Locate WeChat process (new version uses "Weixin", old version uses "WeChat")
# Detect by process existence (covers minimize-to-tray case where MainWindowHandle may be 0)
$wechat = Get-Process -Name "Weixin" -ErrorAction SilentlyContinue
if (-not $wechat) {
    $wechat = Get-Process -Name "WeChat" -ErrorAction SilentlyContinue
}
if (-not $wechat) {
    Write-Error "ERROR: WeChat process not found"
    exit 1
}

# Find a process instance with a valid window handle for activation.
# If none has one (e.g. minimized to tray with hidden window), try to bring it
# up via WeChat's global hotkey Ctrl+Alt+W (default), then re-check.
$target = $wechat | ForEach-Object { if ($_.MainWindowHandle -ne 0) { $_ } } | Select-Object -First 1
if (-not $target) {
    # Send WeChat global hotkey Ctrl+Alt+W to show the main window
    [System.Windows.Forms.SendKeys]::SendWait("^%w")
    Start-Sleep -Milliseconds 1500
    # Refresh and re-check for a visible window
    $wechat = Get-Process -Name "Weixin" -ErrorAction SilentlyContinue
    if (-not $wechat) { $wechat = Get-Process -Name "WeChat" -ErrorAction SilentlyContinue }
    $target = $wechat | ForEach-Object { if ($_.MainWindowHandle -ne 0) { $_ } } | Select-Object -First 1
    if (-not $target) {
        Write-Error "ERROR: WeChat is running but the window cannot be restored. Please open WeChat from the system tray and retry."
        exit 1
    }
}
# Bring WeChat window to foreground using P/Invoke (more reliable than AppActivate)
$hwnd = $target.MainWindowHandle
[Win32]::ShowWindow($hwnd, 9) | Out-Null  # SW_RESTORE
Start-Sleep -Milliseconds 300
[Win32]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 500

# Open search (Ctrl+F)
[System.Windows.Forms.SendKeys]::SendWait("^f")
Start-Sleep -Milliseconds 1200

# Paste recipient name
[System.Windows.Forms.Clipboard]::SetText($Recipient)
[System.Windows.Forms.SendKeys]::SendWait("^{v}")
Start-Sleep -Milliseconds 1500

# Press Enter to enter the chat
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Milliseconds 1200

# Clear input box (Ctrl+A select all, Delete to clear)
[System.Windows.Forms.SendKeys]::SendWait("^a")
Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait("{DELETE}")
Start-Sleep -Milliseconds 200

if ($ImagePath) {
    # Send image: load image into clipboard as Image object
    if (-not (Test-Path $ImagePath)) {
        Write-Error "ERROR: Image file not found: $ImagePath"
        exit 1
    }
    $img = [System.Drawing.Image]::FromFile($ImagePath)
    [System.Windows.Forms.Clipboard]::SetImage($img)
    Start-Sleep -Milliseconds 300
    [System.Windows.Forms.SendKeys]::SendWait("^{v}")
    Start-Sleep -Milliseconds 1500
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    Write-Output "Image sent to $Recipient successfully"
}
elseif ($FilePath) {
    # Send file: copy file to clipboard as file drop
    if (-not (Test-Path $FilePath)) {
        Write-Error "ERROR: File not found: $FilePath"
        exit 1
    }
    $fileList = New-Object System.Collections.Specialized.StringCollection
    $fileList.Add((Resolve-Path $FilePath).Path)
    [System.Windows.Forms.Clipboard]::SetFileDropList($fileList)
    Start-Sleep -Milliseconds 300
    [System.Windows.Forms.SendKeys]::SendWait("^{v}")
    Start-Sleep -Milliseconds 2000
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    Write-Output "File sent to $Recipient successfully"
}
else {
    # Send text message
    if (-not $Message) {
        Write-Error "ERROR: No message, image, or file specified"
        exit 1
    }
    [System.Windows.Forms.Clipboard]::SetText($Message)
    [System.Windows.Forms.SendKeys]::SendWait("^{v}")
    Start-Sleep -Milliseconds 500
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    Write-Output "Message sent to $Recipient successfully"
}
