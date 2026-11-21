# Folder Size Trimmer 0.1
# Windows PowerShell 5.1 / Windows Forms
# Coded by NetDaemon
# Scans a directory recursively, previews files largest-first and, on explicit
# confirmation, deletes only the previewed files until total bytes < target.

#Requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:unitBytes = [decimal]1000000000  # decimal GB, not GiB
$script:rootPath = ''
$script:targetBytes = [decimal]0
$script:totalBytes = [decimal]0
$script:remainingBytes = [decimal]0
$script:files = New-Object 'System.Collections.Generic.List[object]'
$script:plan = @()
$script:phase = 'idle'
$script:cancelRequested = $false
$script:scanMode = ''
$script:scanDirs = $null
$script:scanIterator = $null
$script:scanCount = 0
$script:ignoredLinks = 0
$script:deleteIndex = 0
$script:deletedCount = 0
$script:deleteError = ''
$script:logLines = New-Object 'System.Collections.Generic.List[string]'

function Format-GB([decimal]$bytes) {
    return ('{0:N4}' -f ($bytes / $script:unitBytes))
}

function Show-Error([string]$message) {
    [void][System.Windows.Forms.MessageBox]::Show(
        $message,
        'Folder Size Trimmer',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
}

function Clear-Preview {
    $script:plan = @()
    $grid.RowCount = 0
    $lblTotal.Text = '-'
    $lblResult.Text = '-'
    $lblCount.Text = '-'
    $lblFileCount.Text = '-'
    $lblStatus.Text = 'Ordner auswählen, Zielgröße eingeben und analysieren.'
    $btnDelete.Enabled = $false
}

function Update-Controls {
    $idle = ($script:phase -eq 'idle')
    $txtFolder.Enabled = $idle
    $txtLimit.Enabled = $idle
    $btnBrowse.Enabled = $idle
    $btnAnalyze.Enabled = $idle
    $btnDelete.Enabled = $idle -and ($script:plan.Count -gt 0)
    $btnCancel.Enabled = ($script:phase -eq 'scan' -or $script:phase -eq 'delete')
}

function Close-Iterator {
    if ($null -ne $script:scanIterator) {
        try { $script:scanIterator.Dispose() } catch { }
        $script:scanIterator = $null
    }
}

function Finish-Work {
    $timer.Stop()
    Close-Iterator
    $script:scanDirs = $null
    $script:phase = 'idle'
    $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
    $progress.Value = 0
    Update-Controls
}

function Test-NoJunctionParents([string]$folder) {
    # Reject not just a linked root itself, but any linked ancestor.
    $dir = New-Object System.IO.DirectoryInfo($folder)
    while ($null -ne $dir) {
        $dir.Refresh()
        if (-not $dir.Exists) { throw "Ordner existiert nicht: $($dir.FullName)" }
        if (($dir.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Verknüpfte Ordner/Junctions sind nicht erlaubt: $($dir.FullName)"
        }
        $dir = $dir.Parent
    }
}

function Get-SafeRoot([string]$userInput) {
    $text = $userInput.Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { throw 'Bitte einen Ordner auswählen.' }

    $full = [System.IO.Path]::GetFullPath($text)
    if (-not [System.IO.Directory]::Exists($full)) {
        throw "Ordner nicht gefunden: $full"
    }
    $normalized = $full.TrimEnd([char[]]@('\', '/'))
    $volumeRoot = ([System.IO.Path]::GetPathRoot($full)).TrimEnd([char[]]@('\', '/'))
    if ($normalized.Equals($volumeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Ein ganzes Laufwerk oder der Stamm einer Netzwerkfreigabe ist nicht erlaubt.'
    }

    Test-NoJunctionParents $full
    return $normalized
}

function Get-TargetBytes([string]$inputText) {
    $value = [decimal]0
    $s = $inputText.Trim().Replace(',', '.')
    $style = [System.Globalization.NumberStyles]::AllowDecimalPoint
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if (-not [decimal]::TryParse($s, $style, $culture, [ref]$value) -or $value -le 0) {
        throw 'Ungültige Zielgröße. Beispiele: 4,5 oder 4.5 (GB, größer als 0).'
    }
    return ($value * $script:unitBytes)
}

function Start-Enumeration([string]$mode) {
    Close-Iterator
    $script:scanDirs = New-Object 'System.Collections.Generic.Stack[string]'
    $script:scanDirs.Push($script:rootPath)
    $script:scanMode = $mode
    $script:scanCount = 0
    $script:ignoredLinks = 0
    $script:totalBytes = [decimal]0
    if ($mode -eq 'analyze') {
        $script:files = New-Object 'System.Collections.Generic.List[object]'
        $script:phase = 'scan'
        $lblStatus.Text = 'Analysiere Ordner und Unterordner ...'
    } else {
        $script:phase = 'verify'
        $lblStatus.Text = 'Prüfe die tatsächlich verbleibende Gesamtgröße ...'
    }
    $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
    Update-Controls
    $timer.Start()
}

function Complete-Analysis {
    # Sort by byte size, descending; the path is only a deterministic tie-breaker.
    $sorted = @($script:files | Sort-Object -Property `
        @{ Expression = { $_.Bytes }; Descending = $true }, `
        @{ Expression = { $_.Path }; Descending = $false })

    $remaining = $script:totalBytes
    $preview = New-Object 'System.Collections.Generic.List[object]'
    foreach ($file in $sorted) {
        if ($remaining -lt $script:targetBytes) { break }
        $preview.Add($file)
        $remaining -= [decimal]$file.Bytes
    }

    $script:plan = @($preview.ToArray())
    $script:remainingBytes = $remaining
    $grid.RowCount = $script:plan.Count
    $lblTotal.Text = "$(Format-GB $script:totalBytes) GB"
    $lblResult.Text = "$(Format-GB $remaining) GB"
    $lblCount.Text = [string]$script:plan.Count
    $lblFileCount.Text = [string]$script:scanCount

    Finish-Work
    if ($script:plan.Count -eq 0) {
        $lblStatus.Text = "Bereits unter dem Limit. Keine Löschung nötig. ($($script:ignoredLinks) Verknüpfungen ignoriert)"
    } else {
        $lblStatus.Text = "Vorschau fertig: $($script:plan.Count) Dateien werden gelöscht. $($script:ignoredLinks) Verknüpfungen ignoriert."
    }
}

function Complete-Verification {
    $finalBytes = $script:totalBytes
    $finalCount = $script:scanCount
    $errors = $script:deleteError
    $nDeleted = $script:deletedCount
    $goalMet = ($finalBytes -lt $script:targetBytes)
    $wasCancelled = $script:cancelRequested
    $logFile = ''

    if ($script:logLines.Count -gt 0) {
        try {
            $logFile = Join-Path ([System.IO.Path]::GetTempPath()) (
                'FolderSizeTrimmer_{0:yyyyMMdd_HHmmss_fff}.log' -f (Get-Date)
            )
            $script:logLines.ToArray() | Set-Content -LiteralPath $logFile -Encoding UTF8 -ErrorAction Stop
        } catch {
            $logFile = '(Protokoll konnte nicht gespeichert werden)'
        }
    }

    Finish-Work
    $script:plan = @()  # old preview must not be executed twice
    $grid.RowCount = 0
    $lblTotal.Text = "$(Format-GB $finalBytes) GB"
    $lblResult.Text = $(if ($goalMet) { 'Ziel erreicht' } else { 'Ziel nicht erreicht' })
    $lblCount.Text = "${nDeleted} gelöscht"
    $lblFileCount.Text = [string]$finalCount
    Update-Controls

    $message = "Gelöscht: $nDeleted Datei(en). Verbleibend: $(Format-GB $finalBytes) GB."
    if ($goalMet) { $message += ' Ziel unterschritten.' }
    else { $message += ' Ziel noch nicht unterschritten.' }
    if ($wasCancelled) { $message += ' Vorgang abgebrochen.' }
    if ($errors) { $message += " Fehler: $errors" }
    if ($logFile) { $message += " Protokoll: $logFile" }
    $lblStatus.Text = $message
}

function Tick-Enumeration {
    # Work is intentionally split into batches so the GUI remains responsive.
    $processed = 0
    while ($processed -lt 250) {
        if ($script:scanMode -eq 'analyze' -and $script:cancelRequested) {
            $script:plan = @()
            $grid.RowCount = 0
            Finish-Work
            $lblStatus.Text = 'Analyse abgebrochen. Es wurde nichts gelöscht.'
            return
        }

        if ($null -eq $script:scanIterator) {
            if ($script:scanDirs.Count -eq 0) {
                if ($script:scanMode -eq 'analyze') { Complete-Analysis }
                else { Complete-Verification }
                return
            }
            $dirPath = $script:scanDirs.Pop()
            $dirInfo = New-Object System.IO.DirectoryInfo($dirPath)
            $script:scanIterator = $dirInfo.EnumerateFileSystemInfos().GetEnumerator()
        }

        if (-not $script:scanIterator.MoveNext()) {
            Close-Iterator
            continue
        }
        $entry = $script:scanIterator.Current
        $processed++

        # Includes directory junctions and symbolic links. Do not traverse them.
        if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            $script:ignoredLinks++
            continue
        }
        if ($entry -is [System.IO.DirectoryInfo]) {
            $script:scanDirs.Push($entry.FullName)
        } elseif ($entry -is [System.IO.FileInfo]) {
            $length = [long]$entry.Length
            $script:totalBytes += [decimal]$length
            $script:scanCount++
            if ($script:scanMode -eq 'analyze') {
                $script:files.Add([pscustomobject]@{
                    Name = $entry.Name
                    Path = $entry.FullName
                    Bytes = $length
                    WriteTicks = $entry.LastWriteTimeUtc.Ticks
                })
            }
        }
    }
    $lblStatus.Text = "$(if ($script:scanMode -eq 'verify') { 'Prüfung' } else { 'Analyse' }) läuft ... $($script:scanCount) Dateien erfasst."
}

function Assert-UnchangedFile($file) {
    $path = [System.IO.Path]::GetFullPath([string]$file.Path)
    $separator = [string][System.IO.Path]::DirectorySeparatorChar
    if (-not $path.StartsWith($script:rootPath + $separator,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Datei liegt außerhalb des ausgewählten Ordners: $path"
    }

    # All directory segments inside the target must still be real directories.
    $parent = [System.IO.Path]::GetDirectoryName($path)
    while ($true) {
        $di = New-Object System.IO.DirectoryInfo($parent)
        $di.Refresh()
        if (-not $di.Exists) { throw "Übergeordneter Ordner fehlt: $parent" }
        if (($di.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Ordner wurde zur Verknüpfung: $parent"
        }
        if ($parent.Equals($script:rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $newParent = [System.IO.Path]::GetDirectoryName($parent)
        if (-not $newParent -or $newParent -eq $parent) { throw 'Unsicherer Ordnerpfad.' }
        $parent = $newParent
    }

    $current = New-Object System.IO.FileInfo($path)
    $current.Refresh()
    if (-not $current.Exists) { throw "Datei existiert nicht mehr: $path" }
    if (($current.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Datei wurde zu einer Verknüpfung.'
    }
    if ($current.Length -ne $file.Bytes -or $current.LastWriteTimeUtc.Ticks -ne $file.WriteTicks) {
        throw 'Datei wurde seit der Analyse verändert. Bitte erneut analysieren.'
    }
}

function Tick-Deletion {
    if ($script:cancelRequested) {
        Start-Enumeration 'verify'
        return
    }
    if ($script:deleteIndex -ge $script:plan.Count -or
        $script:remainingBytes -lt $script:targetBytes) {
        Start-Enumeration 'verify'
        return
    }

    # One deletion per timer tick allows Cancel between files.
    $file = $script:plan[$script:deleteIndex]
    try {
        Assert-UnchangedFile $file
        Remove-Item -LiteralPath $file.Path -Force -ErrorAction Stop
        $script:remainingBytes -= [decimal]$file.Bytes
        $script:deletedCount++
        $script:deleteIndex++
        $script:logLines.Add(("{0:yyyy-MM-dd HH:mm:ss}`t{1}`t{2}" -f
            (Get-Date), $file.Bytes, $file.Path))
        $progress.Value = [Math]::Min(100, [int](100 * $script:deleteIndex / $script:plan.Count))
        $lblStatus.Text = "Gelöscht: $($script:deletedCount)/$($script:plan.Count) | Rechnerischer Rest: $(Format-GB $script:remainingBytes) GB"
    } catch {
        # Never delete files beyond those explicitly approved in the preview.
        # Stop at the first error instead of silently advancing to smaller files.
        $script:deleteError = $_.Exception.Message
        Start-Enumeration 'verify'
    }
}

# -------------------- GUI --------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Folder Size Trimmer'
$form.ClientSize = New-Object System.Drawing.Size(960, 675)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 251)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Folder Size Trimmer'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20, 14)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'Dateien von groß nach klein entfernen, bis die gewünschte Gesamtgröße unterschritten ist.'
$subtitle.AutoSize = $true
$subtitle.ForeColor = [System.Drawing.Color]::DimGray
$subtitle.Location = New-Object System.Drawing.Point(23, 52)
$form.Controls.Add($subtitle)

$btnAbout = New-Object System.Windows.Forms.Button
$btnAbout.Text = 'About'
$btnAbout.SetBounds(838, 20, 100, 32)
$form.Controls.Add($btnAbout)

$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = 'Überordner (alle echten Unterordner werden durchsucht)'
$lblFolder.SetBounds(20, 91, 730, 22)
$form.Controls.Add($lblFolder)

$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.SetBounds(20, 115, 805, 27)
$form.Controls.Add($txtFolder)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = 'Durchsuchen ...'
$btnBrowse.SetBounds(835, 113, 105, 30)
$form.Controls.Add($btnBrowse)

$lblLimit = New-Object System.Windows.Forms.Label
$lblLimit.Text = 'Zielgröße in GB'
$lblLimit.SetBounds(20, 159, 145, 22)
$form.Controls.Add($lblLimit)

$txtLimit = New-Object System.Windows.Forms.TextBox
$txtLimit.Text = '5,0'
$txtLimit.SetBounds(20, 183, 133, 28)
$form.Controls.Add($txtLimit)

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text = 'Dezimale GB (1 GB = 1.000.000.000 Byte). Komma oder Punkt erlaubt.'
$lblHint.ForeColor = [System.Drawing.Color]::DimGray
$lblHint.SetBounds(167, 188, 612, 23)
$form.Controls.Add($lblHint)

$btnAnalyze = New-Object System.Windows.Forms.Button
$btnAnalyze.Text = 'Analysieren'
$btnAnalyze.SetBounds(806, 177, 134, 36)
$form.Controls.Add($btnAnalyze)

$group = New-Object System.Windows.Forms.GroupBox
$group.Text = 'Übersicht'
$group.SetBounds(20, 227, 920, 94)
$form.Controls.Add($group)

function Add-Stat([System.Windows.Forms.Control]$container, [string]$caption,
                  [int]$x, [int]$w) {
    $head = New-Object System.Windows.Forms.Label
    $head.Text = $caption
    $head.ForeColor = [System.Drawing.Color]::DimGray
    $head.SetBounds($x, 21, $w, 20)
    $container.Controls.Add($head)
    $value = New-Object System.Windows.Forms.Label
    $value.Text = '-'
    $value.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $value.SetBounds($x, 44, $w, 32)
    $container.Controls.Add($value)
    return $value
}

$lblTotal = Add-Stat $group 'Gesamtgröße' 18 210
$lblResult = Add-Stat $group 'Größe nach Bereinigung' 250 224
$lblCount = Add-Stat $group 'Betroffene Dateien' 498 185
$lblFileCount = Add-Stat $group 'Dateien insgesamt' 707 190

$previewTitle = New-Object System.Windows.Forms.Label
$previewTitle.Text = 'Löschvorschau (größte Datei zuerst)'
$previewTitle.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$previewTitle.SetBounds(20, 336, 500, 24)
$form.Controls.Add($previewTitle)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.SetBounds(20, 365, 920, 220)
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.ReadOnly = $true
$grid.RowHeadersVisible = $false
$grid.MultiSelect = $false
$grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$grid.VirtualMode = $true
$grid.BackgroundColor = [System.Drawing.Color]::White
$grid.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
[void]$grid.Columns.Add('SizeGB', 'Größe (GB)')
[void]$grid.Columns.Add('Name', 'Datei')
[void]$grid.Columns.Add('FilePath', 'Pfad')
$grid.Columns[0].FillWeight = 18
$grid.Columns[1].FillWeight = 30
$grid.Columns[2].FillWeight = 70
$grid.Columns[0].MinimumWidth = 110
$grid.Columns[1].MinimumWidth = 155
$grid.Columns[2].MinimumWidth = 370
$form.Controls.Add($grid)

$grid.add_CellValueNeeded({
    param($sender, $e)
    if ($e.RowIndex -ge 0 -and $e.RowIndex -lt $script:plan.Count) {
        $f = $script:plan[$e.RowIndex]
        switch ($e.ColumnIndex) {
            0 { $e.Value = Format-GB ([decimal]$f.Bytes) }
            1 { $e.Value = $f.Name }
            2 { $e.Value = $f.Path }
        }
    }
})

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.SetBounds(20, 602, 920, 13)
$progress.Minimum = 0
$progress.Maximum = 100
$form.Controls.Add($progress)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = 'Ordner auswählen, Zielgröße eingeben und analysieren.'
$lblStatus.AutoEllipsis = $true
$lblStatus.SetBounds(20, 622, 916, 21)
$form.Controls.Add($lblStatus)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = 'Dateien löschen'
$btnDelete.SetBounds(642, 645, 151, 28)
$btnDelete.Enabled = $false
$form.Controls.Add($btnDelete)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = 'Abbrechen'
$btnCancel.SetBounds(803, 645, 137, 28)
$btnCancel.Enabled = $false
$form.Controls.Add($btnCancel)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 15
$timer.add_Tick({
    try {
        switch ($script:phase) {
            'scan'   { Tick-Enumeration }
            'verify' { Tick-Enumeration }
            'delete' { Tick-Deletion }
        }
    } catch {
        $message = $_.Exception.Message
        Finish-Work
        Clear-Preview
        $lblStatus.Text = "Fehler: $message"
        Show-Error "Vorgang gestoppt. Es wurden keine weiteren Dateien gelöscht.`r`n`r`n$message"
    }
})

$txtFolder.add_TextChanged({ if ($script:phase -eq 'idle') { Clear-Preview } })
$txtLimit.add_TextChanged({ if ($script:phase -eq 'idle') { Clear-Preview } })

$btnBrowse.add_Click({
    $picker = New-Object System.Windows.Forms.FolderBrowserDialog
    $picker.Description = 'Ordner auswählen, dessen Dateien verkleinert werden sollen'
    $picker.ShowNewFolderButton = $false
    if ([System.IO.Directory]::Exists($txtFolder.Text)) {
        $picker.SelectedPath = $txtFolder.Text
    }
    try {
        if ($picker.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtFolder.Text = $picker.SelectedPath
        }
    } finally {
        $picker.Dispose()
    }
})

$btnAnalyze.add_Click({
    try {
        $root = Get-SafeRoot $txtFolder.Text
        $limit = Get-TargetBytes $txtLimit.Text
        $script:rootPath = $root
        $script:targetBytes = $limit
        $script:plan = @()
        $grid.RowCount = 0
        $script:cancelRequested = $false
        Start-Enumeration 'analyze'
    } catch {
        Show-Error $_.Exception.Message
    }
})

$btnDelete.add_Click({
    if ($script:phase -ne 'idle' -or $script:plan.Count -eq 0) { return }
    $toRemove = $script:totalBytes - $script:remainingBytes
    $confirmText = @"
ACHTUNG: Die Dateien werden dauerhaft gelöscht (nicht in den Papierkorb)!

Ordner: $($script:rootPath)
Geplante Dateien: $($script:plan.Count)
Dateigröße zum Löschen: $(Format-GB $toRemove) GB
Erwarteter Rest: $(Format-GB $script:remainingBytes) GB

Die Löschung stoppt beim ersten Fehler. Nur die angezeigten Dateien dürfen gelöscht werden.

Jetzt wirklich löschen?
"@
    $answer = [System.Windows.Forms.MessageBox]::Show(
        $confirmText, 'Dauerhafte Löschung bestätigen',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning,
        [System.Windows.Forms.MessageBoxDefaultButton]::Button2
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $script:cancelRequested = $false
    $script:deleteIndex = 0
    $script:deletedCount = 0
    $script:deleteError = ''
    $script:remainingBytes = $script:totalBytes
    $script:logLines = New-Object 'System.Collections.Generic.List[string]'
    $script:logLines.Add("Folder Size Trimmer 0.1 | $(Get-Date -Format s)")
    $script:logLines.Add("Ordner: $($script:rootPath)")
    $script:logLines.Add("Ziel (Bytes): $($script:targetBytes)")
    $script:logLines.Add('Datum / Uhrzeit`tBytes`tDateipfad')
    $script:phase = 'delete'
    $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
    $progress.Value = 0
    $lblStatus.Text = 'Bereinigung läuft ...'
    Update-Controls
    $timer.Start()
})

$btnCancel.add_Click({
    if ($script:phase -eq 'scan' -or $script:phase -eq 'delete') {
        $script:cancelRequested = $true
        $btnCancel.Enabled = $false
        $lblStatus.Text = 'Abbruch angefordert ...'
    }
})

$btnAbout.add_Click({
    [void][System.Windows.Forms.MessageBox]::Show(
        "Folder Size Trimmer`r`nVersion 0.1`r`n`r`nCoded by NetDaemon`r`nOriginal idea: NetDaemon`r`nhttps://ntdmn.xyz/`r`n`r`nVorschau und gezielte Größenreduzierung per PowerShell.",
        'About Folder Size Trimmer',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

$form.add_FormClosing({
    param($sender, $e)
    if ($script:phase -ne 'idle') {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            'Ein Vorgang läuft. Wirklich beenden? Bereits gelöschte Dateien bleiben gelöscht.',
            'Vorgang läuft',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        )
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
            $e.Cancel = $true
            return
        }
        $timer.Stop()
        Close-Iterator
    }
})

[void]$form.ShowDialog()
$timer.Dispose()
$form.Dispose()