param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$SkipClaude,
  [switch]$SkipCodex,
  [switch]$RequireHostCli
)

$ErrorActionPreference = "Stop"

if ($RequireHostCli -and ($SkipClaude -or $SkipCodex)) {
  throw "-RequireHostCli cannot be combined with -SkipClaude or -SkipCodex."
}

$rootPath = (Resolve-Path -LiteralPath $Root).Path
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
  $mutexHashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($rootPath.ToLowerInvariant()))
}
finally {
  $sha256.Dispose()
}
$mutexHash = [System.BitConverter]::ToString($mutexHashBytes).Replace("-", "").Substring(0, 16)
$releaseCheckMutex = [System.Threading.Mutex]::new($false, "Local\SoulAgentReleaseCheck-$mutexHash")
$releaseCheckMutexAcquired = $false
try {
  $releaseCheckMutexAcquired = $releaseCheckMutex.WaitOne([TimeSpan]::FromMinutes(15))
}
catch [System.Threading.AbandonedMutexException] {
  $releaseCheckMutexAcquired = $true
}
if (-not $releaseCheckMutexAcquired) {
  throw "Timed out waiting for another SoulAgent release check to finish."
}

$claudePluginPath = Join-Path $rootPath "claude_code_plugin"
$claudeSkillPath = Join-Path $claudePluginPath "skills\run"
$codexPluginPath = Join-Path $rootPath "codex_plugin"
$codexSkillPath = Join-Path $codexPluginPath "skills\run"
$sourceEnginePath = Join-Path $rootPath "soulagent\soulagent"
$skillValidator = Join-Path $env:USERPROFILE ".codex\skills\.system\skill-creator\scripts\quick_validate.py"
$releaseTmpParent = Join-Path $rootPath ".release_tmp"
$releaseTmpRoot = Join-Path $releaseTmpParent ("r$PID")
$pushedRootLocation = $false

$ForbiddenRuntimeDirNames = @("__pycache__", ".execution_cache", ".version_history", ".evolution_snapshot", ".nihil_backup", ".pipeline_cache", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".release_tmp", "yijing_history", ".soulbot", "htmlcov", "node_modules", "dist", "build", ".tox", ".hypothesis", ".venv", "venv", "env")
$ForbiddenRuntimeFileNames = @("conversation_context.json", "pipeline_run_metadata.json", ".audit_log.json", "credentials.json", ".netrc")
$ForbiddenRuntimeFilePatterns = @("_*payload*.json", "_spans*.jsonl*", "*_backup.*", "*.backup.*", "*.bak", "*.backup*", "*.pyc", "*.pyo", "*.tmp", "*.log", "*.pid", "*.pem", "*.key", "*.pkcs12", "id_rsa*", "id_ed25519*", "service-account*.json", "*.db", "*.db-wal", "*.db-shm", "*.db-journal", "*.sqlite")

function Invoke-Checked([string]$Label, [scriptblock]$Command) {
  Write-Host "==> $Label"
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE"
  }
}

function New-ReleaseTempBase([string]$Prefix) {
  $root = Assert-PathWithinRoot $releaseTmpRoot
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  $safePrefix = ($Prefix -replace '[^A-Za-z0-9]', '')
  if ($safePrefix.Length -gt 3) {
    $safePrefix = $safePrefix.Substring(0, 3)
  }
  if (-not $safePrefix) {
    $safePrefix = "tmp"
  }
  $path = Assert-PathWithinRoot (Join-Path $root ($safePrefix + [guid]::NewGuid().ToString("N").Substring(0, 8)))
  New-Item -ItemType Directory -Force -Path $path | Out-Null
  return $path
}

function Remove-ReleaseTempRoot {
  try {
    if (Test-Path -LiteralPath $releaseTmpRoot) {
      Remove-Item -LiteralPath $releaseTmpRoot -Recurse -Force
    }
    if ((Test-Path -LiteralPath $releaseTmpParent -PathType Container) -and -not (Get-ChildItem -LiteralPath $releaseTmpParent -Force -ErrorAction SilentlyContinue)) {
      Remove-Item -LiteralPath $releaseTmpParent -Force -ErrorAction SilentlyContinue
    }
  }
  catch {
    Write-Host "release temp cleanup skipped: $($_.Exception.Message)"
  }
}

function Assert-NoForbiddenRuntimeArtifacts {
  $skipDirNames = @('.git')
  $found = @()
  $found += Get-ChildItem -LiteralPath $rootPath -Recurse -Force -Directory |
    Where-Object {
      -not (Test-RelativePathHasSkippedPart (Get-RepoRelativePath $_.FullName) $skipDirNames) -and
      $ForbiddenRuntimeDirNames -contains $_.Name
    }
  $found += Get-ChildItem -LiteralPath $rootPath -Recurse -Force -File |
    Where-Object {
      -not (Test-RelativePathHasSkippedPart (Get-RepoRelativePath $_.FullName) $skipDirNames) -and
      (Test-ForbiddenRuntimeFileName $_.Name)
    }
  if ($found) {
    throw "Forbidden runtime/private artifacts found:`n$($found.FullName -join "`n")"
  }
}

function Test-ForbiddenRuntimeFileName([string]$Name) {
  if ($ForbiddenRuntimeFileNames -contains $Name) {
    return $true
  }
  foreach ($pattern in $ForbiddenRuntimeFilePatterns) {
    if ($Name -like $pattern) {
      return $true
    }
  }
  return $false
}

function Get-ForbiddenRuntimeArtifactsUnder([string]$BasePath, [switch]$TreatGitAsForbidden) {
  if (-not (Test-Path -LiteralPath $BasePath -PathType Container)) {
    return @()
  }
  $forbiddenDirs = @($ForbiddenRuntimeDirNames)
  if ($TreatGitAsForbidden) {
    $forbiddenDirs += ".git"
  }
  $items = @()
  $items += Get-ChildItem -LiteralPath $BasePath -Recurse -Force -Directory |
    Where-Object { $forbiddenDirs -contains $_.Name }
  $items += Get-ChildItem -LiteralPath $BasePath -Recurse -Force -File |
    Where-Object { Test-ForbiddenRuntimeFileName $_.Name }
  return @($items | Sort-Object FullName)
}

function Remove-ForbiddenRuntimeArtifactsUnder([string]$BasePath, [switch]$TreatGitAsForbidden) {
  foreach ($item in @(Get-ForbiddenRuntimeArtifactsUnder $BasePath -TreatGitAsForbidden:$TreatGitAsForbidden | Sort-Object FullName -Descending)) {
    $full = Assert-PathWithinRoot $item.FullName
    Remove-Item -LiteralPath $full -Recurse -Force
  }
}

function Get-FilteredFileHashMap([string]$BasePath) {
  if (-not (Test-Path -LiteralPath $BasePath -PathType Container)) {
    throw "Engine bundle not found: $BasePath"
  }
  $base = (Resolve-Path -LiteralPath $BasePath).Path
  $map = @{}
  Get-ChildItem -LiteralPath $base -Recurse -Force -File |
    Where-Object {
      $rel = $_.FullName.Substring($base.Length + 1)
      $parts = $rel -split '[\\/]'
      -not (@($parts | Where-Object { $ForbiddenRuntimeDirNames -contains $_ }).Count) -and
      -not (Test-ForbiddenRuntimeFileName $_.Name)
    } |
    ForEach-Object {
      $rel = $_.FullName.Substring($base.Length + 1).Replace('\', '/')
      $map[$rel] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
  return $map
}

function Assert-EngineBundleSynced([string]$SourcePath, [string]$TargetPath, [string]$Label) {
  $sourceMap = Get-FilteredFileHashMap $SourcePath
  $targetMap = Get-FilteredFileHashMap $TargetPath
  $diffs = @()
  foreach ($rel in @($sourceMap.Keys + $targetMap.Keys | Sort-Object -Unique)) {
    if (-not $sourceMap.ContainsKey($rel)) {
      $diffs += "$Label target-only $rel"
    } elseif (-not $targetMap.ContainsKey($rel)) {
      $diffs += "$Label target-missing $rel"
    } elseif ($sourceMap[$rel] -ne $targetMap[$rel]) {
      $diffs += "$Label hash-diff $rel"
    }
  }
  if ($diffs) {
    throw "Engine bundle drift detected:`n$($diffs -join "`n")"
  }
}

function Read-JsonFile([string]$PathValue) {
  if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
    throw "Required JSON file not found: $PathValue"
  }
  try {
    return Get-Content -LiteralPath $PathValue -Raw | ConvertFrom-Json
  }
  catch {
    throw "Invalid JSON file: $PathValue`n$($_.Exception.Message)"
  }
}

