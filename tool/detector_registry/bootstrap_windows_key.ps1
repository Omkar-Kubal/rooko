param(
    [string]$KeyPath = (Join-Path $env:LOCALAPPDATA 'SyncScroll\DetectorRegistry\signing-key.dpapi')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security.Cryptography.ProtectedData

$directory = Split-Path -Parent $KeyPath
New-Item -ItemType Directory -Path $directory -Force | Out-Null
if (Test-Path -LiteralPath $KeyPath) {
    throw 'A registry signing key already exists at the selected location; refusing to replace it.'
}

$temporaryPath = Join-Path $directory ('.signing-key-' + [Guid]::NewGuid().ToString('N') + '.tmp')
$ecdsa = [System.Security.Cryptography.ECDsa]::Create()
$privateBytes = $null
$protectedBytes = $null
$checkBytes = $null
$privatePem = $null
$checkPem = $null
$checkKey = $null

try {
    $ecdsa.GenerateKey([System.Security.Cryptography.ECCurve]::CreateFromFriendlyName('nistP256'))
    $privatePem = $ecdsa.ExportPkcs8PrivateKeyPem()
    $publicDer = $ecdsa.ExportSubjectPublicKeyInfo()
    $privateBytes = [System.Text.Encoding]::UTF8.GetBytes($privatePem)
    $protectedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
        $privateBytes,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    [System.IO.File]::WriteAllBytes($temporaryPath, $protectedBytes)

    $checkBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
        [System.IO.File]::ReadAllBytes($temporaryPath),
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    $checkPem = [System.Text.Encoding]::UTF8.GetString($checkBytes)
    $checkKey = [System.Security.Cryptography.ECDsa]::Create()
    $checkKey.ImportFromPem($checkPem)
    $challenge = [System.Text.Encoding]::UTF8.GetBytes('Rooko registry key self-check')
    $signature = $checkKey.SignData($challenge, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    if (-not $checkKey.VerifyData($challenge, $signature, [System.Security.Cryptography.HashAlgorithmName]::SHA256)) {
        throw 'The protected key could not be read back and verified.'
    }
    if ([Convert]::ToBase64String($publicDer) -ne
        [Convert]::ToBase64String($checkKey.ExportSubjectPublicKeyInfo())) {
        throw 'The protected key does not match its public key.'
    }

    [System.IO.File]::Move($temporaryPath, $KeyPath)
    $fingerprint = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($publicDer))
    [pscustomobject]@{
        public_key_base64 = [Convert]::ToBase64String($publicDer)
        public_key_sha256 = $fingerprint
        key_storage = 'Windows DPAPI CurrentUser'
        encrypted_key_written = $true
    } | ConvertTo-Json -Compress
}
catch {
    if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force }
    throw
}
finally {
    if ($null -ne $privateBytes) { [Array]::Clear($privateBytes, 0, $privateBytes.Length) }
    if ($null -ne $protectedBytes) { [Array]::Clear($protectedBytes, 0, $protectedBytes.Length) }
    if ($null -ne $checkBytes) { [Array]::Clear($checkBytes, 0, $checkBytes.Length) }
    $privatePem = $null
    $checkPem = $null
    if ($null -ne $checkKey) { $checkKey.Dispose() }
    if ($null -ne $ecdsa) { $ecdsa.Dispose() }
}
