param(
    [Parameter(Mandatory = $true)][int]$Sequence,
    [Parameter(Mandatory = $true)][int]$PreviousSequence,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$KeyPath = (Join-Path $env:LOCALAPPDATA 'SyncScroll\DetectorRegistry\signing-key.dpapi')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security.Cryptography.ProtectedData
if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) {
    throw 'The protected registry signing key is not available for this Windows account.'
}

$protectedBytes = [System.IO.File]::ReadAllBytes($KeyPath)
$privateBytes = $null
$privatePem = $null
$process = $null
try {
    $privateBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $protectedBytes,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    $privatePem = [System.Text.Encoding]::UTF8.GetString($privateBytes)

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'node'
    $psi.WorkingDirectory = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    @(
        (Join-Path $ProjectRoot 'tool/detector_registry/publish_registry.mjs'),
        '--catalog', (Join-Path $ProjectRoot 'tool/detector_registry/registry-catalog.json'),
        '--private-key-stdin',
        '--sequence', $Sequence.ToString([Globalization.CultureInfo]::InvariantCulture),
        '--previous-sequence', $PreviousSequence.ToString([Globalization.CultureInfo]::InvariantCulture),
        '--output', $OutputPath
    ) | ForEach-Object { [void]$psi.ArgumentList.Add($_) }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    if (-not $process.Start()) { throw 'Could not start the registry publisher.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.Write($privatePem)
    $process.StandardInput.Close()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw "Registry signing failed: $stderr" }
    if ($stdout) { Write-Output $stdout.TrimEnd() }
}
finally {
    if ($null -ne $privateBytes) { [Array]::Clear($privateBytes, 0, $privateBytes.Length) }
    if ($null -ne $protectedBytes) { [Array]::Clear($protectedBytes, 0, $protectedBytes.Length) }
    $privatePem = $null
    if ($null -ne $process) { $process.Dispose() }
}