function Assert-SameFileHash([string]$ExpectedPath, [string]$ActualPath, [string]$Label) {
  if (-not (Test-Path -LiteralPath $ExpectedPath -PathType Leaf)) {
    throw "Expected file missing for ${Label}: $ExpectedPath"
  }
  if (-not (Test-Path -LiteralPath $ActualPath -PathType Leaf)) {
    throw "Actual file missing for ${Label}: $ActualPath"
  }
  $expectedHash = (Get-FileHash -LiteralPath $ExpectedPath -Algorithm SHA256).Hash
  $actualHash = (Get-FileHash -LiteralPath $ActualPath -Algorithm SHA256).Hash
  if ($expectedHash -ne $actualHash) {
    throw "$Label hash mismatch: $ActualPath is not synced with $ExpectedPath"
  }
}

function Assert-DistributionLicenseCopies {
  $copyDirs = @(
    "soulagent",
    "claude_code_plugin",
    "claude_code_plugin\skills\run",
    "codex_plugin",
    "codex_plugin\skills\run"
  )
  foreach ($name in @("LICENSE", "NOTICE")) {
    $rootFile = Join-Path $rootPath $name
    foreach ($relDir in $copyDirs) {
      Assert-SameFileHash $rootFile (Join-Path (Join-Path $rootPath $relDir) $name) "$relDir $name"
    }
  }
}

function Assert-TextDoesNotMatch([string]$PathValue, [string]$Label, [string[]]$ForbiddenPatterns) {
  if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
    throw "Adapter boundary check missing file for ${Label}: $PathValue"
  }
  $text = Get-Content -LiteralPath $PathValue -Raw
  foreach ($pattern in $ForbiddenPatterns) {
    if ($text -match $pattern) {
      throw "$Label contains adapter-specific text from another host: $pattern"
    }
  }
}

function Assert-TextMatches([string]$PathValue, [string]$Label, [string[]]$RequiredPatterns) {
  if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
    throw "Required text file missing for ${Label}: $PathValue"
  }
  $text = Get-Content -LiteralPath $PathValue -Raw
  foreach ($pattern in $RequiredPatterns) {
    if ($text -notmatch $pattern) {
      throw "$Label missing required version/provenance pattern: $pattern"
    }
  }
}

function Get-AisopSystemContent([string]$PathValue, [string]$Label) {
  $doc = Read-JsonFile $PathValue
  $messages = @($doc)
  $systemMessage = @($messages | Where-Object { $_.role -eq "system" } | Select-Object -First 1)
  if (-not $systemMessage -or -not $systemMessage[0].content) {
    throw "$Label missing system.content in start.aisop.json"
  }
  return $systemMessage[0].content
}

function Assert-VersionConsistency {
  $expectedVersion = "1.0.0"
  $expectedProtocol = "AIAP V1.0.0"
  $expectedVersionText = "v1.0.0"

  $startPrograms = @(
    @{
      Label = "Root engine"
      Path = Join-Path $sourceEnginePath "start.aisop.json"
    },
    @{
      Label = "Claude bundled engine"
      Path = Join-Path (Join-Path $claudeSkillPath "soulagent") "start.aisop.json"
    },
    @{
      Label = "Codex bundled engine"
      Path = Join-Path (Join-Path $codexSkillPath "soulagent") "start.aisop.json"
    }
  )

  foreach ($entry in $startPrograms) {
    $content = Get-AisopSystemContent $entry.Path $entry.Label
    if ($content.protocol -ne $expectedProtocol) {
      throw "$($entry.Label) protocol must be '$expectedProtocol'. Current: '$($content.protocol)'"
    }
    if ($content.version -ne $expectedVersion) {
      throw "$($entry.Label) start.aisop.json version must be '$expectedVersion'. Current: '$($content.version)'"
    }
    if ($content.name -notmatch [regex]::Escape($expectedVersionText)) {
      throw "$($entry.Label) start.aisop.json name must include '$expectedVersionText'. Current: '$($content.name)'"
    }
  }

  $claudeMarketplace = Read-JsonFile (Join-Path $rootPath ".claude-plugin\marketplace.json")
  if ($claudeMarketplace.plugins[0].version -ne $expectedVersion) {
    throw "Claude marketplace plugin version must be '$expectedVersion'."
  }
  $claudeManifest = Read-JsonFile (Join-Path $claudePluginPath ".claude-plugin\plugin.json")
  if ($claudeManifest.version -ne $expectedVersion) {
    throw "Claude plugin manifest version must be '$expectedVersion'."
  }
  $claudeMeta = Read-JsonFile (Join-Path $claudePluginPath "_meta.json")
  if ($claudeMeta.latest.version -ne $expectedVersion) {
    throw "Claude plugin _meta latest.version must be '$expectedVersion'."
  }
  $codexManifest = Read-JsonFile (Join-Path $codexPluginPath ".codex-plugin\plugin.json")
  if ($codexManifest.version -ne $expectedVersion) {
    throw "Codex plugin manifest version must be '$expectedVersion'."
  }

  Assert-TextMatches (Join-Path $rootPath "README.md") "README.md" @(
    'version-1\.0\.0',
    'version 1\.0\.0',
    'v1\.0\.0',
    'soulagent-1\.0\.0\.zip'
  )
  Assert-TextMatches (Join-Path $rootPath "README_CN.md") "README_CN.md" @(
    'version-1\.0\.0',
    '版本 1\.0\.0',
    'v1\.0\.0',
    'soulagent-1\.0\.0\.zip'
  )
  Assert-TextMatches (Join-Path $rootPath "CHANGELOG.md") "CHANGELOG.md" @(
    '(?m)^## \[1\.0\.0\] - ',
    '\[1\.0\.0\]: https://github\.com/AIXP-Labs/SoulAgent/releases/tag/v1\.0\.0',
    'Claude `_meta\.json` registry manifest',
    'Codex `\.codex-plugin/plugin\.json` \+ `\.agents/plugins/marketplace\.json`'
  )
  Assert-TextMatches (Join-Path $rootPath "GOVERNANCE.md") "GOVERNANCE.md" @(
    'Claude plugin manifest and `_meta\.json`',
    'Codex plugin manifest and marketplace index',
    'host-neutral skill footer'
  )
  Assert-TextMatches (Join-Path $rootPath "soulagent\SKILL.md") "Host-neutral SKILL.md" @(
    'SoulAgent v1\.0\.0 \(host-neutral\)'
  )
  Assert-TextMatches (Join-Path $claudeSkillPath "SKILL.md") "Claude SKILL.md" @(
    'SoulAgent v1\.0\.0'
  )
  Assert-TextMatches (Join-Path $codexSkillPath "SKILL.md") "Codex SKILL.md" @(
    'SoulAgent v1\.0\.0 \(Codex\)'
  )
}

function Assert-AdapterTextBoundaries {
  $codexFiles = @(
    (Join-Path $codexPluginPath "README.md"),
    (Join-Path $codexSkillPath "SKILL.md"),
    (Join-Path $codexSkillPath "agents\openai.yaml"),
    (Join-Path $codexPluginPath ".codex-plugin\plugin.json")
  )
  $codexForbidden = @(
    'CLAUDE_SKILL_DIR',
    'disable-model-invocation',
    'argument-hint',
    'allowed-tools',
    '/soulagent:run',
    'Claude Code Task tool'
  )
  foreach ($path in $codexFiles) {
    Assert-TextDoesNotMatch $path "Codex adapter $path" $codexForbidden
  }

  $claudeFiles = @(
    (Join-Path $claudePluginPath "README.md"),
    (Join-Path $claudeSkillPath "SKILL.md"),
    (Join-Path $claudePluginPath ".claude-plugin\plugin.json"),
    (Join-Path $claudePluginPath "_meta.json")
  )
  $claudeForbidden = @(
    'CODEX_HOME',
    '(?i)codex plugin marketplace',
    'codex_plugin[\\/]',
    '\$soulagent-run',
    'SKILL_ROOT',
    '(?i)Codex skill'
  )
  foreach ($path in $claudeFiles) {
    Assert-TextDoesNotMatch $path "Claude adapter $path" $claudeForbidden
  }
}

