param(
  [string[]]$TestArgs = @(),
  [int]$TimeoutSeconds = 180,
  [int]$PollSeconds = 5
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$logDir = Join-Path $repoRoot "tmp_test_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$stdoutPath = Join-Path $logDir "flutter_test_$stamp.out.log"
$stderrPath = Join-Path $logDir "flutter_test_$stamp.err.log"

$arguments = @("test", "--no-pub") + $TestArgs
Write-Host "Starting: flutter $($arguments -join ' ')"
Write-Host "Timeout: ${TimeoutSeconds}s"
Write-Host "stdout: $stdoutPath"
Write-Host "stderr: $stderrPath"

$process = Start-Process `
  -FilePath "flutter" `
  -ArgumentList $arguments `
  -WorkingDirectory $repoRoot `
  -RedirectStandardOutput $stdoutPath `
  -RedirectStandardError $stderrPath `
  -NoNewWindow `
  -PassThru

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$lastOutLength = 0
$lastErrLength = 0

while (-not $process.HasExited) {
  Start-Sleep -Seconds $PollSeconds
  $now = Get-Date

  if (Test-Path $stdoutPath) {
    $outLength = (Get-Item $stdoutPath).Length
    if ($outLength -ne $lastOutLength) {
      Write-Host ""
      Write-Host "--- stdout tail ---"
      Get-Content -Tail 20 $stdoutPath
      $lastOutLength = $outLength
    }
  }

  if (Test-Path $stderrPath) {
    $errLength = (Get-Item $stderrPath).Length
    if ($errLength -ne $lastErrLength) {
      Write-Host ""
      Write-Host "--- stderr tail ---"
      Get-Content -Tail 20 $stderrPath
      $lastErrLength = $errLength
    }
  }

  if ($now -ge $deadline) {
    Write-Host ""
    Write-Host "Timeout reached. Terminating process tree for PID $($process.Id)."
    taskkill.exe /PID $process.Id /T /F | Out-Host
    exit 124
  }
}

$process.WaitForExit()
Write-Host ""
Write-Host "Flutter test exited with code $($process.ExitCode)."

if (Test-Path $stdoutPath) {
  Write-Host ""
  Write-Host "--- final stdout tail ---"
  Get-Content -Tail 40 $stdoutPath
}

if (Test-Path $stderrPath) {
  Write-Host ""
  Write-Host "--- final stderr tail ---"
  Get-Content -Tail 40 $stderrPath
}

exit $process.ExitCode
