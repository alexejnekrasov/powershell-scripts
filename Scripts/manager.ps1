# =========================================================================
# Назначение: Локальный диспетчер автоматизации (Автономный запуск из C:\Windows\Setup\Scripts)
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'\r\n$ProgressPreference    = 'SilentlyContinue'

# Настройка папки логов в Документах текущего профиля (C:\Users\admin\\Documents)
$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
Start-Transcript -Path (Join-Path $LogDir "Main_Setup_Dispatcher.log") -Append

try {
    Write-Host "========================================================="
    Write-Host " СТАРТ ОСНОВНОГО ЭТАПА АВТОМАТИЗАЦИИ (РЕЖИМ PULL)"
    Write-Host "========================================================="

    # Абсолютный путь к папке скриптов
    $ScriptsDir = "C:\Windows\Setup\Scripts"
    Write-Host "Рабочая директория скриптов: $ScriptsDir"

    Write-Host "`n>>> Запуск последовательности автоматизации..."

    # Массив скриптов для последовательного выполнения
    $ScriptsToRun = @(
        @{ Name = "clean-and-photo.ps1";        Title = "Очистка системы и фото" },
        @{ Name = "install-sys-components.ps1"; Title = "Системные компоненты (VC++, .NET)" },
        @{ Name = "apps-install.ps1";           Title = "Установка базового софта" },
        @{ Name = "office-install.ps1";         Title = "Установка Office 2024 LTSC" }
    )

    # ШАГ 2: ПОСЛЕДОВАТЕЛЬНЫЙ ЗАПУСК МОДУЛЕЙ
    foreach ($Script in $ScriptsToRun) {
        $FileName = $Script.Name
        $FileTitle = $Script.Title
        $FullPath = Join-Path $ScriptsDir $FileName

        if (-not (Test-Path $FullPath)) {
            Write-Warning "[ ПРОПУЩЕНО ] -> Модуль '$FileName' не найден по пути: $FullPath"
            continue
        }

        Write-Host "Запуск модуля: $FileName ($FileTitle)..."
        
        # Запуск процесса в видимом окне (чтобы вы его видели) с ожиданием завершения
        $Proc = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$FullPath`"" -Wait -PassThru

        if ($Proc.ExitCode -eq 0) {
            Write-Host "[ УСПЕШНО ] -> $FileName успешно завершил работу.`n"
        } else {
            Write-Warning "[ СБОЙ ] -> $FileName завершился с ошибкой! Код возврата: $($Proc.ExitCode).`n"
        }
    }

    Write-Host "========================================================="
    Write-Host " ВСЕ ОСНОВНЫЕ МОДУЛИ ОТРАБОТАЛИ"
    Write-Host "========================================================="

    # Финальный запуск скрипта-самоликвидатора временных файлов
    $ResetPath = Join-Path $ScriptsDir "reset-setup-scripts.ps1"
    
    if (Test-Path $ResetPath) {
        Write-Host "Запуск модуля: reset-setup-scripts.ps1 (Самоликвидация временных файлов)..."
        
        $ProcReset = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ResetPath`"" -WindowStyle Hidden -Wait -PassThru

        if ($ProcReset.ExitCode -eq 0) {
            Write-Host "[ УСПЕШНО ] -> Скрипт самоликвидации успешно запустил очистку в фоне.`n"
        } else {
            Write-Warning "[ СБОЙ ] -> Не удалось инициировать очистку! Код возврата: $($ProcReset.ExitCode)`n"
        }
    } else {
        Write-Warning "[ ПРОПУЩЕНО ] -> Скрипт reset-setup-scripts.ps1 отсутствует в целевой папке."
    }

    Write-Host "========================================================="
    Write-Host " РАБОТА ДИСПЕТЧЕРА УСПЕШНО ЗАВЕРШЕНА"
    Write-Host "========================================================="

} catch {
    Write-Error "КРИТИЧЕСКАЯ ОШИБКА В ДИСПЕТЧЕРЕ: $_"
} finally {
    Stop-Transcript | Out-Null
}
