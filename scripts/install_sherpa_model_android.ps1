param(
  [string]$SourceDir = "D:\AI\sherpa-onnx\sherpa-th\active-int8",
  [string]$Serial = "",
  [string]$ModelVersion = "sherpa-onnx-zipformer-thai-2024-06-20-int8"
)

$ErrorActionPreference = "Stop"

$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  $adb = "adb"
}

$requiredFiles = @(
  "tokens.txt",
  "encoder.int8.onnx",
  "decoder.int8.onnx",
  "joiner.int8.onnx"
)

if (-not (Test-Path $SourceDir)) {
  throw "Sherpa ONNX model source directory was not found: $SourceDir"
}

foreach ($file in $requiredFiles) {
  $path = Join-Path $SourceDir $file
  if (-not (Test-Path $path)) {
    throw "Required model file is missing: $path"
  }
}

$deviceDir = "/storage/emulated/0/Android/data/com.thaimission.app/files/sherpa-onnx/sherpa-th/active-int8"
$adbArgs = @()
if ($Serial.Trim().Length -gt 0) {
  $adbArgs += @("-s", $Serial.Trim())
}

& $adb @adbArgs shell "mkdir -p '$deviceDir'"

foreach ($file in $requiredFiles) {
  $sourcePath = Join-Path $SourceDir $file
  & $adb @adbArgs push $sourcePath "$deviceDir/$file"
}

$versionFile = New-TemporaryFile
try {
  Set-Content -Path $versionFile -Value $ModelVersion.Trim() -NoNewline -Encoding UTF8
  & $adb @adbArgs push $versionFile "$deviceDir/model.version"
}
finally {
  Remove-Item -LiteralPath $versionFile -Force -ErrorAction SilentlyContinue
}

Write-Host "Sherpa ONNX model files were installed to $deviceDir"
Write-Host "Model version: $($ModelVersion.Trim())"
