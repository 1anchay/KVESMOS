param(
    [string]$UnsignedApk = 'build/releases/rustore/KVESMOS-1.0.0-RuStore-unsigned.apk',
    [string]$Keystore = (Join-Path $env:USERPROFILE 'KVESMOS-private/rustore-release.p12'),
    [string]$Alias = 'kvesmos-rustore',
    [string]$AndroidSdk = '.tools/android-sdk'
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$inputApk = (Resolve-Path -LiteralPath $UnsignedApk).Path
$keyPath = [IO.Path]::GetFullPath($Keystore)
if ($keyPath.StartsWith($repo.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Choose a keystore path outside the repository.'
}
$sdk = (Resolve-Path -LiteralPath $AndroidSdk).Path
$buildTools = Join-Path $sdk 'build-tools/36.0.0'
$signer = Join-Path $buildTools 'apksigner.bat'
$align = Join-Path $buildTools 'zipalign.exe'
$aapt = Join-Path $buildTools 'aapt2.exe'
if ($env:JAVA_HOME) {
    $keytool = Join-Path $env:JAVA_HOME 'bin/keytool.exe'
} else {
    $keytool = (Get-Command keytool.exe -ErrorAction Stop).Source
}

$meta = & $aapt dump badging $inputApk
if ($LASTEXITCODE -ne 0 -or
    !($meta -match "package: name='dev.orbitwords.orbitwords' versionCode='18' versionName='1.0.0'") -or
    !($meta -match "^targetSdkVersion:'36'$") -or
    ($meta -match '^application-debuggable')) {
    throw 'Unexpected APK package, version, API or debug flag.'
}
& $align -c -P 16 4 $inputApk
if ($LASTEXITCODE -ne 0) { throw 'The source APK failed ZIP alignment.' }
$folder = Split-Path -Parent $inputApk
$output = Join-Path $folder 'KVESMOS-1.0.0-RuStore-release.apk'
if (Test-Path -LiteralPath $output) { throw "Output already exists: $output" }

if (!(Test-Path -LiteralPath $keyPath)) {
    Write-Host "Permanent RuStore signing key will be stored at $keyPath"
    if ((Read-Host 'Type CREATE to generate the permanent key') -cne 'CREATE') { return }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $keyPath) | Out-Null
    & $keytool -genkeypair -storetype PKCS12 -keystore $keyPath -alias $Alias `
        -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=KVESMOS RuStore Release'
    if ($LASTEXITCODE -ne 0) { throw 'Key creation failed.' }
    Write-Host 'Make an encrypted backup of the keystore outside the repository. Store the password separately.'
}

$temporary = Join-Path $folder ('.signing-' + [Guid]::NewGuid().ToString('N') + '.apk')
try {
    & $signer sign --ks $keyPath --ks-key-alias $Alias --v4-signing-enabled false --out $temporary $inputApk
    if ($LASTEXITCODE -ne 0) { throw 'Signing failed.' }
    $certificate = & $signer verify --verbose --print-certs $temporary
    if ($LASTEXITCODE -ne 0 -or
        ($certificate -match 'CN=Android Debug|b8c558730dd20651119dd74b014b31ff51f076af208198dc79e05e51a0dca8be') -or
        !($certificate -match 'Signer #1 certificate SHA-256 digest:')) {
        throw 'APK verification failed or a test certificate was detected.'
    }
    & $align -c -P 16 4 $temporary
    if ($LASTEXITCODE -ne 0) { throw 'The signed APK failed ZIP alignment.' }
    Move-Item -LiteralPath $temporary -Destination $output
    $certificate | Set-Content -Encoding utf8 (Join-Path $folder 'release-certificate.txt')
    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $(Split-Path -Leaf $output)" | Set-Content -Encoding ascii (Join-Path $folder 'SHA256SUMS-release.txt')
    Write-Host "$output`nSHA-256 $hash"
} finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
}