function Assert-CodexPluginShape {
  $approvedEmail = "noreply@SoulAgent.dev"
  $expectedVersion = "1.0.0"
  $expectedRepository = "https://github.com/AIXP-Labs/SoulAgent"
  $expectedLicense = "Apache-2.0"
  $expectedHomepage = "https://soulagent.dev/"
  $expectedPrivacyUrl = "https://github.com/AIXP-Labs/SoulAgent/blob/main/PRIVACY.md"
  $expectedTermsUrl = "https://github.com/AIXP-Labs/SoulAgent/blob/main/LICENSE"
  $expectedBrandColor = "#2563EB"
  $marketplacePath = Join-Path $rootPath ".agents\plugins\marketplace.json"
  $pluginManifestPath = Join-Path $codexPluginPath ".codex-plugin\plugin.json"
  $skillPath = Join-Path $codexSkillPath "SKILL.md"
  $enginePath = Join-Path $codexSkillPath "soulagent\start.aisop.json"

  $marketplace = Read-JsonFile $marketplacePath
  if ($marketplace.name -ne "soulagent") {
    throw "Codex marketplace name must be 'soulagent'."
  }
  if ($marketplace.interface.displayName -ne "SoulAgent") {
    throw "Codex marketplace interface.displayName must be 'SoulAgent'."
  }
  if (-not $marketplace.plugins -or $marketplace.plugins.Count -ne 1) {
    throw "Codex marketplace must contain exactly one plugin entry."
  }
  $pluginEntry = $marketplace.plugins[0]
  if ($pluginEntry.name -ne "soulagent") {
    throw "Codex marketplace plugin name must be 'soulagent'."
  }
  if ($pluginEntry.source.path -ne "./codex_plugin") {
    throw "Codex marketplace plugin source.path must be './codex_plugin'."
  }
  if ($pluginEntry.source.source -ne "local") {
    throw "Codex marketplace plugin source.source must be 'local'."
  }
  if ($pluginEntry.policy.installation -ne "AVAILABLE") {
    throw "Codex marketplace plugin policy.installation must be 'AVAILABLE'."
  }
  if ($pluginEntry.policy.authentication -ne "ON_INSTALL") {
    throw "Codex marketplace plugin policy.authentication must be 'ON_INSTALL'."
  }
  if ($pluginEntry.category -ne "Productivity") {
    throw "Codex marketplace plugin category must be 'Productivity'."
  }

  $manifest = Read-JsonFile $pluginManifestPath
  if ($manifest.name -ne "soulagent") {
    throw "Codex plugin manifest name must be 'soulagent'."
  }
  if ($manifest.interface.displayName -ne "SoulAgent") {
    throw "Codex plugin interface.displayName must be 'SoulAgent'."
  }
  if ($manifest.interface.developerName -ne "SoulAgent.dev") {
    throw "Codex plugin interface.developerName must be 'SoulAgent.dev'."
  }
  if ($manifest.interface.category -ne "Productivity") {
    throw "Codex plugin interface.category must be 'Productivity'."
  }
  if ($manifest.version -ne $expectedVersion) {
    throw "Codex plugin manifest version must be '$expectedVersion'."
  }
  if ($manifest.repository -ne $expectedRepository) {
    throw "Codex plugin manifest repository must be '$expectedRepository'."
  }
  if ($manifest.homepage -ne $expectedHomepage) {
    throw "Codex plugin manifest homepage must be '$expectedHomepage'."
  }
  if ($manifest.interface.websiteURL -ne $expectedHomepage) {
    throw "Codex plugin interface.websiteURL must be '$expectedHomepage'."
  }
  if ($manifest.interface.privacyPolicyURL -ne $expectedPrivacyUrl) {
    throw "Codex plugin interface.privacyPolicyURL must be '$expectedPrivacyUrl'."
  }
  if ($manifest.interface.termsOfServiceURL -ne $expectedTermsUrl) {
    throw "Codex plugin interface.termsOfServiceURL must be '$expectedTermsUrl'."
  }
  if ($manifest.license -ne $expectedLicense) {
    throw "Codex plugin manifest license must be '$expectedLicense'."
  }
  $capabilities = @($manifest.interface.capabilities)
  $expectedCapabilities = @("Interactive", "Read", "Write")
  $capabilityDiff = Compare-Object -ReferenceObject $expectedCapabilities -DifferenceObject $capabilities
  if ($capabilityDiff) {
    throw "Codex plugin interface.capabilities must be exactly: $($expectedCapabilities -join ', '). Current: $($capabilities -join ', ')"
  }
  if ($manifest.skills -ne "./skills/") {
    throw "Codex plugin manifest skills must be './skills/'."
  }
  if ($manifest.author.email -ne $approvedEmail) {
    throw "Codex plugin manifest author email is not the approved anonymous address."
  }
  if ($manifest.author.name -ne "SoulAgent.dev") {
    throw "Codex plugin manifest author name must be 'SoulAgent.dev'."
  }
  if ($manifest.interface.brandColor -ne $expectedBrandColor) {
    throw "Codex plugin interface.brandColor must be '$expectedBrandColor'."
  }
  $defaultPromptText = ($manifest.interface.defaultPrompt -join "`n")
  if ($defaultPromptText -notmatch 'Use \$soulagent-run ') {
    throw "Codex plugin manifest defaultPrompt must mention `$soulagent-run."
  }
  if (-not (Test-Path -LiteralPath (Join-Path $codexPluginPath "README.md") -PathType Leaf)) {
    throw "Codex plugin README.md missing."
  }
  if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
    throw "Codex skill SKILL.md missing: $skillPath"
  }
  $skillText = Get-Content -LiteralPath $skillPath -Raw
  foreach ($required in @(
    '(?m)^name:\s*"soulagent-run"\s*$',
    '(?m)^license:\s*"Apache-2\.0"\s*$',
    '(?m)^description:\s*".*AIAP package creation or evolution.*"\s*$'
  )) {
    if ($skillText -notmatch $required) {
      throw "Codex skill SKILL.md frontmatter missing required pattern: $required"
    }
  }
  if ($skillText -match 'CLAUDE_SKILL_DIR|disable-model-invocation|argument-hint') {
    throw "Codex skill contains Claude-specific adapter text."
  }
  if ($skillText -notmatch 'python -B -X utf8 soulagent/start\.py') {
    throw "Codex skill must bootstrap with python -B -X utf8."
  }
  if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Codex bundled engine bootstrap missing: $enginePath"
  }
}

function Assert-CodexSkillUiMetadata {
  $openAiYaml = Join-Path $codexSkillPath "agents\openai.yaml"
  $pluginManifestPath = Join-Path $codexPluginPath ".codex-plugin\plugin.json"
  if (-not (Test-Path -LiteralPath $openAiYaml -PathType Leaf)) {
    throw "Codex skill UI metadata missing: $openAiYaml"
  }
  $manifest = Read-JsonFile $pluginManifestPath
  $text = Get-Content -LiteralPath $openAiYaml -Raw
  if ($text -notmatch 'display_name:\s*"SoulAgent Run"') {
    throw "Codex skill UI metadata display_name is stale."
  }
  $expectedShortDescription = [regex]::Escape($manifest.interface.shortDescription)
  if ($text -notmatch "short_description:\s*`"$expectedShortDescription`"") {
    throw "Codex skill UI metadata short_description must match plugin interface.shortDescription."
  }
  $expectedBrandColor = [regex]::Escape($manifest.interface.brandColor)
  if ($text -notmatch "brand_color:\s*`"$expectedBrandColor`"") {
    throw "Codex skill UI metadata brand_color must match plugin interface.brandColor."
  }
  if ($text -notmatch 'default_prompt:\s*"Use \$soulagent-run ') {
    throw "Codex skill UI metadata default_prompt must mention `$soulagent-run."
  }
}

