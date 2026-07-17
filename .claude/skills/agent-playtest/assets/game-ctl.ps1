param(
  [Parameter(Mandatory=$true)][ValidateSet('info','move','shot','burst','click','dblclick','key','topmost','notopmost')][string]$Action,
  [int]$X = 0,
  [int]$Y = 0,
  [int]$W = 0,
  [int]$H = 0,
  [string]$Path = '',
  [string]$Key = '',
  [int]$Frames = 6,
  [int]$IntervalMs = 120
)

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class GameCtl {
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  public static void ForceForeground(IntPtr hWnd) {
    // Alt-tap trick: releases the Windows foreground lock so SetForegroundWindow succeeds
    keybd_event(0x12, 0, 0, UIntPtr.Zero);
    keybd_event(0x12, 0, 0x2, UIntPtr.Zero);
    SetForegroundWindow(hWnd);
  }
  public struct RECT { public int Left, Top, Right, Bottom; }
  public struct POINT { public int X, Y; }
}
"@

function Get-GameWindow {
  $proc = Get-Process | Where-Object { $_.ProcessName -like 'Godot*' -and $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if (-not $proc) { throw 'Godot game process with a main window not found. Launch the game first.' }
  return $proc
}

$proc = Get-GameWindow
$hwnd = $proc.MainWindowHandle

# Geometry is recomputed on EVERY invocation — the window drifts when the user is active.
$cr = New-Object GameCtl+RECT
[GameCtl]::GetClientRect($hwnd, [ref]$cr) | Out-Null
$origin = New-Object GameCtl+POINT
$origin.X = 0; $origin.Y = 0
[GameCtl]::ClientToScreen($hwnd, [ref]$origin) | Out-Null

function Save-ClientShot([string]$OutPath) {
  $cw = $cr.Right - $cr.Left; $ch = $cr.Bottom - $cr.Top
  $bmp = New-Object System.Drawing.Bitmap($cw, $ch)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($origin.X, $origin.Y, 0, 0, (New-Object System.Drawing.Size($cw, $ch)))
  $g.Dispose()
  $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

switch ($Action) {
  'info' {
    $wr = New-Object GameCtl+RECT
    [GameCtl]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
    [pscustomobject]@{
      title = $proc.MainWindowTitle; pid = $proc.Id
      window = @($wr.Left, $wr.Top, ($wr.Right - $wr.Left), ($wr.Bottom - $wr.Top))
      client_origin = @($origin.X, $origin.Y)
      client_size = @(($cr.Right - $cr.Left), ($cr.Bottom - $cr.Top))
    } | ConvertTo-Json -Compress
  }
  'move' {
    [GameCtl]::ForceForeground($hwnd)
    [GameCtl]::MoveWindow($hwnd, $X, $Y, $W, $H, $true) | Out-Null
    Start-Sleep -Milliseconds 300
    & $PSCommandPath -Action info
  }
  'shot' {
    [GameCtl]::ForceForeground($hwnd)
    Start-Sleep -Milliseconds 250
    Save-ClientShot $Path
    "saved $Path ($($cr.Right - $cr.Left) x $($cr.Bottom - $cr.Top), client origin $($origin.X),$($origin.Y))"
  }
  'burst' {
    # Capture $Frames frames at $IntervalMs intervals -> <Path base>-1.png .. -N.png.
    # Use around an action to detect animation: identical frames = no motion rendered.
    [GameCtl]::ForceForeground($hwnd)
    Start-Sleep -Milliseconds 200
    $base = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($Path), [System.IO.Path]::GetFileNameWithoutExtension($Path))
    for ($i = 1; $i -le $Frames; $i++) {
      Save-ClientShot "$base-$i.png"
      Start-Sleep -Milliseconds $IntervalMs
    }
    "saved $Frames frames to $base-1..$Frames.png (interval $IntervalMs ms)"
  }
  'click' {
    # X,Y are CLIENT coords inside the game viewport
    [GameCtl]::ForceForeground($hwnd)
    Start-Sleep -Milliseconds 150
    $sx = $origin.X + $X; $sy = $origin.Y + $Y
    [GameCtl]::SetCursorPos($sx, $sy) | Out-Null
    Start-Sleep -Milliseconds 80
    [GameCtl]::mouse_event(0x02, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [GameCtl]::mouse_event(0x04, 0, 0, 0, [UIntPtr]::Zero)
    "clicked client ($X,$Y) = screen ($sx,$sy)"
  }
  'dblclick' {
    [GameCtl]::ForceForeground($hwnd)
    Start-Sleep -Milliseconds 150
    $sx = $origin.X + $X; $sy = $origin.Y + $Y
    [GameCtl]::SetCursorPos($sx, $sy) | Out-Null
    Start-Sleep -Milliseconds 80
    1..2 | ForEach-Object {
      [GameCtl]::mouse_event(0x02, 0, 0, 0, [UIntPtr]::Zero)
      Start-Sleep -Milliseconds 40
      [GameCtl]::mouse_event(0x04, 0, 0, 0, [UIntPtr]::Zero)
      Start-Sleep -Milliseconds 60
    }
    "double-clicked client ($X,$Y) = screen ($sx,$sy)"
  }
  'key' {
    [GameCtl]::ForceForeground($hwnd)
    Start-Sleep -Milliseconds 150
    [System.Windows.Forms.SendKeys]::SendWait($Key)
    "sent keys: $Key"
  }
  'topmost' {
    # HWND_TOPMOST = -1; SWP_NOMOVE|SWP_NOSIZE|SWP_SHOWWINDOW
    [GameCtl]::SetWindowPos($hwnd, [IntPtr](-1), 0, 0, 0, 0, 0x43) | Out-Null
    "game window pinned topmost"
  }
  'notopmost' {
    [GameCtl]::SetWindowPos($hwnd, [IntPtr](-2), 0, 0, 0, 0, 0x43) | Out-Null
    "game window unpinned"
  }
}
