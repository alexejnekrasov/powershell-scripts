# =========================================================================
# Модернизированный GUI Диспетчер (с принудительным завершением)
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# --- ФУНКЦИЯ ПРИНУДИТЕЛЬНОГО ЗАВЕРШЕНИЯ ---
function Exit-Script {
    # Убиваем процесс, чтобы гарантированно завершить работу
    Stop-Process -Id $PID -Force
    # Или через системный метод: [Environment]::Exit(0)
}

# --- СКРЫТИЕ КОНСОЛИ ---
$Win32Code = @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
'@
$WindowManager = Add-Type -MemberDefinition $Win32Code -Name "Win32ShowWindow" -Namespace "Win32" -PassThru
$ConsoleHandle = $WindowManager::GetConsoleWindow()
if ($ConsoleHandle -ne [System.IntPtr]::Zero) { $null = $WindowManager::ShowWindow($ConsoleHandle, 0) }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
Start-Transcript -Path (Join-Path $LogDir "Main_Setup_GUI_Dispatcher.log") -Append

# --- GUI ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = " Автоматическая настройка системы"
$Form.Size = New-Object System.Drawing.Size(960, 480)
$Form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
$Form.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$Form.MaximizeBox = $false

# --- Ключевое изменение: привязка закрытия формы к функции завершения ---
$Form.Add_FormClosing({ Exit-Script })

# (Остальной код формы остается без изменений)
# ... [КОД ПАНЕЛЕЙ, ШРИФТОВ И Т.Д. ОСТАВИТЬ КАК БЫЛО] ...

# --- КНОПКА ГОТОВО ---
$DoneButton = New-Object System.Windows.Forms.Button
$DoneButton.Text = "ГОТОВО"
$DoneButton.Location = New-Object System.Drawing.Point(740, 380)
$DoneButton.Size = New-Object System.Drawing.Size(180, 40)
$DoneButton.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$DoneButton.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
$DoneButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$DoneButton.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
$DoneButton.Visible = $false
# Вызываем функцию завершения
$DoneButton.Add_Click({ Exit-Script }) 
$Form.Controls.Add($DoneButton)

# ... [КОД ЛОГИКИ И ЗАПУСКА] ...

[System.Windows.Forms.Application]::Run($Form)
Stop-Transcript
