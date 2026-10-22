$FlutterArgs = $args
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$localFlutter = Join-Path $projectRoot '.tools\flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $localFlutter)) { throw 'Install Flutter in .tools/flutter or use your system flutter command.' }
# Dart does not automatically inherit the Windows system proxy. Read only its
# address through Python; do not store credentials in project configuration.
if (Get-Command python -ErrorAction SilentlyContinue) {
  $systemProxy = python -c "import urllib.request; print(urllib.request.getproxies().get('https',''))"
  if ($systemProxy) { $env:https_proxy=$systemProxy; $env:http_proxy=$systemProxy }
}
$env:no_proxy='localhost,127.0.0.1,::1'
& $localFlutter @FlutterArgs
exit $LASTEXITCODE