function Assert-ClaudePluginMetadata {
  $approvedEmail = 'noreply@SoulAgent.dev'
  $repositoryUrl = 'https://github.com/AIXP-Labs/SoulAgent'
  $homepageUrl = 'https://soulagent.dev/'
  $expectedVersion = '1.0.0'
  $expectedLicense = 'Apache-2.0'

  $marketplacePath = Join-Path $rootPath '.claude-plugin\marketplace.json'
  $pluginManifestPath = Join-Path $claudePluginPath '.claude-plugin\plugin.json'
  $metaPath = Join-Path $claudePluginPath '_meta.json'

  $marketplace = Read-JsonFile $marketplacePath
  if ($marketplace.name -ne 'soulagent') {
    throw "Claude marketplace name must be 'soulagent'."
  }
  if ($marketplace.owner.email -ne $approvedEmail) {
    throw 'Claude marketplace owner email is not the approved anonymous address.'
  }
  if (-not $marketplace.plugins -or $marketplace.plugins.Count -ne 1) {
    throw 'Claude marketplace must contain exactly one plugin entry.'
  }
  $entry = $marketplace.plugins[0]
  if ($entry.name -ne 'soulagent') {
    throw "Claude marketplace plugin name must be 'soulagent'."
  }
  if ($entry.version -ne $expectedVersion) {
    throw "Claude marketplace plugin version must be '$expectedVersion'."
  }
  if ($entry.source -ne './claude_code_plugin') {
    throw "Claude marketplace plugin source must be './claude_code_plugin'."
  }
  if ($entry.author.email -ne $approvedEmail) {
    throw 'Claude marketplace plugin author email is not the approved anonymous address.'
  }
  if ($entry.author.name -ne 'SoulAgent.dev') {
    throw "Claude marketplace plugin author name must be 'SoulAgent.dev'."
  }
  if ($entry.homepage -ne $homepageUrl) {
    throw "Claude marketplace plugin homepage must be '$homepageUrl'."
  }
  if ($entry.repository -ne $repositoryUrl) {
    throw "Claude marketplace repository must be '$repositoryUrl'."
  }
  if ($entry.license -ne $expectedLicense) {
    throw "Claude marketplace license must be '$expectedLicense'."
  }
  if ($entry.category -ne 'productivity') {
    throw "Claude marketplace category must be 'productivity'."
  }

  $manifest = Read-JsonFile $pluginManifestPath
  if ($manifest.name -ne 'soulagent') {
    throw "Claude plugin manifest name must be 'soulagent'."
  }
  if ($manifest.displayName -ne 'SoulAgent') {
    throw "Claude plugin manifest displayName must be 'SoulAgent'."
  }
  if ($manifest.version -ne $expectedVersion) {
    throw "Claude plugin manifest version must be '$expectedVersion'."
  }
  if ($manifest.author.email -ne $approvedEmail) {
    throw 'Claude plugin manifest author email is not the approved anonymous address.'
  }
  if ($manifest.author.name -ne 'SoulAgent.dev') {
    throw "Claude plugin manifest author name must be 'SoulAgent.dev'."
  }
  if ($manifest.homepage -ne $homepageUrl) {
    throw "Claude plugin manifest homepage must be '$homepageUrl'."
  }
  if ($manifest.repository -ne $repositoryUrl) {
    throw "Claude plugin manifest repository must be '$repositoryUrl'."
  }
  if ($manifest.license -ne $expectedLicense) {
    throw "Claude plugin manifest license must be '$expectedLicense'."
  }

  $meta = Read-JsonFile $metaPath
  if ($meta.latest.version -ne $expectedVersion) {
    throw "Claude plugin _meta latest.version must be '$expectedVersion'."
  }
  if ($meta.author.email -ne $approvedEmail) {
    throw 'Claude plugin _meta author email is not the approved anonymous address.'
  }
  if ($meta.author.name -ne 'SoulAgent.dev') {
    throw "Claude plugin _meta author name must be 'SoulAgent.dev'."
  }
  if ($meta.homepage -ne $homepageUrl) {
    throw "Claude plugin _meta homepage must be '$homepageUrl'."
  }
  if ($meta.repository -ne $repositoryUrl) {
    throw "Claude plugin _meta repository must be '$repositoryUrl'."
  }
  if ($meta.license -ne $expectedLicense) {
    throw "Claude plugin _meta license must be '$expectedLicense'."
  }
}

function Assert-GitRepositoryMetadata {
  $expectedRemote = 'https://github.com/AIXP-Labs/SoulAgent.git'
  $expectedUserName = 'SoulAgent.dev'
  $expectedUserEmail = 'noreply@SoulAgent.dev'

  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) {
    throw 'git is required for release metadata checks.'
  }

  $remote = (& git -C $rootPath remote get-url origin 2>$null)
  if ($LASTEXITCODE -ne 0 -or $remote -ne $expectedRemote) {
    throw "Git origin must be '$expectedRemote'. Current: '$remote'"
  }

  $userName = (& git -C $rootPath config --get user.name 2>$null)
  if ($LASTEXITCODE -ne 0 -or $userName -ne $expectedUserName) {
    throw "Git user.name must be '$expectedUserName'. Current: '$userName'"
  }

  $userEmail = (& git -C $rootPath config --get user.email 2>$null)
  if ($LASTEXITCODE -ne 0 -or $userEmail -ne $expectedUserEmail) {
    throw "Git user.email must be '$expectedUserEmail'. Current: '$userEmail'"
  }
}

function Assert-ClaudeSkillShape {
  $skillPath = Join-Path $claudeSkillPath "SKILL.md"
  $readmePath = Join-Path $claudePluginPath "README.md"
  $enginePath = Join-Path $claudeSkillPath "soulagent\start.aisop.json"
  if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
    throw "Claude skill SKILL.md missing: $skillPath"
  }
  if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
    throw "Claude plugin README.md missing: $readmePath"
  }
  if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Claude bundled engine bootstrap missing: $enginePath"
  }
  $text = Get-Content -LiteralPath $skillPath -Raw
  $readmeText = Get-Content -LiteralPath $readmePath -Raw
  if ($text -notmatch '(?m)^name:\s*run\s*$') {
    throw "Claude skill frontmatter must keep name: run."
  }
  if ($text -notmatch '(?m)^disable-model-invocation:\s*true\s*$') {
    throw "Claude skill must keep disable-model-invocation: true."
  }
  if ($text -notmatch '(?m)^allowed-tools:\s*Read Write Task Bash\(python \*\) Bash\(python3 \*\)\s*$') {
    throw "Claude skill allowed-tools must stay limited to Read/Write/Task/Python Bash."
  }
  if ($readmeText -notmatch 'Read Write Task Bash\(python \*\) Bash\(python3 \*\)') {
    throw "Claude plugin README scoped adapter tools must match SKILL.md allowed-tools."
  }
  if ($text -notmatch '\$\{CLAUDE_SKILL_DIR\}\\soulagent\\start\.aisop\.json') {
    throw "Claude skill must address the bundled engine through `${CLAUDE_SKILL_DIR}\soulagent\..."
  }
  if ($text -notmatch 'python -B -X utf8 .*start\.py') {
    throw "Claude skill must bootstrap with python -B -X utf8."
  }
  if ($text -match 'concatenate user text into a shell command string' -and $text -notmatch 'do not concatenate user text into a shell command string') {
    throw "Claude skill command-injection guard wording is malformed."
  }
}

function Get-RepoRelativePath([string]$PathValue) {
  return $PathValue.Substring($rootPath.Length + 1).Replace('\', '/')
}

function Test-RelativePathHasSkippedPart([string]$RelativePath, [string[]]$SkipDirNames) {
  $parts = $RelativePath -split '[\\/]'
  return @($parts | Where-Object { $SkipDirNames -contains $_ }).Count -gt 0
}

function Assert-PathWithinRoot([string]$PathValue) {
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

function Assert-HostNeutralSkillShape {
  $skillPath = Join-Path $rootPath "soulagent\SKILL.md"
  if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
    throw "Host-neutral root SKILL.md missing: $skillPath"
  }
  $text = Get-Content -LiteralPath $skillPath -Raw
  if ($text -notmatch '(?m)^name:\s*soulagent\s*$') {
    throw "Host-neutral root SKILL.md frontmatter must keep name: soulagent."
  }
  if ($text -notmatch 'python -B -X utf8 soulagent/start\.py') {
    throw "Host-neutral root SKILL.md must bootstrap with python -B -X utf8."
  }
  foreach ($stale in @(
    'python -X utf8 soulagent/start.py',
    'always invoke `python -X utf8`'
  )) {
    if ($text.Contains($stale)) {
      throw "Host-neutral root SKILL.md contains stale Python invocation wording: $stale"
    }
  }
}

function Assert-RepositoryPolicyFiles {
  $gitAttributesPath = Join-Path $rootPath ".gitattributes"
  $gitIgnorePath = Join-Path $rootPath ".gitignore"
  $workflowPath = Join-Path $rootPath ".github\workflows\release-check.yml"
  $requirementsPath = Join-Path $rootPath "requirements-dev.txt"

  if (-not (Test-Path -LiteralPath $gitAttributesPath -PathType Leaf)) {
    throw ".gitattributes missing; LF normalization policy is required."
  }
  if (-not (Test-Path -LiteralPath $gitIgnorePath -PathType Leaf)) {
    throw ".gitignore missing; runtime/private artifact exclusions are required."
  }
  if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
    throw ".github/workflows/release-check.yml missing; GitHub release gate is required."
  }
  if (-not (Test-Path -LiteralPath $requirementsPath -PathType Leaf)) {
    throw "requirements-dev.txt missing; release-check Python dependencies must be declared."
  }

  $attributesText = Get-Content -LiteralPath $gitAttributesPath -Raw
  foreach ($required in @(
    "* text=auto eol=lf",
    "*.png binary",
    "*.jpg binary",
    "*.zip binary"
  )) {
    if (-not $attributesText.Contains($required)) {
      throw ".gitattributes missing required policy line: $required"
    }
  }

  $ignoreText = Get-Content -LiteralPath $gitIgnorePath -Raw
  foreach ($required in @(
    "__pycache__/",
    "*.py[cod]",
    ".venv/",
    "venv/",
    "env/",
    ".release_tmp/",
    "htmlcov/",
    ".hypothesis/",
    ".tox/",
    "dist/",
    "build/",
    "node_modules/",
    "**/.execution_cache/",
    "**/conversation_context.json",
    "**/.version_history/",
    "**/.evolution_snapshot/",
    "**/.pipeline_cache/",
    "**/pipeline_run_metadata.json",
    "**/yijing_history/",
    "**/.audit_log.json",
    "*_backup.*",
    "*.backup.*",
    "**/.nihil_backup/",
    "*.log",
    "*.pid",
    "**/.soulbot/",
    "*.pem",
    "*.key",
    "*.pkcs12",
    "id_rsa*",
    "id_ed25519*",
    "credentials.json",
    "service-account*.json",
    ".netrc",
    "*.db",
    "*.db-wal",
    "*.db-shm",
    "*.db-journal",
    "*.sqlite"
  )) {
    if (-not $ignoreText.Contains($required)) {
      throw ".gitignore missing required exclusion: $required"
    }
  }

  $workflowText = Get-Content -LiteralPath $workflowPath -Raw
  foreach ($required in @(
    "workflow_dispatch:",
    "windows-latest",
    "timeout-minutes: 20",
    "permissions:",
    "contents: read",
    "actions/checkout@v4",
    "actions/setup-python@v5",
    'python-version: "3.12"',
    "python -m pip install -r requirements-dev.txt",
    "git config user.name SoulAgent.dev",
    "git config user.email noreply@SoulAgent.dev",
    "git remote set-url origin https://github.com/AIXP-Labs/SoulAgent.git",
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_check.ps1",
    "git diff --check",
    "git diff --exit-code -- ."
  )) {
    if (-not $workflowText.Contains($required)) {
      throw ".github/workflows/release-check.yml missing required release-gate line: $required"
    }
  }

  $requirementsText = Get-Content -LiteralPath $requirementsPath -Raw
  if ($requirementsText -notmatch '(?m)^PyYAML>=6,<7\s*$') {
    throw "requirements-dev.txt must pin the release-check YAML parser dependency as PyYAML>=6,<7."
  }
}

