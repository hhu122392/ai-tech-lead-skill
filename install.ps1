[CmdletBinding()]
param(
    [ValidateSet("User", "Project")]
    [string]$Scope = "User",

    [ValidateSet("Codex", "Claude", "Both")]
    [string]$Target = "Both",

    [string]$ProjectPath = (Get-Location).Path,

    [switch]$InstallAgentProfiles,

    [switch]$DryRun,

    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillSource = Join-Path $Root "ai-tech-lead"

if (-not (Test-Path (Join-Path $SkillSource "SKILL.md"))) {
    throw "Skill source not found: $SkillSource"
}

function Copy-DirectoryStrict {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if ($DryRun) {
        Write-Host "Would install: $Destination"
        return
    }

    $destinationExists = Test-Path -LiteralPath $Destination
    if ($destinationExists) {
        if (-not $Force) {
            throw "Destination already exists: $Destination. Re-run with -Force to replace it."
        }
    }

    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $stage = Join-Path $parent ('.ai-tech-lead-stage-' + [guid]::NewGuid().ToString('N'))
    $backup = $null
    try {
        Copy-Item -Recurse -Force $Source $stage
        if ($destinationExists) {
            $backup = $Destination + '.backup-' + (Get-Date -Format 'yyyyMMddHHmmss') + '-' + [guid]::NewGuid().ToString('N')
            Move-Item -LiteralPath $Destination -Destination $backup
        }
        Move-Item -LiteralPath $stage -Destination $Destination
    } catch {
        if (Test-Path -LiteralPath $stage) {
            Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
        }
        if ($backup -and (Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $Destination)) {
            Move-Item -LiteralPath $backup -Destination $Destination -ErrorAction SilentlyContinue
        }
        throw
    }
    Write-Host "Installed: $Destination"
    if ($backup) {
        Write-Host "Previous version backed up: $backup"
    }
}

function Copy-AgentFiles {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$DestinationDir
    )

    $sourceFiles = @(Get-ChildItem -File $SourceDir)
    $targets = @($sourceFiles | ForEach-Object { Join-Path $DestinationDir $_.Name })
    if (-not $DryRun) {
        $collisions = @($targets | Where-Object { (Test-Path -LiteralPath $_) -and (-not $Force) })
        if ($collisions.Count -gt 0) {
            throw "Agent profiles already exist: $($collisions -join ', '). Re-run with -Force to replace them."
        }
        New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null
    } else {
        Write-Host "Would install agent profiles: $DestinationDir"
        return
    }

    $parent = Split-Path -Parent $DestinationDir
    $stage = Join-Path $parent ('.ai-tech-lead-agents-stage-' + [guid]::NewGuid().ToString('N'))
    $backup = $null
    $movedTargets = @()
    $copiedTargets = @()
    try {
        New-Item -ItemType Directory -Force -Path $stage | Out-Null
        foreach ($source in $sourceFiles) {
            Copy-Item -Force $source.FullName (Join-Path $stage $source.Name)
        }
        if ($Force -and ($targets | Where-Object { Test-Path -LiteralPath $_ })) {
            $backup = $DestinationDir + '.backup-' + (Get-Date -Format 'yyyyMMddHHmmss') + '-' + [guid]::NewGuid().ToString('N')
            New-Item -ItemType Directory -Force -Path $backup | Out-Null
            foreach ($target in $targets) {
                if (Test-Path -LiteralPath $target) {
                    Move-Item -LiteralPath $target -Destination $backup
                    $movedTargets += $target
                }
            }
        }
        foreach ($source in $sourceFiles) {
            $staged = Join-Path $stage $source.Name
            $dest = Join-Path $DestinationDir $source.Name
            Move-Item -LiteralPath $staged -Destination $dest
            $copiedTargets += $dest
            Write-Host "Installed agent profile: $dest"
        }
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        foreach ($target in $copiedTargets) {
            Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        }
        if ($backup) {
            foreach ($target in $movedTargets) {
                $backupFile = Join-Path $backup ([IO.Path]::GetFileName($target))
                if (Test-Path -LiteralPath $backupFile) {
                    Move-Item -LiteralPath $backupFile -Destination $target -ErrorAction SilentlyContinue
                }
            }
        }
        if (Test-Path -LiteralPath $stage) {
            Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw
    }
    if ($backup) {
        Write-Host "Previous agent profiles backed up: $backup"
    }
}

function Assert-AgentDestinationFree {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$DestinationDir
    )

    $sourceFiles = @(Get-ChildItem -File $SourceDir)
    $collisions = @($sourceFiles | ForEach-Object {
        $target = Join-Path $DestinationDir $_.Name
        if (Test-Path -LiteralPath $target) { $target }
    })
    if ($collisions.Count -gt 0) {
        throw "Preflight failed; existing agent profiles: $($collisions -join ', '). No files were changed."
    }
}

