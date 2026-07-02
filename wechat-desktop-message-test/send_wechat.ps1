# WeChat Desktop Message Sender (human-like typing)
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
    [string]$FilePath,

    [Parameter(Mandatory=$false)]
    [int]$ChatIconOffsetX = 28,

    [Parameter(Mandatory=$false)]
    [int]$ChatIconOffsetY = 108
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint cButtons, uint dwExtraInfo);
    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);
    [DllImport("user32.dll")]
    public static extern bool ScreenToClient(IntPtr hWnd, ref POINT lpPoint);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    public struct POINT { public int X, Y; }
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
    public const uint MOUSEEVENTF_MOVE = 0x0001;
}
'@

# Helper: sleep with random jitter (±40% around base ms)
function Sleep-Jitter {
    param([int]$BaseMs)
    $jitter = $BaseMs * 0.4
    $actual = [math]::Max(50, $BaseMs + (Get-Random -Minimum (-$jitter) -Maximum $jitter))
    Start-Sleep -Milliseconds $actual
}

# Helper: type text character by character with human-like delays
function Type-Human {
    param([string]$Text)
    # Split into words to add longer pauses between words
    $words = $Text -split '(\s+)'
    $wordCount = 0
    foreach ($word in $words) {
        if ($word.Length -eq 0) { continue }
        $wordCount++
        # Type each character in the word
        for ($i = 0; $i -lt $word.Length; $i++) {
            $ch = $word[$i]
            # Convert char to SendKeys-safe format
            $keyStr = if ($ch -eq '+' -or $ch -eq '^' -or $ch -eq '%' -or $ch -eq '~' -or $ch -eq '(' -or $ch -eq ')' -or $ch -eq '[' -or $ch -eq ']' -or $ch -eq '{' -or $ch -eq '}') {
                "{$ch}"
            } else {
                $ch
            }
            [System.Windows.Forms.SendKeys]::SendWait($keyStr)
            # Random delay between keystrokes (40-180ms, longer for special chars)
            $charDelay = if ($ch -eq ' ' -or $ch -eq ',' -or $ch -eq '.' -or $ch -eq '!' -or $ch -eq '?') {
                Get-Random -Minimum 100 -Maximum 250
            } else {
                Get-Random -Minimum 40 -Maximum 180
            }
            Start-Sleep -Milliseconds $charDelay
        }
        # Longer pause between words (200-600ms), but not after last word
        if ($wordCount -lt $words.Length) {
            $pause = Get-Random -Minimum 200 -Maximum 600
            Start-Sleep -Milliseconds $pause
        }
    }
}

# Helper: move mouse to a random nearby position (subtle nudge)
function Move-MouseSubtle {
    $pt = New-Object Win32+POINT
    [Win32]::GetCursorPos([ref]$pt) | Out-Null
    $newX = $pt.X + (Get-Random -Minimum -8 -Maximum 8)
    $newY = $pt.Y + (Get-Random -Minimum -5 -Maximum 5)
    [Win32]::SetCursorPos($newX, $newY) | Out-Null
    Start-Sleep -Milliseconds (Get-Random -Minimum 30 -Maximum 80)
}

$wechat = Get-Process -Name "Weixin" -ErrorAction SilentlyContinue
if (-not $wechat) {
    $wechat = Get-Process -Name "WeChat" -ErrorAction SilentlyContinue
}
if (-not $wechat) {
    Write-Error "ERROR: WeChat process not found"
    exit 1
}

$target = $wechat | ForEach-Object { if ($_.MainWindowHandle -ne 0) { $_ } } | Select-Object -First 1
if (-not $target) {
    [System.Windows.Forms.SendKeys]::SendWait("^%w")
    Sleep-Jitter 1500
    $wechat = Get-Process -Name "Weixin" -ErrorAction SilentlyContinue
    if (-not $wechat) { $wechat = Get-Process -Name "WeChat" -ErrorAction SilentlyContinue }
    $target = $wechat | ForEach-Object { if ($_.MainWindowHandle -ne 0) { $_ } } | Select-Object -First 1
    if (-not $target) {
        Write-Error "ERROR: WeChat is running but the window cannot be restored."
        exit 1
    }
}
$hwnd = $target.MainWindowHandle
[Win32]::ShowWindow($hwnd, 9) | Out-Null
Sleep-Jitter 300
[Win32]::SetForegroundWindow($hwnd) | Out-Null
Sleep-Jitter 500

$rect = New-Object Win32+RECT
[Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$clickX = $rect.Left + $ChatIconOffsetX
$clickY = $rect.Top + $ChatIconOffsetY
[Win32]::SetCursorPos($clickX, $clickY) | Out-Null
Sleep-Jitter 150
[Win32]::mouse_event([Win32]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0) | Out-Null
[Win32]::mouse_event([Win32]::MOUSEEVENTF_LEFTUP, 0, 0, 0, 0) | Out-Null
Sleep-Jitter 800

[System.Windows.Forms.SendKeys]::SendWait("^f")
Sleep-Jitter 1200

[System.Windows.Forms.Clipboard]::SetText($Recipient)
[System.Windows.Forms.SendKeys]::SendWait("^{v}")
Sleep-Jitter 1500

[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Sleep-Jitter 1200

[System.Windows.Forms.SendKeys]::SendWait("^a")
Sleep-Jitter 200
[System.Windows.Forms.SendKeys]::SendWait("{DELETE}")
Sleep-Jitter 200

if ($ImagePath) {
    if (-not (Test-Path $ImagePath)) {
        Write-Error "ERROR: Image file not found: $ImagePath"
        exit 1
    }
    Move-MouseSubtle
    $img = [System.Drawing.Image]::FromFile($ImagePath)
    [System.Windows.Forms.Clipboard]::SetImage($img)
    Sleep-Jitter 300
    [System.Windows.Forms.SendKeys]::SendWait("^{v}")
    Sleep-Jitter 1500
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    Write-Output "Image sent to $Recipient successfully"
}
elseif ($FilePath) {
    if (-not (Test-Path $FilePath)) {
        Write-Error "ERROR: File not found: $FilePath"
        exit 1
    }
    Move-MouseSubtle
    $fileList = New-Object System.Collections.Specialized.StringCollection
    $fileList.Add((Resolve-Path $FilePath).Path)
    [System.Windows.Forms.Clipboard]::SetFileDropList($fileList)
    Sleep-Jitter 300
    [System.Windows.Forms.SendKeys]::SendWait("^{v}")
    Sleep-Jitter 2000
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    Write-Output "File sent to $Recipient successfully"
}
else {
    if (-not $Message) {
        Write-Error "ERROR: No message, image, or file specified"
        exit 1
    }
    Move-MouseSubtle
    Type-Human $Message
    Sleep-Jitter 800
    [System.Windows.Forms.SendKeys]::SendWait("~")
    Write-Output "Message sent to $Recipient successfully"
}
