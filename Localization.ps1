# Folder Size Trimmer localization (Windows PowerShell 5.1)
# Save this file as UTF-8 with BOM for Windows PowerShell 5.1.

$script:translations = @{
    de = @{
        subtitle             = 'Dateien von groß nach klein entfernen, bis die gewünschte Gesamtgröße unterschritten ist.'
        folderLabel          = 'Überordner (alle echten Unterordner werden durchsucht)'
        browse               = 'Durchsuchen ...'
        targetSizeLabel      = 'Zielgröße in GB'
        hint                 = 'Dezimale GB (1 GB = 1.000.000.000 Byte). Komma oder Punkt erlaubt.'
        analyze              = 'Analysieren'
        summaryGroup         = 'Übersicht'
        totalLabel           = 'Gesamtgröße'
        projectedLabel       = 'Größe nach Bereinigung'
        affectedLabel        = 'Betroffene Dateien'
        totalFilesLabel      = 'Dateien insgesamt'
        previewTitle         = 'Löschvorschau (größte Datei zuerst)'
        colSize              = 'Größe (GB)'
        colFile              = 'Datei'
        colPath              = 'Pfad'
        deleteButton         = 'Dateien löschen'
        cancelButton         = 'Abbrechen'
        aboutButton          = 'Über ...'
        languageLabel        = 'Sprache:'
        pickerDescription    = 'Ordner auswählen, dessen Dateien verkleinert werden sollen'
        ready                = 'Ordner auswählen, Zielgröße eingeben und analysieren.'
        analyzing            = 'Analysiere Ordner und Unterordner ...'
        verifying            = 'Prüfe die tatsächlich verbleibende Gesamtgröße ...'
        analyzeProgress      = 'Analyse läuft ... {0} Dateien erfasst.'
        verifyProgress       = 'Prüfung läuft ... {0} Dateien erfasst.'
        alreadyUnder         = 'Bereits unter dem Limit. Keine Löschung nötig. ({0} Verknüpfungen ignoriert)'
        previewReady         = 'Vorschau fertig: {0} Dateien werden gelöscht. {1} Verknüpfungen ignoriert.'
        analysisCancelled    = 'Analyse abgebrochen. Es wurde nichts gelöscht.'
        deleteProgress       = 'Gelöscht: {0}/{1} | Rechnerischer Rest: {2} GB'
        deleteRunning        = 'Bereinigung läuft ...'
        cancelRequested      = 'Abbruch angefordert ...'
        stoppedWithError     = 'Vorgang gestoppt. Es wurden keine weiteren Dateien gelöscht.'
        errorStatus          = 'Fehler: {0}'
        goalReached          = 'Ziel erreicht'
        goalNotReached       = 'Ziel nicht erreicht'
        deletedCount         = '{0} gelöscht'
        verificationSummary  = 'Gelöscht: {0} Datei(en). Verbleibend: {1} GB.'
        verificationMet      = 'Ziel unterschritten.'
        verificationNotMet   = 'Ziel noch nicht unterschritten.'
        verificationCanceled = 'Vorgang abgebrochen.'
        verificationError    = 'Fehler: {0}'
        verificationLog      = 'Protokoll: {0}'
        logUnavailable       = '(Protokoll konnte nicht gespeichert werden)'
        logFolder            = 'Ordner: {0}'
        logTargetBytes       = 'Ziel (Bytes): {0}'
        logDateTime          = 'Datum / Uhrzeit'
        logBytes             = 'Bytes'
        logFilePath          = 'Dateipfad'
        missingFolder        = 'Bitte einen Ordner auswählen.'
        folderNotFound       = 'Ordner nicht gefunden: {0}'
        wholeRootNotAllowed  = 'Ein ganzes Laufwerk oder der Stamm einer Netzwerkfreigabe ist nicht erlaubt.'
        linkedFolder         = 'Verknüpfte Ordner/Junctions sind nicht erlaubt: {0}'
        folderDisappeared    = 'Ordner existiert nicht: {0}'
        invalidTarget        = 'Ungültige Zielgröße. Beispiele: 4,5 oder 4.5 (GB, größer als 0).'
        fileOutside          = 'Datei liegt außerhalb des ausgewählten Ordners: {0}'
        parentMissing        = 'Übergeordneter Ordner fehlt: {0}'
        parentLinked         = 'Ordner wurde zur Verknüpfung: {0}'
        unsafeParent         = 'Unsicherer Ordnerpfad.'
        fileGone             = 'Datei existiert nicht mehr: {0}'
        fileLinked           = 'Datei wurde zu einer Verknüpfung.'
        fileChanged          = 'Datei wurde seit der Analyse verändert. Bitte erneut analysieren.'
        confirmTitle         = 'Dauerhafte Löschung bestätigen'
        confirmBody          = (@(
            'ACHTUNG: Die Dateien werden dauerhaft gelöscht (nicht in den Papierkorb)!'
            ''
            'Ordner: {0}'
            'Geplante Dateien: {1}'
            'Dateigröße zum Löschen: {2} GB'
            'Erwarteter Rest: {3} GB'
            ''
            'Die Löschung stoppt beim ersten Fehler. Nur die angezeigten Dateien dürfen gelöscht werden.'
            ''
            'Jetzt wirklich löschen?'
        ) -join [Environment]::NewLine)
        aboutTitle           = 'Über Folder Size Trimmer'
        aboutBody            = (@(
            'Folder Size Trimmer'
            'Version 0.2'
            ''
            'Coded by NetDaemon'
            'Original idea: NetDaemon'
            'https://ntdmn.xyz/'
            ''
            'Vorschau und gezielte Größenreduzierung per PowerShell.'
        ) -join [Environment]::NewLine)
        closingBody          = 'Ein Vorgang läuft. Wirklich beenden? Bereits gelöschte Dateien bleiben gelöscht.'
        closingTitle         = 'Vorgang läuft'
    }
    en = @{
        subtitle             = 'Remove the largest files first until the total folder size falls below your limit.'
        folderLabel          = 'Parent folder (all regular subfolders are included)'
        browse               = 'Browse ...'
        targetSizeLabel      = 'Target size in GB'
        hint                 = 'Decimal GB (1 GB = 1,000,000,000 bytes). Dot or comma accepted.'
        analyze              = 'Analyze'
        summaryGroup         = 'Overview'
        totalLabel           = 'Total size'
        projectedLabel       = 'Size after cleanup'
        affectedLabel        = 'Affected files'
        totalFilesLabel      = 'Total files'
        previewTitle         = 'Deletion preview (largest files first)'
        colSize              = 'Size (GB)'
        colFile              = 'File'
        colPath              = 'Path'
        deleteButton         = 'Delete files'
        cancelButton         = 'Cancel'
        aboutButton          = 'About ...'
        languageLabel        = 'Language:'
        pickerDescription    = 'Select the folder whose total file size should be reduced'
        ready                = 'Select a folder, enter a target size and click Analyze.'
        analyzing            = 'Scanning the folder and its subfolders ...'
        verifying            = 'Checking the actual remaining total size ...'
        analyzeProgress      = 'Scanning ... {0} files found.'
        verifyProgress       = 'Verifying ... {0} files found.'
        alreadyUnder         = 'Already below the target. Nothing to delete. ({0} links skipped)'
        previewReady         = 'Preview ready: {0} files to delete. {1} links skipped.'
        analysisCancelled    = 'Scan cancelled. No files were deleted.'
        deleteProgress       = 'Deleted: {0}/{1} | Estimated remaining: {2} GB'
        deleteRunning        = 'Deleting files ...'
        cancelRequested      = 'Cancellation requested ...'
        stoppedWithError     = 'Operation stopped. No additional files have been deleted.'
        errorStatus          = 'Error: {0}'
        goalReached          = 'Target reached'
        goalNotReached       = 'Target not reached'
        deletedCount         = '{0} deleted'
        verificationSummary  = 'Deleted: {0} file(s). Remaining: {1} GB.'
        verificationMet      = 'Target is now below the limit.'
        verificationNotMet   = 'Target is not yet below the limit.'
        verificationCanceled = 'Operation cancelled.'
        verificationError    = 'Error: {0}'
        verificationLog      = 'Log: {0}'
        logUnavailable       = '(Could not save the log)'
        logFolder            = 'Folder: {0}'
        logTargetBytes       = 'Target (bytes): {0}'
        logDateTime          = 'Date / time'
        logBytes             = 'Bytes'
        logFilePath          = 'File path'
        missingFolder        = 'Please select a folder.'
        folderNotFound       = 'Folder not found: {0}'
        wholeRootNotAllowed  = 'Selecting an entire drive or network share root is not allowed.'
        linkedFolder         = 'Linked folders and junctions are not allowed: {0}'
        folderDisappeared    = 'Folder no longer exists: {0}'
        invalidTarget        = 'Invalid target size. Examples: 4.5 or 4,5 (GB, greater than 0).'
        fileOutside          = 'File is outside the selected folder: {0}'
        parentMissing        = 'Parent folder is missing: {0}'
        parentLinked         = 'A parent folder has become a link: {0}'
        unsafeParent         = 'Unsafe folder path.'
        fileGone             = 'File no longer exists: {0}'
        fileLinked           = 'File has become a symbolic link.'
        fileChanged          = 'File changed since the scan. Please analyze again.'
        confirmTitle         = 'Confirm permanent deletion'
        confirmBody          = (@(
            'WARNING: Files will be deleted permanently (not moved to the Recycle Bin)!'
            ''
            'Folder: {0}'
            'Planned files: {1}'
            'Amount to delete: {2} GB'
            'Expected remaining size: {3} GB'
            ''
            'Deletion stops on the first error. Only the files shown in the preview may be deleted.'
            ''
            'Do you really want to delete these files?'
        ) -join [Environment]::NewLine)
        aboutTitle           = 'About Folder Size Trimmer'
        aboutBody            = (@(
            'Folder Size Trimmer'
            'Version 0.2'
            ''
            'Coded by NetDaemon'
            'Original idea: NetDaemon'
            'https://ntdmn.xyz/'
            ''
            'Preview and safely review a largest-first file size reduction plan.'
        ) -join [Environment]::NewLine)
        closingBody          = 'An operation is running. Quit anyway? Previously deleted files cannot be restored.'
        closingTitle         = 'Operation in progress'
    }
}

