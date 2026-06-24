param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [ValidateSet("all", "claude", "codex")]
  [string]$Target = "all",
  [switch]$Check
)

$ErrorActionPreference = "Stop"

$rootPath = (Resolve-Path -LiteralPath $Root).Path
$sourceEngine = Join-Path $rootPath "soulagent\soulagent"

if (-not (Test-Path -LiteralPath $sourceEngine -PathType Container)) {
  throw "Source engine not found: $sourceEngine"
}

$forbiddenDirNames = @(
  "__pycache__",
  ".execution_cache",
  ".version_history",
  ".evolution_snapshot",
  ".nihil_backup",
  ".pipeline_cache",
  ".pytest_cache",
  ".mypy_cache",
  ".ruff_cache",
  ".release_tmp",
  "yijing_history",
  ".soulbot",
  "htmlcov",
  "node_modules",
  "dist",
  "build",
  ".tox",
  ".hypothesis",
  ".venv",
  "venv",
  "env",
  ".git"
)

$forbiddenFilePatterns = @(
  "conversation_context.json",
  "pipeline_run_metadata.json",
  ".audit_log.json",
  "credentials.json",
  ".netrc",
  "_*payload*.json",
  "_spans*.jsonl*",
  "*.pyc",
  "*.pyo",
  "*.tmp",
  "*.bak",
  "*_backup.*",
  "*.backup.*",
  "*.backup*",
  "*.log",
  "*.pid",
  "*.pem",
  "*.key",
  "*.pkcs12",
  "id_rsa*",
  "id_ed25519*",
  "service-account*.json",
  "*.db",
  "*.db-wal",
  "*.db-shm",
  "*.db-journal",
  "*.sqlite"
)

function Assert-WithinRoot([string]$PathValue) {
  $full = [System.IO.Path]::GetFullPath($PathValue)
  $rootFull = [System.IO.Path]::GetFullPath($rootPath).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  )
  $fullNormalized = $full.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  )
  $rootPrefix = $rootFull + [System.IO.Path]::DirectorySeparatorChar
  if (
    -not $fullNormalized.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -and
    -not $full.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
  ) {
    throw "Refusing to operate outside repository root: $full"
  }
  return $full
}

function Test-ForbiddenFileName([string]$Name) {
  foreach ($pattern in $forbiddenFilePatterns) {
    if ($Name -like $pattern) {
      return $true
    }
  }
  return $false
}

function Get-ForbiddenRuntimeArtifacts([string]$BasePath) {
  if (-not (Test-Path -LiteralPath $BasePath -PathType Container)) {
    return @()
  }
  $items = @()
  $items += Get-ChildItem -LiteralPath $BasePath -Recurse -Force -Directory |
    Where-Object { $forbiddenDirNames -contains $_.Name }
  $items += Get-ChildItem -LiteralPath $BasePath -Recurse -Force -File |
    Where-Object { Test-ForbiddenFileName $_.Name }
  return @($items | Sort-Object FullName)
}

function Remove-ForbiddenRuntimeArtifacts([string]$BasePath) {
  foreach ($item in @(Get-ForbiddenRuntimeArtifacts $BasePath | Sort-Object FullName -Descending)) {
    $full = Assert-WithinRoot $item.FullName
    Remove-Item -LiteralPath $full -Recurse -Force
  }
}

