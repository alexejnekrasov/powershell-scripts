# =========================================================================
# Назначение: Локальный диспетчер-загрузчик (ТЕСТОВАЯ ВЕРСИЯ)
# Этап: Локальное тестирование развертывания без интернета
# Логирование: Документы текущего администратора (Изолированный Мастер-Лог)
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Настройка папки логов в Документах текущего профиля (C:\Users\admin\Documents)
$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
Start-Transcript -Path (Join-Path $LogDir "Main_Setup_Dispatcher.log") -Append

try {
    Write-Host "========================================================="
    Write-Host " СТАРТ ОСНОВНОГО ЭТАПА АВТОМАТИЗАЦИИ (ЛОКАЛЬНЫЙ ТЕСТ)"
    Write-Host "========================================================="

    # Источник локальных скриптов для теста
    $SourceDir = "C:\Users\AgentSharik\Downloads\Scripts"
    # Целевая папка системы
    $ScriptsDir = "C:\Windows\Setup\Scripts"
    
    if (-not (Test-Path $SourceDir)) {
        throw "Критическая ошибка: Тестовая папка-источник не найдена: $SourceDir"
    }

    if (-not (Test-Path $ScriptsDir)) { 
        New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null 
    }

    # Список файлов для копирования и работы
    $ScriptsList = @(
        "clean-and-photo.ps1",
        "install-sys-components.ps1",
        "apps-install.ps1",
        "office-install.ps1",
        "reset-setup-scripts.ps1"
    )

    # ----------------------------------------------------
    # ШАГ 1: ЛОКАЛЬНОЕ КОПИРОВАНИЕ СКРИПТОВ
    # ----------------------------------------------------
    Write-Host "`n>>> [1/2] Копирование компонентов из локальной папки..."
    foreach ($FileName in $ScriptsList) {
        $LocalSourcePath = Join-Path $SourceDir $FileName
        $TargetFilePath  = Join-Path $ScriptsDir $FileName

        if (Test-Path $LocalSourcePath) {
            Copy-Item -Path $LocalSourcePath -Destination $TargetFilePath -Force
            Write-Host "[ СКОПИРОВАНО ] -> $FileName"
        } else {
            Write-Warning "[ ПРЕДУПРЕЖДЕНИЕ ] -> Файл $FileName не найден в источнике. Пропускаем."
        }
    }

    # ----------------------------------------------------
    # ШАГ 2: ПОСЛЕДОВАТЕЛЬНЫЙ ИЗОЛИРОВАННЫЙ ЗАПУСК
    # ----------------------------------------------------
    Write-Host "`n>>> [2/2] Запуск последовательности автоматизации..."

    # Структура для запуска основных модулей
    $ScriptsToRun = @(
        @{ Name = "clean-and-photo.ps1";        Title = "Очистка системы и фото" }
        @{ Name = "install-sys-components.ps1"; Title = "Системные компоненты (VC++, .NET)" }
        @{ Name = "apps-install.ps1";           Title = "Установка базового софта" }
        @{ Name = "office-install.ps1";         Title = "Установка Office 2024 LTSC" }
    )

    foreach ($Script in $ScriptsToRun) {
        $FileName = $Script.Name
        $LocalPath = Join-Path $ScriptsDir $FileName
        
        # Если файл не скопировался или отсутствует — просто идем дальше
        if (-not (Test-Path $LocalPath)) { continue }
        
        Write-Host "Запуск модуля: $FileName ($($Script.Title))...."
        
        # Запускаем дочерний скрипт изолированно
        $Proc = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$LocalPath`"" -WindowStyle Hidden -Wait -PassThru
        
        # Проверяем код завершения процесса
        if ($Proc.ExitCode -eq 0) {
            Write-Host "[ УСПЕШНО ] -> $FileName успешно завершил работу.`n"
        } else {
            Write-Warning "[ СБОЙ ] -> $FileName завершился с ошибкой! Код возврата: $($Proc.ExitCode).`n"
        }
    }

    Write-Host "========================================================="
    Write-Host " ВСЕ ОСНОВНЫЕ МОДУЛИ ОТРАБОТАЛИ"
    Write-Host "========================================================="

    # Финальный запуск скрипта-камикадзе
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
    Write-Host " ТЕСТОВАЯ АВТОМАТИЗАЦИЯ ЗАВЕРШЕНА."
    Write-Host "========================================================="

} catch {
    Write-Warning "`n[ КРИТИЧЕСКИЙ СБОЙ ДИСПЕТЧЕРА ]: $($_.Exception.Message)"
} finally {
    Stop-Transcript
}