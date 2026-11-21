# Folder Size Trimmer 0.3
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
$script:deleteOrder = 'largest'
$script:planOrder = ''
$script:updatingOrderLabels = $false
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

# Separate, UTF-8-BOM translation resource (DE/EN).
. (Join-Path $PSScriptRoot 'Localization.ps1')

function Format-GB([decimal]$bytes) {
    $culture = if ($script:language -eq 'de') {
        [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
    } else {
        [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
    }
    return [string]::Format($culture, '{0:N4}', ($bytes / $script:unitBytes))
}

function Get-OrderName([string]$order) {
    if ($order -eq 'smallest') { return (T 'orderSmallest') }
    return (T 'orderLargest')
}

function Render-Status {
    if ($null -eq $lblStatus) { return }
    if ($script:statusKey -eq 'verificationDone') {
        $message = [string]::Format((T 'verificationSummary'), $script:deletedCount, (Format-GB $script:totalBytes))
        $message += ' ' + $(if ($script:lastResult.goal) { T 'verificationMet' } else { T 'verificationNotMet' })
        if ($script:cancelRequested) { $message += ' ' + (T 'verificationCanceled') }
        if ($script:deleteError) {
            $message += ' ' + [string]::Format((T 'verificationError'), $script:deleteError)
        }
        if ($script:lastLogFile) {
            $message += ' ' + [string]::Format((T 'verificationLog'), $script:lastLogFile)
        }
        $lblStatus.Text = $message
    } else {
        $lblStatus.Text = [string]::Format((T $script:statusKey), [object[]]$script:statusArgs)
    }
}

function Set-Status([string]$key, [object[]]$values = @()) {
    $script:statusKey = $key
    $script:statusArgs = @($values)
    Render-Status
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
    $script:planOrder = ''
    $script:analysisComplete = $false
    $script:lastResult = $null
    $grid.RowCount = 0
    $lblTotal.Text = '-'
    $lblResult.Text = '-'
    $lblCount.Text = '-'
    $lblFileCount.Text = '-'
    Set-Status 'ready'
    $btnDelete.Enabled = $false
}

function Update-Controls {
    $idle = ($script:phase -eq 'idle')
    $txtFolder.Enabled = $idle
    $txtLimit.Enabled = $idle
    $btnBrowse.Enabled = $idle
    $btnAnalyze.Enabled = $idle
    $cmbOrder.Enabled = $idle
    $btnDelete.Enabled = $idle -and ($script:plan.Count -gt 0) -and ($script:planOrder -eq $script:deleteOrder)
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
        if (-not $dir.Exists) { throw ([string]::Format((T 'folderDisappeared'), $dir.FullName)) }
        if (($dir.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw ([string]::Format((T 'linkedFolder'), $dir.FullName))
        }
        $dir = $dir.Parent
    }
}

function Get-SafeRoot([string]$userInput) {
    $text = $userInput.Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { throw (T 'missingFolder') }

    $full = [System.IO.Path]::GetFullPath($text)
    if (-not [System.IO.Directory]::Exists($full)) {
        throw ([string]::Format((T 'folderNotFound'), $full))
    }
    $normalized = $full.TrimEnd([char[]]@('\', '/'))
    $volumeRoot = ([System.IO.Path]::GetPathRoot($full)).TrimEnd([char[]]@('\', '/'))
    if ($normalized.Equals($volumeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw (T 'wholeRootNotAllowed')
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
        throw (T 'invalidTarget')
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
        Set-Status 'analyzing'
    } else {
        $script:phase = 'verify'
        Set-Status 'verifying'
    }
    $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
    Update-Controls
    $timer.Start()
}

function Complete-Analysis {
    # Sort files in the approved direction; the path is a deterministic tie-breaker.
    $descending = ($script:planOrder -eq 'largest')
    $sorted = @($script:files | Sort-Object -Property `
        @{ Expression = { $_.Bytes }; Descending = $descending }, `
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
    $script:analysisComplete = $true
    $script:lastResult = $null
    $grid.RowCount = $script:plan.Count
    $lblTotal.Text = "$(Format-GB $script:totalBytes) GB"
    $lblResult.Text = "$(Format-GB $remaining) GB"
    $lblCount.Text = [string]$script:plan.Count
    $lblFileCount.Text = [string]$script:scanCount

    Finish-Work
    if ($script:plan.Count -eq 0) {
        Set-Status 'alreadyUnder' @($script:ignoredLinks)
    } else {
        Set-Status 'previewReady' @($script:plan.Count, $script:ignoredLinks)
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
            $logFile = (T 'logUnavailable')
        }
    }

    Finish-Work
    $script:plan = @()  # old preview must not be executed twice
    $script:analysisComplete = $false
    $script:lastResult = @{ goal = $goalMet; bytes = $finalBytes; count = $finalCount; deleted = $nDeleted }
    $script:lastLogFile = $logFile
    $grid.RowCount = 0
    $lblTotal.Text = "$(Format-GB $finalBytes) GB"
    $lblResult.Text = $(if ($goalMet) { T 'goalReached' } else { T 'goalNotReached' })
    $lblCount.Text = [string]::Format((T 'deletedCount'), $nDeleted)
    $lblFileCount.Text = [string]$finalCount
    Update-Controls
    Set-Status 'verificationDone'
}

function Tick-Enumeration {
    # Work is intentionally split into batches so the GUI remains responsive.
    $processed = 0
    while ($processed -lt 250) {
        if ($script:scanMode -eq 'analyze' -and $script:cancelRequested) {
            $script:plan = @()
            $grid.RowCount = 0
            Finish-Work
            Set-Status 'analysisCancelled'
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
    if ($script:scanMode -eq 'verify') {
        Set-Status 'verifyProgress' @($script:scanCount)
    } else {
        Set-Status 'analyzeProgress' @($script:scanCount)
    }
}

function Assert-UnchangedFile($file) {
    $path = [System.IO.Path]::GetFullPath([string]$file.Path)
    $separator = [string][System.IO.Path]::DirectorySeparatorChar
    if (-not $path.StartsWith($script:rootPath + $separator,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw ([string]::Format((T 'fileOutside'), $path))
    }

    # All directory segments inside the target must still be real directories.
    $parent = [System.IO.Path]::GetDirectoryName($path)
    while ($true) {
        $di = New-Object System.IO.DirectoryInfo($parent)
        $di.Refresh()
        if (-not $di.Exists) { throw ([string]::Format((T 'parentMissing'), $parent)) }
        if (($di.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw ([string]::Format((T 'parentLinked'), $parent))
        }
        if ($parent.Equals($script:rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $newParent = [System.IO.Path]::GetDirectoryName($parent)
        if (-not $newParent -or $newParent -eq $parent) { throw (T 'unsafeParent') }
        $parent = $newParent
    }

    $current = New-Object System.IO.FileInfo($path)
    $current.Refresh()
    if (-not $current.Exists) { throw ([string]::Format((T 'fileGone'), $path)) }
    if (($current.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw (T 'fileLinked')
    }
    if ($current.Length -ne $file.Bytes -or $current.LastWriteTimeUtc.Ticks -ne $file.WriteTicks) {
        throw (T 'fileChanged')
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
        Set-Status 'deleteProgress' @($script:deletedCount, $script:plan.Count, (Format-GB $script:remainingBytes))
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
$form.ClientSize = New-Object System.Drawing.Size(960, 742)
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
$subtitle.Text = T 'subtitle'
$subtitle.AutoSize = $true
$subtitle.ForeColor = [System.Drawing.Color]::DimGray
$subtitle.Location = New-Object System.Drawing.Point(23, 52)
$form.Controls.Add($subtitle)

$btnAbout = New-Object System.Windows.Forms.Button
$btnAbout.Text = T 'aboutButton'
$btnAbout.SetBounds(838, 20, 100, 32)
$form.Controls.Add($btnAbout)

$lblLanguage = New-Object System.Windows.Forms.Label
$lblLanguage.Text = T 'languageLabel'
$lblLanguage.SetBounds(637, 27, 72, 22)
$form.Controls.Add($lblLanguage)

$cmbLanguage = New-Object System.Windows.Forms.ComboBox
$cmbLanguage.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbLanguage.SetBounds(710, 23, 113, 28)
[void]$cmbLanguage.Items.Add('Deutsch')
[void]$cmbLanguage.Items.Add('English')
$cmbLanguage.SelectedIndex = $(if ($script:language -eq 'en') { 1 } else { 0 })
$form.Controls.Add($cmbLanguage)

$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = T 'folderLabel'
$lblFolder.SetBounds(20, 91, 730, 22)
$form.Controls.Add($lblFolder)

$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.SetBounds(20, 115, 805, 27)
$form.Controls.Add($txtFolder)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = T 'browse'
$btnBrowse.SetBounds(835, 113, 105, 30)
$form.Controls.Add($btnBrowse)

$lblLimit = New-Object System.Windows.Forms.Label
$lblLimit.Text = T 'targetSizeLabel'
$lblLimit.SetBounds(20, 159, 145, 22)
$form.Controls.Add($lblLimit)

$txtLimit = New-Object System.Windows.Forms.TextBox
$txtLimit.Text = '5,0'
$txtLimit.SetBounds(20, 183, 133, 28)
$form.Controls.Add($txtLimit)

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text = T 'hint'
$lblHint.ForeColor = [System.Drawing.Color]::DimGray
$lblHint.SetBounds(167, 188, 612, 23)
$form.Controls.Add($lblHint)

$btnAnalyze = New-Object System.Windows.Forms.Button
$btnAnalyze.Text = T 'analyze'
$btnAnalyze.SetBounds(806, 177, 134, 36)
$form.Controls.Add($btnAnalyze)

$lblOrder = New-Object System.Windows.Forms.Label
$lblOrder.Text = T 'orderLabel'
$lblOrder.SetBounds(20, 232, 147, 22)
$form.Controls.Add($lblOrder)

$cmbOrder = New-Object System.Windows.Forms.ComboBox
$cmbOrder.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbOrder.SetBounds(175, 227, 315, 28)
[void]$cmbOrder.Items.Add((T 'orderLargest'))
[void]$cmbOrder.Items.Add((T 'orderSmallest'))
$cmbOrder.SelectedIndex = 0
$form.Controls.Add($cmbOrder)

$group = New-Object System.Windows.Forms.GroupBox
$group.Text = T 'summaryGroup'
$group.SetBounds(20, 270, 920, 94)
$form.Controls.Add($group)

$script:statCaptions = @{}
function Add-Stat([System.Windows.Forms.Control]$container, [string]$caption,
                  [int]$x, [int]$w) {
    $head = New-Object System.Windows.Forms.Label
    $head.Text = T $caption
    $script:statCaptions[$caption] = $head
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

$lblTotal = Add-Stat $group 'totalLabel' 18 210
$lblResult = Add-Stat $group 'projectedLabel' 250 224
$lblCount = Add-Stat $group 'affectedLabel' 498 185
$lblFileCount = Add-Stat $group 'totalFilesLabel' 707 190

$previewTitle = New-Object System.Windows.Forms.Label
$previewTitle.Text = T 'previewTitle'
$previewTitle.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$previewTitle.SetBounds(20, 381, 500, 24)
$form.Controls.Add($previewTitle)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.SetBounds(20, 410, 920, 220)
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
[void]$grid.Columns.Add('SizeGB', (T 'colSize'))
[void]$grid.Columns.Add('Name', (T 'colFile'))
[void]$grid.Columns.Add('FilePath', (T 'colPath'))
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
$progress.SetBounds(20, 649, 920, 13)
$progress.Minimum = 0
$progress.Maximum = 100
$form.Controls.Add($progress)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = T 'ready'
$lblStatus.AutoEllipsis = $true
$lblStatus.SetBounds(20, 671, 916, 21)
$form.Controls.Add($lblStatus)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = T 'deleteButton'
$btnDelete.SetBounds(642, 701, 151, 28)
$btnDelete.Enabled = $false
$form.Controls.Add($btnDelete)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = T 'cancelButton'
$btnCancel.SetBounds(803, 701, 137, 28)
$btnCancel.Enabled = $false
$form.Controls.Add($btnCancel)

function Apply-Language {
    $subtitle.Text = T 'subtitle'
    $lblOrder.Text = T 'orderLabel'
    # Rebuild translated options without invalidating an approved preview.
    $script:updatingOrderLabels = $true
    try {
        $cmbOrder.BeginUpdate()
        try {
            $index = $(if ($script:deleteOrder -eq 'smallest') { 1 } else { 0 })
            $cmbOrder.Items.Clear()
            [void]$cmbOrder.Items.Add((T 'orderLargest'))
            [void]$cmbOrder.Items.Add((T 'orderSmallest'))
            $cmbOrder.SelectedIndex = $index
        } finally {
            $cmbOrder.EndUpdate()
        }
    } finally {
        $script:updatingOrderLabels = $false
    }
    $lblLanguage.Text = T 'languageLabel'
    $btnAbout.Text = T 'aboutButton'
    $lblFolder.Text = T 'folderLabel'
    $btnBrowse.Text = T 'browse'
    $lblLimit.Text = T 'targetSizeLabel'
    $lblHint.Text = T 'hint'
    $btnAnalyze.Text = T 'analyze'
    $group.Text = T 'summaryGroup'
    foreach ($key in @('totalLabel','projectedLabel','affectedLabel','totalFilesLabel')) {
        $script:statCaptions[$key].Text = T $key
    }
    $previewTitle.Text = $(if ($script:deleteOrder -eq 'smallest') { T 'previewTitleSmallest' } else { T 'previewTitle' })
    $grid.Columns[0].HeaderText = T 'colSize'
    $grid.Columns[1].HeaderText = T 'colFile'
    $grid.Columns[2].HeaderText = T 'colPath'
    $btnDelete.Text = T 'deleteButton'
    $btnCancel.Text = T 'cancelButton'
    if ($script:analysisComplete) {
        $lblTotal.Text = "$(Format-GB $script:totalBytes) GB"
        $lblResult.Text = "$(Format-GB $script:remainingBytes) GB"
    } elseif ($null -ne $script:lastResult) {
        $lblTotal.Text = "$(Format-GB $script:lastResult.bytes) GB"
        $lblResult.Text = $(if ($script:lastResult.goal) { T 'goalReached' } else { T 'goalNotReached' })
        $lblCount.Text = [string]::Format((T 'deletedCount'), $script:lastResult.deleted)
    }
    $grid.Invalidate()
    Render-Status
}

$cmbLanguage.add_SelectedIndexChanged({
    $script:language = $(if ($cmbLanguage.SelectedIndex -eq 1) { 'en' } else { 'de' })
    Save-AppLanguage
    Apply-Language
})
Apply-Language

$cmbOrder.add_SelectedIndexChanged({
    if ($script:updatingOrderLabels -or $script:phase -ne 'idle') { return }
    $newOrder = $(if ($cmbOrder.SelectedIndex -eq 1) { 'smallest' } else { 'largest' })
    if ($newOrder -eq $script:deleteOrder) { return }
    $script:deleteOrder = $newOrder
    Clear-Preview
    $previewTitle.Text = $(if ($newOrder -eq 'smallest') { T 'previewTitleSmallest' } else { T 'previewTitle' })
    Set-Status 'orderChanged'
})

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
        Set-Status 'errorStatus' @($message)
        Show-Error ((T 'stoppedWithError') + [Environment]::NewLine + [Environment]::NewLine + $message)
    }
})

$txtFolder.add_TextChanged({ if ($script:phase -eq 'idle') { Clear-Preview } })
$txtLimit.add_TextChanged({ if ($script:phase -eq 'idle') { Clear-Preview } })

$btnBrowse.add_Click({
    $picker = New-Object System.Windows.Forms.FolderBrowserDialog
    $picker.Description = T 'pickerDescription'
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
        $script:planOrder = $script:deleteOrder
        $script:plan = @()
        $grid.RowCount = 0
        $script:cancelRequested = $false
        Start-Enumeration 'analyze'
    } catch {
        Show-Error $_.Exception.Message
    }
})

$btnDelete.add_Click({
    if ($script:phase -ne 'idle' -or $script:plan.Count -eq 0 -or
        $script:planOrder -ne $script:deleteOrder) { return }
    $toRemove = $script:totalBytes - $script:remainingBytes
    $confirmText = [string]::Format((T 'confirmBody'),
        $script:rootPath, $script:plan.Count,
        (Format-GB $toRemove), (Format-GB $script:remainingBytes),
        (Get-OrderName $script:planOrder))
    $answer = [System.Windows.Forms.MessageBox]::Show(
        $confirmText, (T 'confirmTitle'),
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
    $script:logLines.Add("Folder Size Trimmer 0.3 | $(Get-Date -Format s)")
    $script:logLines.Add([string]::Format((T 'logFolder'), $script:rootPath))
    $script:logLines.Add([string]::Format((T 'logTargetBytes'), $script:targetBytes))
    $script:logLines.Add([string]::Format((T 'logOrder'), (Get-OrderName $script:planOrder)))
    $script:logLines.Add((@((T 'logDateTime'), (T 'logBytes'), (T 'logFilePath'))) -join [char]9)
    $script:phase = 'delete'
    $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
    $progress.Value = 0
    Set-Status 'deleteRunning'
    Update-Controls
    $timer.Start()
})

$btnCancel.add_Click({
    if ($script:phase -eq 'scan' -or $script:phase -eq 'delete') {
        $script:cancelRequested = $true
        $btnCancel.Enabled = $false
        Set-Status 'cancelRequested'
    }
})

$btnAbout.add_Click({
    [void][System.Windows.Forms.MessageBox]::Show(
        (T 'aboutBody'),
        (T 'aboutTitle'),
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

$form.add_FormClosing({
    param($sender, $e)
    if ($script:phase -ne 'idle') {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            (T 'closingBody'),
            (T 'closingTitle'),
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