function Get-FileMap([string]$BasePath) {
  $base = Assert-WithinRoot $BasePath
  $map = @{}
  Get-ChildItem -LiteralPath $base -Recurse -Force -File |
    Where-Object {
      $rel = $_.FullName.Substring($base.Length + 1)
      $parts = $rel -split '[\\/]'
      -not (@($parts | Where-Object { $forbiddenDirNames -contains $_ }).Count) -and
      -not (Test-ForbiddenFileName $_.Name)
    } |
    ForEach-Object {
      $rel = $_.FullName.Substring($base.Length + 1).Replace('\', '/')
      $map[$rel] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
  return $map
}

function Compare-FileMaps([string]$SourcePath, [string]$TargetPath, [string]$Label) {
  $diffs = @()
  if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
    return @("$Label target-missing $TargetPath")
  }

  foreach ($path in @($SourcePath, $TargetPath)) {
    foreach ($item in Get-ForbiddenRuntimeArtifacts $path) {
      $diffs += "$Label forbidden-runtime-artifact $($item.FullName)"
    }
  }

  $srcMap = Get-FileMap $SourcePath
  $tgtMap = Get-FileMap $TargetPath
  foreach ($rel in @($srcMap.Keys + $tgtMap.Keys | Sort-Object -Unique)) {
    if (-not $srcMap.ContainsKey($rel)) {
      $diffs += "$Label target-only $rel"
    } elseif (-not $tgtMap.ContainsKey($rel)) {
      $diffs += "$Label target-missing $rel"
    } elseif ($srcMap[$rel] -ne $tgtMap[$rel]) {
      $diffs += "$Label hash-diff $rel"
    }
  }
  return $diffs
}

function Compare-DistributionMetadata([object[]]$Targets) {
  $diffs = @()
  foreach ($entry in $Targets) {
    foreach ($name in @("LICENSE", "NOTICE")) {
      $sourceFile = Join-Path $rootPath $name
      $targetFile = Join-Path $entry.Root $name
      if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
        $diffs += "$($entry.Name) source-missing $name"
        continue
      }
      if (-not (Test-Path -LiteralPath $targetFile -PathType Leaf)) {
        $diffs += "$($entry.Name) metadata-missing $name"
        continue
      }
      $sourceHash = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash
      $targetHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash
      if ($sourceHash -ne $targetHash) {
        $diffs += "$($entry.Name) metadata-hash-diff $name"
      }
    }
  }
  return $diffs
}

function Sync-DistributionMetadata([object[]]$Targets) {
  foreach ($entry in $Targets) {
    $targetRoot = Assert-WithinRoot $entry.Root
    if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
      throw "Distribution metadata target not found for $($entry.Name): $targetRoot"
    }
    foreach ($name in @("LICENSE", "NOTICE")) {
      $sourceFile = Join-Path $rootPath $name
      if (Test-Path -LiteralPath $sourceFile -PathType Leaf) {
        Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $targetRoot $name) -Force
      }
    }
  }
}

function Get-Targets {
  $allTargets = @(
    @{
      Name = "claude"
      PluginRoot = Join-Path $rootPath "claude_code_plugin"
      SkillRoot = Join-Path $rootPath "claude_code_plugin\skills\run"
    },
    @{
      Name = "codex"
      PluginRoot = Join-Path $rootPath "codex_plugin"
      SkillRoot = Join-Path $rootPath "codex_plugin\skills\run"
    }
  )

  if ($Target -eq "all") {
    return $allTargets
  }
  return @($allTargets | Where-Object { $_.Name -eq $Target })
}

$selectedTargets = @(Get-Targets)
$metadataTargets = @(
  @{
    Name = "host-neutral"
    Root = Join-Path $rootPath "soulagent"
  }
)
foreach ($entry in $selectedTargets) {
  $metadataTargets += @{
    Name = "$($entry.Name)-plugin"
    Root = $entry.PluginRoot
  }
  $metadataTargets += @{
    Name = "$($entry.Name)-skill"
    Root = $entry.SkillRoot
  }
}

if ($Check) {
  $diffs = @()
  foreach ($entry in $selectedTargets) {
    $targetEngine = Join-Path $entry.SkillRoot "soulagent"
    $diffs += Compare-FileMaps $sourceEngine $targetEngine $entry.Name
  }
  $diffs += Compare-DistributionMetadata $metadataTargets
  if ($diffs.Count) {
    Write-Error ("SoulAgent engine bundle drift detected:`n" + ($diffs -join "`n"))
    exit 1
  }
  Write-Host "SoulAgent engine bundles are in sync: $($selectedTargets.Name -join ', ')."
  exit 0
}

foreach ($entry in $selectedTargets) {
  $pluginRoot = Assert-WithinRoot $entry.PluginRoot
  $targetSkill = Assert-WithinRoot $entry.SkillRoot
  $targetEngine = Join-Path $targetSkill "soulagent"

  if (-not (Test-Path -LiteralPath $pluginRoot -PathType Container)) {
    throw "Plugin root not found for $($entry.Name): $pluginRoot"
  }

  New-Item -ItemType Directory -Force -Path $targetSkill | Out-Null

  if (Test-Path -LiteralPath $targetEngine) {
    $resolvedTarget = Assert-WithinRoot $targetEngine
    Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
  }

  Copy-Item -LiteralPath $sourceEngine -Destination $targetEngine -Recurse -Force
  Remove-ForbiddenRuntimeArtifacts $targetEngine

  Write-Host "Synced SoulAgent engine from $sourceEngine -> $targetEngine"
}

Sync-DistributionMetadata $metadataTargets