function Get-PackagingSnippet([string]$PathValue) {
  $lines = @(Get-Content -LiteralPath $PathValue)
  $start = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Contains('$stage = "<path-to>\_pkg\soulagent"')) {
      $start = $i
      break
    }
  }
  if ($start -lt 0) {
    throw "Packaging example missing staging command: $PathValue"
  }

  $end = -1
  for ($i = $start; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Contains('Compress-Archive -Path "$stage\*"')) {
      $end = $i
      break
    }
  }
  if ($end -lt $start) {
    throw "Packaging example missing Compress-Archive command: $PathValue"
  }
  return ($lines[$start..$end] -join "`n")
}

function Assert-PackagingExampleExclusions {
  $requiredTokens = @()
  $requiredTokens += $ForbiddenRuntimeDirNames
  $requiredTokens += ".git"
  $requiredTokens += $ForbiddenRuntimeFileNames
  $requiredTokens += $ForbiddenRuntimeFilePatterns
  $requiredTokens += "coverage.xml"
  $requiredTokens += ".coverage"

  $findings = @()
  foreach ($rel in @("README.md", "README_CN.md")) {
    $path = Join-Path $rootPath $rel
    $snippet = Get-PackagingSnippet $path
    foreach ($token in ($requiredTokens | Sort-Object -Unique)) {
      if (-not $snippet.Contains($token)) {
        $findings += "${rel} packaging example missing exclusion token: $token"
      }
    }
  }
  if ($findings) {
    throw "Packaging example exclusion check failed:`n$($findings -join "`n")"
  }
}

function Invoke-ClaudePackageStageSmoke {
  $tmpBase = New-ReleaseTempBase "claude-package"
  $stage = Assert-PathWithinRoot (Join-Path $tmpBase ("claude-package-" + [guid]::NewGuid().ToString("N")))
  $zipPath = Assert-PathWithinRoot (Join-Path $tmpBase ("soulagent-package-" + [guid]::NewGuid().ToString("N") + ".zip"))
  $extract = Assert-PathWithinRoot (Join-Path $tmpBase ("claude-package-extract-" + [guid]::NewGuid().ToString("N")))
  $requiredFiles = @(
    ".claude-plugin\plugin.json",
    "_meta.json",
    "LICENSE",
    "NOTICE",
    "skills\run\SKILL.md",
    "skills\run\soulagent\start.aisop.json",
    "skills\run\soulagent\start.py"
  )
  New-Item -ItemType Directory -Force -Path $stage | Out-Null
  try {
    Get-ChildItem -LiteralPath $claudePluginPath -Force |
      ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $stage -Recurse -Force
      }
    Remove-ForbiddenRuntimeArtifactsUnder $stage -TreatGitAsForbidden

    foreach ($required in $requiredFiles) {
      $path = Join-Path $stage $required
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Claude staged package smoke missing required file: $required"
      }
    }

    $forbidden = @(Get-ForbiddenRuntimeArtifactsUnder $stage -TreatGitAsForbidden)
    if ($forbidden.Count) {
      throw "Claude staged package contains forbidden runtime/private artifacts:`n$($forbidden.FullName -join "`n")"
    }

    $stageContents = Join-Path $stage "*"
    Compress-Archive -Path $stageContents -DestinationPath $zipPath -Force
    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
      throw "Claude package archive smoke did not create a zip file."
    }
    if ((Get-Item -LiteralPath $zipPath).Length -le 0) {
      throw "Claude package archive smoke created an empty zip file."
    }

    New-Item -ItemType Directory -Force -Path $extract | Out-Null
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extract -Force
    foreach ($required in $requiredFiles) {
      $path = Join-Path $extract $required
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Claude package archive smoke missing required file after unzip: $required"
      }
    }
    $extractedForbidden = @(Get-ForbiddenRuntimeArtifactsUnder $extract -TreatGitAsForbidden)
    if ($extractedForbidden.Count) {
      throw "Claude package archive contains forbidden runtime/private artifacts after unzip:`n$($extractedForbidden.FullName -join "`n")"
    }
  }
  finally {
    if (Test-Path -LiteralPath $extract) {
      Remove-Item -LiteralPath $extract -Recurse -Force
    }
    if (Test-Path -LiteralPath $zipPath) {
      Remove-Item -LiteralPath $zipPath -Force
    }
    if (Test-Path -LiteralPath $stage) {
      Remove-Item -LiteralPath $stage -Recurse -Force
    }
    if ((Test-Path -LiteralPath $tmpBase -PathType Container) -and -not (Get-ChildItem -LiteralPath $tmpBase -Force)) {
      Remove-Item -LiteralPath $tmpBase -Force
    }
  }
}

function Assert-SyncScriptExclusions {
  $syncPath = Join-Path $rootPath "scripts\sync_plugin_engines.ps1"
  if (-not (Test-Path -LiteralPath $syncPath -PathType Leaf)) {
    throw "sync_plugin_engines.ps1 missing; release packaging cannot prove bundle sync."
  }

  $requiredTokens = @()
  $requiredTokens += $ForbiddenRuntimeDirNames
  $requiredTokens += ".git"
  $requiredTokens += $ForbiddenRuntimeFileNames
  $requiredTokens += $ForbiddenRuntimeFilePatterns

  $text = Get-Content -LiteralPath $syncPath -Raw
  $findings = @()
  foreach ($token in ($requiredTokens | Sort-Object -Unique)) {
    if (-not $text.Contains($token)) {
      $findings += "sync_plugin_engines.ps1 missing forbidden artifact token: $token"
    }
  }
  if ($findings) {
    throw "Sync script exclusion check failed:`n$($findings -join "`n")"
  }
}

function Assert-AllJsonFilesParse {
  $tmpBase = New-ReleaseTempBase "json-parse"
  $tmpDir = Assert-PathWithinRoot (Join-Path $tmpBase ('json-parse-' + [guid]::NewGuid().ToString('N')))
  New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
  $scriptPath = Join-Path $tmpDir 'json_parse_check.py'
  $script = @'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
skip_parts = {".git", ".execution_cache", ".release_tmp", "__pycache__"}
errors = []

for path in root.rglob("*.json"):
    if any(part in skip_parts for part in path.parts):
        continue
    try:
        json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception as exc:
        errors.append(f"{path.relative_to(root)}: {exc}")

if errors:
    print("\n".join(errors))
    raise SystemExit(1)
'@
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($scriptPath, $script, $utf8NoBom)
  try {
    $output = & python -B -X utf8 $scriptPath $rootPath
    if ($LASTEXITCODE -ne 0) {
      throw "JSON parse check failed:`n$($output -join "`n")"
    }
  }
  finally {
    if (Test-Path -LiteralPath $tmpDir) {
      Remove-Item -LiteralPath $tmpDir -Recurse -Force
    }
    if ((Test-Path -LiteralPath $tmpBase -PathType Container) -and -not (Get-ChildItem -LiteralPath $tmpBase -Force)) {
      Remove-Item -LiteralPath $tmpBase -Force
    }
  }
}

function Assert-AllYamlFilesParse {
  $tmpBase = New-ReleaseTempBase "yaml-parse"
  $tmpDir = Assert-PathWithinRoot (Join-Path $tmpBase ('yaml-parse-' + [guid]::NewGuid().ToString('N')))
  New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
  $scriptPath = Join-Path $tmpDir 'yaml_parse_check.py'
  $script = @'
import sys
from pathlib import Path

try:
    import yaml
except Exception as exc:
    print(f"PyYAML unavailable: {exc}")
    raise SystemExit(1)

root = Path(sys.argv[1])
skip_parts = {".git", ".execution_cache", ".release_tmp", "__pycache__"}
errors = []

for pattern in ("*.yml", "*.yaml"):
    for path in root.rglob(pattern):
        if any(part in skip_parts for part in path.parts):
            continue
        try:
            parsed = yaml.safe_load(path.read_text(encoding="utf-8-sig"))
        except Exception as exc:
            errors.append(f"{path.relative_to(root)}: {exc}")
            continue
        if not isinstance(parsed, dict):
            errors.append(f"{path.relative_to(root)}: top-level YAML value must be a mapping")

if errors:
    print("\n".join(errors))
    raise SystemExit(1)
'@
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($scriptPath, $script, $utf8NoBom)
  try {
    $output = & python -B -X utf8 $scriptPath $rootPath
    if ($LASTEXITCODE -ne 0) {
      throw "YAML parse check failed:`n$($output -join "`n")"
    }
  }
  finally {
    if (Test-Path -LiteralPath $tmpDir) {
      Remove-Item -LiteralPath $tmpDir -Recurse -Force
    }
    if ((Test-Path -LiteralPath $tmpBase -PathType Container) -and -not (Get-ChildItem -LiteralPath $tmpBase -Force)) {
      Remove-Item -LiteralPath $tmpBase -Force
    }
  }
}