$script:language = 'de'
$script:settingsFile = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'FolderSizeTrimmer\settings.json'
$script:statusKey = 'ready'
$script:statusArgs = @()
$script:analysisComplete = $false
$script:lastResult = $null
$script:lastLogFile = ''

function T([string]$key) {
    $value = $script:translations[$script:language][$key]
    if ($null -eq $value) { throw "Missing translation: $($script:language)/$key" }
    return [string]$value
}

function Load-AppLanguage {
    try {
        if (Test-Path -LiteralPath $script:settingsFile -PathType Leaf) {
            $settings = Get-Content -LiteralPath $script:settingsFile -Encoding UTF8 -Raw | ConvertFrom-Json
            if ($settings.language -in @('de', 'en')) { $script:language = [string]$settings.language }
        }
    } catch {
        # A missing or invalid preference must not prevent the app from starting.
        $script:language = 'de'
    }
}

function Save-AppLanguage {
    try {
        $parent = Split-Path -Parent $script:settingsFile
        if (-not (Test-Path -LiteralPath $parent)) {
            [void](New-Item -ItemType Directory -Path $parent -Force)
        }
        @{ language = $script:language } | ConvertTo-Json -Compress |
            Set-Content -LiteralPath $script:settingsFile -Encoding UTF8 -ErrorAction Stop
    } catch {
        # Language selection stays active for this session even if it cannot be saved.
    }
}

Load-AppLanguage
