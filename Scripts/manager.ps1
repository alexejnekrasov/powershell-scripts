# =========================================================================
# Назначение: Локальный диспетчер-загрузчик (СТАБИЛЬНАЯ ВЕРСИЯ ДЛЯ ФЛЕШКИ)
# Этап: Автоматическое развертывание с загрузочного USB-носителя
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
    Write-Host " СТАРТ ОСНОВНОГО ЭТАПА АВТОМАТИЗАЦИИ (ЗАПУСК С USB)"
    Write-Host "========================================================="

    # ----------------------------------------------------
    # ДИНАМИЧЕСКИЙ ПОИСК ЗАГРУЗОЧНОЙ ФЛЕШКИ
    # ----------------------------------------------------
    Write-Host "Поиск загрузочного USB-носителя в системе..."
    
    # 1. Ищем диск, где в корне одновременно есть файл ответов и папка со скриптами
    $UsbDrive = Get-PSDrive -PSProvider FileSystem | Where-Object { 
        (Test-Path "$($_.Root)autounattend.xml") -and (Test-Path "$($_.Root)Scripts")
    } | Select-Object -First 1

    # 2. Резервный поиск: если xml уже нет, ищем любой диск с папкой Scripts в корне
    if (-not $UsbDrive) {
        $UsbDrive = Get-PSDrive -PSProvider FileSystem | Where-Object { 
            Test-Path "$($_.Root)Scripts"
        } | Select-Object -First 1
    }

    # 3. Проверяем успешность поиска и задаем путь к источнику
    if ($UsbDrive) {
        $SourceDir = Join-Path $UsbDrive.Root "Scripts"
        Write-Host "[ ОК ] Найдена целевая флешка: $($UsbDrive.Root)"
        Write-Host "[ ОК ] Папка-источник скриптов: $SourceDir"
    } else {
        throw "Критическая ошибка: Загрузочная флешка или корневая папка 'Scripts' не обнаружены!"
    }

    # Целевая папка системы
    $ScriptsDir = "C:\Windows\Setup\Scripts"
    
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
    Write-Host "`n>>> [1/2] Копирование компонентов с флешки..."
    foreach ($FileName in $ScriptsList) {
        $LocalSourcePath = Join-Path $SourceDir $FileName
        $TargetFilePath  = Join-Path $ScriptsDir $FileName

        if (Test-Path $LocalSourcePath) {
            Copy-Item -Path $LocalSourcePath -Destination $TargetFilePath -Force
            Write-Host "[ СКОПИРОВАНО ] -> $FileName"
        } else {
            Write-Warning "[ ПРЕДУПРЕЖДЕНИЕ ] -> Файл $FileName не найден на флешке. Пропускаем."
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
        @{ Name = "office-install.ps1";          Title = "Установка Office 2024 LTSC" }
    )

    foreach ($Script in $ScriptsToRun) {
        $FileName = $Script.Name
        $LocalPath = Join-Path $ScriptsDir $FileName
        
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
    Write-Host " АВТОМАТИЗАЦИЯ С USB ЗАВЕРШЕНА."
    Write-Host "========================================================="

} catch {
    Write-Warning "`n[ КРИТИЧЕСКИЙ СБОЙ ДИСПЕТЧЕРА ]: $($_.Exception.Message)"
} finally {
    Stop-Transcript
}