function Assert-PythonSyntax {
  $tmpBase = New-ReleaseTempBase "python-syntax"
  $tmpDir = Assert-PathWithinRoot (Join-Path $tmpBase ('python-syntax-' + [guid]::NewGuid().ToString('N')))
  New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
  $scriptPath = Join-Path $tmpDir 'python_syntax_check.py'
  $script = @'
import ast
import sys
from pathlib import Path

root = Path(sys.argv[1])
skip_parts = {".git", ".execution_cache", ".release_tmp", "__pycache__"}
errors = []

for path in root.rglob("*.py"):
    if any(part in skip_parts for part in path.parts):
        continue
    try:
        ast.parse(path.read_text(encoding="utf-8-sig"), filename=str(path))
    except Exception as exc:
        errors.append(f"{path.relative_to(root)}: {exc}")

if errors:
    print("\n".join(errors))
    raise SystemExit(1)
'@
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($scriptPath, $script, $utf8NoBom)
  try {
    $output = & python -B -X utf8 $scriptPath $rootPath
    if ($LASTEXITCODE -ne 0) {
      throw "Python syntax check failed:`n$($output -join "`n")"
    }
  }
  finally {
    if (Test-Path -LiteralPath $tmpDir) {
      Remove-Item -LiteralPath $tmpDir -Recurse -Force
    }
    if ((Test-Path -LiteralPath $tmpBase -PathType Container) -and -not (Get-ChildItem -LiteralPath $tmpBase -Force)) {
      Remove-Item -LiteralPath $tmpBase -Force
    }
  }
}

function Assert-PowerShellSyntax {
  $skipDirNames = @('.git', '.execution_cache', '.release_tmp', '__pycache__')
  $findings = @()
  foreach ($file in Get-ChildItem -LiteralPath $rootPath -Recurse -Force -File |
    Where-Object { $_.Extension.ToLowerInvariant() -in @('.ps1', '.psm1') }) {
    $rel = Get-RepoRelativePath $file.FullName
    if (Test-RelativePathHasSkippedPart $rel $skipDirNames) {
      continue
    }
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    foreach ($parseError in $parseErrors) {
      $findings += "${rel}: line $($parseError.Extent.StartLineNumber): $($parseError.Message)"
    }
  }
  if ($findings) {
    throw "PowerShell syntax check failed:`n$($findings -join "`n")"
  }
}

function Assert-MarkdownLocalLinks {
  $tmpBase = New-ReleaseTempBase "markdown-links"
  $tmpDir = Assert-PathWithinRoot (Join-Path $tmpBase ('markdown-links-' + [guid]::NewGuid().ToString('N')))
  New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
  $scriptPath = Join-Path $tmpDir 'markdown_link_check.py'
  $script = @'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skip_parts = {".git", ".execution_cache", ".release_tmp", "__pycache__"}
files = [
    path
    for path in root.rglob("*.md")
    if not any(part in skip_parts for part in path.parts)
]

pattern = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
if not pattern.search("[x](README.md)"):
    raise SystemExit("internal markdown link regex self-test failed")
errors = []

for path in files:
    text = path.read_text(encoding="utf-8-sig")
    for match in pattern.finditer(text):
        link = match.group(1).strip()
        if not link or link.startswith(("http://", "https://", "mailto:", "#")):
            continue
        if link.startswith("<") and link.endswith(">"):
            link = link[1:-1]
        if "#" in link:
            link = link.split("#", 1)[0]
        if not link:
            continue
        target = (path.parent / link).resolve()
        if not target.exists():
            errors.append(f"{path.relative_to(root)} -> {link}")

if errors:
    print("\n".join(errors))
    raise SystemExit(1)
'@
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($scriptPath, $script, $utf8NoBom)
  try {
    $output = & python -B -X utf8 $scriptPath $rootPath
    if ($LASTEXITCODE -ne 0) {
      throw "Markdown local link check failed:`n$($output -join "`n")"
    }
  }
  finally {
    if (Test-Path -LiteralPath $tmpDir) {
      Remove-Item -LiteralPath $tmpDir -Recurse -Force
    }
    if ((Test-Path -LiteralPath $tmpBase -PathType Container) -and -not (Get-ChildItem -LiteralPath $tmpBase -Force)) {
      Remove-Item -LiteralPath $tmpBase -Force
    }
  }
}

function Assert-DocumentationHygiene {
  $docFiles = @(
    'README.md',
    'README_CN.md',
    'GUIDE_EN.md',
    'GUIDE_CN.md',
    'ARCHITECTURE.md',
    'SECURITY.md',
    'PRIVACY.md',
    'CODE_OF_CONDUCT.md',
    'CONTRIBUTING.md',
    'CONTRIBUTING_CN.md',
    'GOVERNANCE.md',
    'soulagent\SKILL.md',
    'claude_code_plugin\README.md',
    'codex_plugin\README.md',
    'claude_code_plugin\skills\run\SKILL.md',
    'codex_plugin\skills\run\SKILL.md'
  )
  $forbiddenPatterns = @(
    'TODO',
    'TBD',
    'FIXME',
    'Status: skeleton',
    'work in progress',
    'python -X utf8 soulagent/start\.py',
    'CURRENT Claude Code session',
    'this Claude Code session',
    'capability is your Agent tool',
    'no network / web tools',
    'Codex/release',
    'Codex smoke',
    'anthropics/claude-plugins-community',
    'once listed'
  )
  $findings = @()
  foreach ($rel in $docFiles) {
    $path = Join-Path $rootPath $rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      $findings += "missing documentation file: $rel"
      continue
    }
    $text = Get-Content -LiteralPath $path -Raw
    foreach ($pattern in $forbiddenPatterns) {
      if ($text -match $pattern) {
        $findings += "$rel contains forbidden documentation marker: $pattern"
      }
    }
  }
  if ($findings) {
    throw "Documentation hygiene check failed:`n$($findings -join "`n")"
  }
}

function Assert-ReadmeHeadingStructure {
  $enPath = Join-Path $rootPath "README.md"
  $cnPath = Join-Path $rootPath "README_CN.md"
  foreach ($path in @($enPath, $cnPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "README heading structure check missing file: $path"
    }
  }

  $enLevels = @(
    Select-String -LiteralPath $enPath -Pattern '^(#{1,3}) ' |
      ForEach-Object { $_.Matches[0].Groups[1].Value.Length }
  )
  $cnLevels = @(
    Select-String -LiteralPath $cnPath -Pattern '^(#{1,3}) ' |
      ForEach-Object { $_.Matches[0].Groups[1].Value.Length }
  )

  if ($enLevels.Count -ne $cnLevels.Count) {
    throw "README heading structure mismatch: README.md has $($enLevels.Count) headings; README_CN.md has $($cnLevels.Count)."
  }
  for ($i = 0; $i -lt $enLevels.Count; $i++) {
    if ($enLevels[$i] -ne $cnLevels[$i]) {
      throw "README heading level mismatch at heading $($i + 1): README.md level $($enLevels[$i]), README_CN.md level $($cnLevels[$i])."
    }
  }
}

function Assert-PrivacyAndSecrets {
  $skipDirNames = @('.git', '.execution_cache', '.release_tmp', '__pycache__')
  $binaryExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.pdf', '.zip', '.db', '.sqlite', '.pkcs12', '.pem', '.key')
  $approvedEmail = 'noreply@SoulAgent.dev'
  $emailPattern = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
  $realWindowsPathPattern = '(?i)\b[A-Z]:\\(?:Users\\(?!<)|newworkspace\\|workspace\\)'
  $secretPattern = '(?i)(BEGIN (?:RSA|OPENSSH|PRIVATE) KEY|sk-[A-Za-z0-9]{20,}|api[_-]?key\s*[:=]\s*["''][^"'']{8,}|password\s*[:=]\s*["''][^"'']{4,}|secret\s*[:=]\s*["''][^"'']{8,})'
  $findings = @()

  foreach ($file in Get-ChildItem -LiteralPath $rootPath -Recurse -Force -File) {
    $rel = Get-RepoRelativePath $file.FullName
    if (Test-RelativePathHasSkippedPart $rel $skipDirNames) {
      continue
    }
    if ($binaryExtensions -contains $file.Extension.ToLowerInvariant()) {
      continue
    }
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    if (Test-BytesContainNul $bytes) {
      continue
    }
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    foreach ($match in [regex]::Matches($text, $emailPattern)) {
      $email = $match.Value
      if ($email -ne $approvedEmail -and -not $email.EndsWith('@example.com', [System.StringComparison]::OrdinalIgnoreCase)) {
        $findings += "${rel}: unexpected email $email"
      }
    }
    foreach ($match in [regex]::Matches($text, $realWindowsPathPattern)) {
      $findings += "${rel}: real-looking Windows path $($match.Value)"
    }
    if ($text -match $secretPattern) {
      $findings += "${rel}: secret-like token"
    }
  }

  if ($findings) {
    throw "Privacy/secrets check failed:`n$($findings -join "`n")"
  }
}

function Test-BytesContainNul([byte[]]$Bytes) {
  $limit = [Math]::Min($Bytes.Length, 4096)
  for ($i = 0; $i -lt $limit; $i++) {
    if ($Bytes[$i] -eq 0) {
      return $true
    }
  }
  return $false
}

function Test-BytesContainCr([byte[]]$Bytes) {
  foreach ($byte in $Bytes) {
    if ($byte -eq 13) {
      return $true
    }
  }
  return $false
}

function Assert-LfLineEndings {
  $skipDirNames = @('.git', '.execution_cache', '.release_tmp', '__pycache__')
  $binaryExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.pdf', '.zip', '.db', '.sqlite', '.pkcs12', '.pem', '.key')
  $findings = @()
  foreach ($file in Get-ChildItem -LiteralPath $rootPath -Recurse -Force -File) {
    $rel = $file.FullName.Substring($rootPath.Length + 1)
    $parts = $rel -split '[\\/]'
    if (@($parts | Where-Object { $skipDirNames -contains $_ }).Count) {
      continue
    }
    if ($binaryExtensions -contains $file.Extension.ToLowerInvariant()) {
      continue
    }
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    if (Test-BytesContainNul $bytes) {
      continue
    }
    if (Test-BytesContainCr $bytes) {
      $findings += $rel.Replace('\', '/')
    }
  }
  if ($findings) {
    throw "Text files must use LF line endings:`n$($findings -join "`n")"
  }
}

function Assert-StartProgramShape([string]$Label, [string]$EngineRoot) {
  $startPath = Join-Path $EngineRoot "start.aisop.json"
  $startPyPath = Join-Path $EngineRoot "start.py"
  if (-not (Test-Path -LiteralPath $startPath -PathType Leaf)) {
    throw "$Label start.aisop.json missing: $startPath"
  }
  if (-not (Test-Path -LiteralPath $startPyPath -PathType Leaf)) {
    throw "$Label start.py missing: $startPyPath"
  }

  $startPyText = Get-Content -LiteralPath $startPyPath -Raw
  if ($startPyText -notmatch 'current host session as the orchestrator') {
    throw "$Label start.py must use host-neutral orchestrator wording."
  }
  if ($startPyText -notmatch 'python -B -X utf8 start\.py "<non-empty user_message>"') {
    throw "$Label start.py usage must recommend python -B -X utf8."
  }
  foreach ($stale in @(
    'Claude Code session as the orchestrator',
    'Soul_Agent\\aiap',
    'python start.py "<non-empty user_message>"'
  )) {
    if ($startPyText.Contains($stale)) {
      throw "$Label start.py contains stale host-specific wording: $stale"
    }
  }

  $text = Get-Content -LiteralPath $startPath -Raw
  if ($text -notmatch 'CURRENT host session') {
    throw "$Label start.aisop.json must describe the current host session, not one fixed host."
  }
  if ($text -notmatch 'python -B -X utf8 start\.py') {
    throw "$Label start.aisop.json must bootstrap with python -B -X utf8."
  }
  foreach ($stale in @(
    'CURRENT Claude Code session',
    'this Claude Code session',
    'capability is your Agent tool',
    "start.py '{user_message}'",
    'single quoted argv'
  )) {
    if ($text.Contains($stale)) {
      throw "$Label start.aisop.json contains stale bootstrap wording: $stale"
    }
  }
}

function Invoke-CodexMarketplaceSmoke {
  $codex = Get-Command codex -ErrorAction SilentlyContinue
  if (-not $codex) {
    if ($RequireHostCli) {
      throw "codex not found; -RequireHostCli requires Codex marketplace smoke to run."
    }
    Write-Host "codex not found; skipping Codex marketplace smoke"
    return
  }

  $codexHomeBase = New-ReleaseTempBase "codex-marketplace"
  $codexHome = Assert-PathWithinRoot (Join-Path $codexHomeBase ("codex-marketplace-" + [guid]::NewGuid().ToString("N")))

  New-Item -ItemType Directory -Force -Path $codexHome | Out-Null
  $oldCodexHome = $env:CODEX_HOME
  try {
    $env:CODEX_HOME = $codexHome
    Invoke-Checked "Codex marketplace add smoke" {
      codex plugin marketplace add $rootPath
    }

    $configPath = Join-Path $codexHome "config.toml"
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
      throw "Codex marketplace smoke did not create config.toml"
    }
    $configText = Get-Content -LiteralPath $configPath -Raw
    if ($configText -notmatch '\[marketplaces\.soulagent\]') {
      throw "Codex marketplace smoke did not register marketplace 'soulagent'"
    }
    if ($configText -notmatch 'source_type\s*=\s*"local"') {
      throw "Codex marketplace smoke did not register a local marketplace source"
    }
  }
  finally {
    if ($null -eq $oldCodexHome) {
      Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue
    } else {
      $env:CODEX_HOME = $oldCodexHome
    }
    if (Test-Path -LiteralPath $codexHome) {
      Remove-Item -LiteralPath $codexHome -Recurse -Force
    }
    if ((Test-Path -LiteralPath $codexHomeBase -PathType Container) -and -not (Get-ChildItem -LiteralPath $codexHomeBase -Force)) {
      Remove-Item -LiteralPath $codexHomeBase -Force
    }
  }
}

function Invoke-StartPySmoke([string]$Label, [string]$EngineRoot) {
  $startPy = Join-Path $EngineRoot "start.py"
  $engineDir = Join-Path $EngineRoot "soulbot_execute_engine_aiap"
  $cacheDir = Join-Path $engineDir ".execution_cache"
  $smokeMessage = ([char]0x4F60).ToString() + ([char]0x597D).ToString() + ', UTF-8 smoke ' + [char]::ConvertFromUtf32(0x1F512)
  try {
    Write-Host "==> $Label start.py smoke"
    $output = & python -B -X utf8 $startPy $smokeMessage
    if ($LASTEXITCODE -ne 0) {
      throw "$Label start.py smoke failed with exit code $LASTEXITCODE"
    }
    $jsonText = ($output -join "`n")
    try {
      $parsed = $jsonText | ConvertFrom-Json
    }
    catch {
      throw "$Label start.py smoke did not emit valid JSON: $($_.Exception.Message)"
    }
    foreach ($field in @("status", "execution_context", "engine_dir", "router_entry", "aiap_dir", "registry", "user_message")) {
      if (-not ($parsed.PSObject.Properties.Name -contains $field)) {
        throw "$Label start.py smoke missing JSON field: $field"
      }
    }
    if ($parsed.status -ne "ok") {
      throw "$Label start.py smoke status is not ok: $($parsed.status)"
    }
    if ($parsed.user_message -ne $smokeMessage) {
      throw "$Label start.py smoke did not round-trip UTF-8 user_message."
    }
  }
  finally {
    if (Test-Path -LiteralPath $cacheDir) {
      Remove-Item -LiteralPath $cacheDir -Recurse -Force
    }
    Get-ChildItem -LiteralPath $EngineRoot -Recurse -Force -Directory -Filter "__pycache__" |
      Sort-Object FullName -Descending |
      ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
  }
}

function Invoke-StartPyEmptyInputSmoke([string]$Label, [string]$EngineRoot) {
  $startPy = Join-Path $EngineRoot "start.py"
  $engineDir = Join-Path $EngineRoot "soulbot_execute_engine_aiap"
  $cacheDir = Join-Path $engineDir ".execution_cache"
  try {
    Write-Host "==> $Label start.py empty-input smoke"
    $output = & python -B -X utf8 $startPy
    if ($LASTEXITCODE -eq 0) {
      throw "$Label start.py empty-input smoke unexpectedly succeeded."
    }
    $jsonText = ($output -join "`n")
    try {
      $parsed = $jsonText | ConvertFrom-Json
    }
    catch {
      throw "$Label start.py empty-input smoke did not emit valid JSON: $($_.Exception.Message)"
    }
    if ($parsed.status -ne "error" -or $parsed.error -ne "missing_user_message") {
      throw "$Label start.py empty-input smoke returned unexpected payload: $jsonText"
    }
    if (Test-Path -LiteralPath $cacheDir) {
      throw "$Label start.py empty-input smoke created an execution cache."
    }
  }
  finally {
    if (Test-Path -LiteralPath $cacheDir) {
      Remove-Item -LiteralPath $cacheDir -Recurse -Force
    }
    Get-ChildItem -LiteralPath $EngineRoot -Recurse -Force -Directory -Filter "__pycache__" |
      Sort-Object FullName -Descending |
      ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
  }
}

function Invoke-StartPySplitArgSmoke([string]$Label, [string]$EngineRoot) {
  $startPy = Join-Path $EngineRoot "start.py"
  $engineDir = Join-Path $EngineRoot "soulbot_execute_engine_aiap"
  $cacheDir = Join-Path $engineDir ".execution_cache"
  $expected = "split argv smoke"
  try {
    Write-Host "==> $Label start.py split-argv smoke"
    $output = & python -B -X utf8 $startPy split argv smoke
    if ($LASTEXITCODE -ne 0) {
      throw "$Label start.py split-argv smoke failed with exit code $LASTEXITCODE"
    }
    $jsonText = ($output -join "`n")
    try {
      $parsed = $jsonText | ConvertFrom-Json
    }
    catch {
      throw "$Label start.py split-argv smoke did not emit valid JSON: $($_.Exception.Message)"
    }
    if ($parsed.status -ne "ok") {
      throw "$Label start.py split-argv smoke status is not ok: $($parsed.status)"
    }
    if ($parsed.user_message -ne $expected) {
      throw "$Label start.py split-argv smoke truncated or changed user_message. Expected '$expected', got '$($parsed.user_message)'"
    }
  }
  finally {
    if (Test-Path -LiteralPath $cacheDir) {
      Remove-Item -LiteralPath $cacheDir -Recurse -Force
    }
    Get-ChildItem -LiteralPath $EngineRoot -Recurse -Force -Directory -Filter "__pycache__" |
      Sort-Object FullName -Descending |
      ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
  }
}

function Invoke-StartPyRelativeSmoke([string]$Label, [string]$SkillRoot) {
  $relativeStartPy = Join-Path "soulagent" "start.py"
  $engineRoot = Join-Path $SkillRoot "soulagent"
  $engineDir = Join-Path $engineRoot "soulbot_execute_engine_aiap"
  $cacheDir = Join-Path $engineDir ".execution_cache"
  $expected = "relative bootstrap smoke"
  try {
    Write-Host "==> $Label relative start.py smoke"
    Push-Location $SkillRoot
    try {
      $output = & python -B -X utf8 $relativeStartPy $expected
    }
    finally {
      Pop-Location
    }
    if ($LASTEXITCODE -ne 0) {
      throw "$Label relative start.py smoke failed with exit code $LASTEXITCODE"
    }
    $jsonText = ($output -join "`n")
    try {
      $parsed = $jsonText | ConvertFrom-Json
    }
    catch {
      throw "$Label relative start.py smoke did not emit valid JSON: $($_.Exception.Message)"
    }
    if ($parsed.status -ne "ok") {
      throw "$Label relative start.py smoke status is not ok: $($parsed.status)"
    }
    if ($parsed.user_message -ne $expected) {
      throw "$Label relative start.py smoke changed user_message. Expected '$expected', got '$($parsed.user_message)'"
    }
    if (-not ($parsed.engine_dir -like "*\soulagent\soulbot_execute_engine_aiap")) {
      throw "$Label relative start.py smoke resolved unexpected engine_dir: $($parsed.engine_dir)"
    }
  }
  finally {
    if (Test-Path -LiteralPath $cacheDir) {
      Remove-Item -LiteralPath $cacheDir -Recurse -Force
    }
    Get-ChildItem -LiteralPath $engineRoot -Recurse -Force -Directory -Filter "__pycache__" |
      Sort-Object FullName -Descending |
      ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
  }
}

try {
  Push-Location $rootPath
  $pushedRootLocation = $true

  Invoke-Checked "Engine bundle drift check" {
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $rootPath "scripts\sync_plugin_engines.ps1") -Check
  }
  Invoke-Checked "Codex sync wrapper drift check" {
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $rootPath "scripts\sync_codex_plugin.ps1") -Check
  }
  Assert-EngineBundleSynced $sourceEnginePath (Join-Path $claudeSkillPath "soulagent") "Claude engine bundle"
  Assert-EngineBundleSynced $sourceEnginePath (Join-Path $codexSkillPath "soulagent") "Codex engine bundle"

  Assert-CodexPluginShape
  Assert-CodexSkillUiMetadata
  Assert-ClaudePluginMetadata
  Assert-GitRepositoryMetadata
  Assert-DistributionLicenseCopies
  Assert-AdapterTextBoundaries
  Assert-VersionConsistency
  Assert-ClaudeSkillShape
  Assert-HostNeutralSkillShape
  Assert-RepositoryPolicyFiles
  Assert-SyncScriptExclusions
  Assert-PackagingExampleExclusions
  Write-Host "==> Claude package archive smoke"
  Invoke-ClaudePackageStageSmoke
  Assert-AllJsonFilesParse
  Assert-AllYamlFilesParse
  Assert-PythonSyntax
  Assert-PowerShellSyntax
  Assert-MarkdownLocalLinks
  Assert-DocumentationHygiene
  Assert-ReadmeHeadingStructure
  Assert-LfLineEndings
  Assert-PrivacyAndSecrets
  Assert-StartProgramShape "Root engine" $sourceEnginePath
  Assert-StartProgramShape "Claude bundled engine" (Join-Path $claudeSkillPath "soulagent")
  Assert-StartProgramShape "Codex bundled engine" (Join-Path $codexSkillPath "soulagent")

  if (Test-Path -LiteralPath $skillValidator -PathType Leaf) {
    Invoke-Checked "Codex skill validation" {
      python -B -X utf8 $skillValidator $codexSkillPath
    }
  } else {
    Write-Host "Codex skill validator not found; skipping skill validation"
  }

  if (-not $SkipCodex) {
    Invoke-CodexMarketplaceSmoke
  }

  Invoke-StartPyEmptyInputSmoke "Root engine" $sourceEnginePath
  Invoke-StartPySplitArgSmoke "Root engine" $sourceEnginePath
  Invoke-StartPySmoke "Root engine" $sourceEnginePath
  Invoke-StartPyRelativeSmoke "Host-neutral skill" (Join-Path $rootPath "soulagent")
  if (-not $SkipClaude) {
    Invoke-StartPyEmptyInputSmoke "Claude bundled engine" (Join-Path $claudeSkillPath "soulagent")
    Invoke-StartPySplitArgSmoke "Claude bundled engine" (Join-Path $claudeSkillPath "soulagent")
    Invoke-StartPySmoke "Claude bundled engine" (Join-Path $claudeSkillPath "soulagent")
    Invoke-StartPyRelativeSmoke "Claude skill" $claudeSkillPath
  }
  if (-not $SkipCodex) {
    Invoke-StartPyEmptyInputSmoke "Codex bundled engine" (Join-Path $codexSkillPath "soulagent")
    Invoke-StartPySplitArgSmoke "Codex bundled engine" (Join-Path $codexSkillPath "soulagent")
    Invoke-StartPySmoke "Codex bundled engine" (Join-Path $codexSkillPath "soulagent")
    Invoke-StartPyRelativeSmoke "Codex skill" $codexSkillPath
  }

  if (-not $SkipClaude) {
    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if ($claude) {
      Invoke-Checked "Claude marketplace validation" { claude plugin validate $rootPath }
      Invoke-Checked "Claude plugin validation" { claude plugin validate $claudePluginPath }
    } else {
      if ($RequireHostCli) {
        throw "claude not found; -RequireHostCli requires Claude plugin validation to run."
      }
      Write-Host "claude not found; skipping Claude plugin validation"
    }
  }

  Remove-ReleaseTempRoot
  Assert-NoForbiddenRuntimeArtifacts
  Write-Host "SoulAgent release check passed."
}
finally {
  Remove-ReleaseTempRoot
  if ($releaseCheckMutexAcquired) {
    $releaseCheckMutex.ReleaseMutex()
  }
  $releaseCheckMutex.Dispose()
  if ($pushedRootLocation) {
    Pop-Location
  }
}