if ($Scope -eq "Project") {
    $ProjectPath = (Resolve-Path $ProjectPath).Path
}

$installCodex = $Target -eq "Codex" -or $Target -eq "Both"
$installClaude = $Target -eq "Claude" -or $Target -eq "Both"

$skillDestinations = @()
if ($Scope -eq "User") {
    if ($installCodex) { $skillDestinations += Join-Path $HOME ".codex\skills\ai-tech-lead" }
    if ($installClaude) { $skillDestinations += Join-Path $HOME ".claude\skills\ai-tech-lead" }
} else {
    if ($installCodex) { $skillDestinations += Join-Path $ProjectPath ".codex\skills\ai-tech-lead" }
    if ($installClaude) { $skillDestinations += Join-Path $ProjectPath ".claude\skills\ai-tech-lead" }
}

if (-not $Force -and -not $DryRun) {
    $existingDestinations = @($skillDestinations | Where-Object { Test-Path -LiteralPath $_ })
    if ($existingDestinations.Count -gt 0) {
        throw "Preflight failed; existing skill destinations: $($existingDestinations -join ', '). No files were changed."
    }
    if ($InstallAgentProfiles) {
        if ($Scope -eq "User") {
            if ($installCodex) { Assert-AgentDestinationFree (Join-Path $Root "integrations\codex\agents") (Join-Path $HOME ".codex\agents") }
            if ($installClaude) { Assert-AgentDestinationFree (Join-Path $Root "integrations\claude-code\agents") (Join-Path $HOME ".claude\agents") }
        } else {
            if ($installCodex) { Assert-AgentDestinationFree (Join-Path $Root "integrations\codex\agents") (Join-Path $ProjectPath ".codex\agents") }
            if ($installClaude) { Assert-AgentDestinationFree (Join-Path $Root "integrations\claude-code\agents") (Join-Path $ProjectPath ".claude\agents") }
        }
    }
}

if ($Scope -eq "User") {
    if ($installCodex) {
        Copy-DirectoryStrict $SkillSource (Join-Path $HOME ".codex\skills\ai-tech-lead")
        if ($InstallAgentProfiles) {
            Copy-AgentFiles (Join-Path $Root "integrations\codex\agents") (Join-Path $HOME ".codex\agents")
        }
    }
    if ($installClaude) {
        Copy-DirectoryStrict $SkillSource (Join-Path $HOME ".claude\skills\ai-tech-lead")
        if ($InstallAgentProfiles) {
            Copy-AgentFiles (Join-Path $Root "integrations\claude-code\agents") (Join-Path $HOME ".claude\agents")
        }
    }
} else {
    if ($installCodex) {
        Copy-DirectoryStrict $SkillSource (Join-Path $ProjectPath ".codex\skills\ai-tech-lead")
        if ($InstallAgentProfiles) {
            Copy-AgentFiles (Join-Path $Root "integrations\codex\agents") (Join-Path $ProjectPath ".codex\agents")
        }
    }
    if ($installClaude) {
        Copy-DirectoryStrict $SkillSource (Join-Path $ProjectPath ".claude\skills\ai-tech-lead")
        if ($InstallAgentProfiles) {
            Copy-AgentFiles (Join-Path $Root "integrations\claude-code\agents") (Join-Path $ProjectPath ".claude\agents")
        }
    }
}

Write-Host ""
Write-Host "Installation complete. Restart Codex or Claude Code if the skill is not visible in the current session."
Write-Host "Use `$ai-tech-lead in Codex or /ai-tech-lead in Claude Code."
