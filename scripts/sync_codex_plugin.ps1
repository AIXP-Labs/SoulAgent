param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$Check
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "sync_plugin_engines.ps1"
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
  throw "Required sync script not found: $scriptPath"
}

$params = @{
  Root = $Root
  Target = "codex"
}
if ($Check) {
  $params.Check = $true
}

& $scriptPath @params
