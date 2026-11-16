<#
.SYNOPSIS
  Puts the current commit of the API on the server and (re)starts it.

.DESCRIPTION
  Packs the committed api/ folder with `git archive` (so .env is never
  included), copies it over SSH into ~/brainwake and runs
  `docker compose up -d --build` there. The API runs beside JARVIS on the
  same server but in its own container; JARVIS's Caddy forwards
  https://<server name>/brainwake/... to it.

  -WithEnv   also upload api\.env (first deploy, or after changing a key)

.EXAMPLE
  .\deploy\push.ps1 -Server 68.210.230.92 -WithEnv     # first time
  .\deploy\push.ps1 -Server 68.210.230.92              # later updates
#>
param(
    [Parameter(Mandatory = $true)][string]$Server,
    [string]$User = "azureuser",
    [string]$Key = "$HOME\.ssh\jarvis-server.key",
    [switch]$WithEnv
)
$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Target = "$User@$Server"
$Ssh = @("-i", $Key, "-o", "StrictHostKeyChecking=accept-new")

Push-Location $Repo
try {
    if (git status --porcelain) {
        Write-Warning "You have uncommitted changes; only committed code is deployed."
    }
    $archive = Join-Path $env:TEMP "brainwake-deploy.tar.gz"
    git archive --format=tar.gz -o $archive HEAD api
    if ($LASTEXITCODE -ne 0) { throw "git archive failed" }

    Write-Host "Uploading code to $Target ..."
    scp @Ssh $archive "${Target}:brainwake-deploy.tar.gz"
    # Remote commands contain no double quotes: PowerShell 5 mangles them.
    ssh @Ssh $Target "mkdir -p ~/brainwake && tar -xzf ~/brainwake-deploy.tar.gz -C ~/brainwake && rm ~/brainwake-deploy.tar.gz"

    if ($WithEnv) {
        $envFile = Join-Path $Repo "api\.env"
        if (-not (Test-Path $envFile)) { throw "api\.env does not exist. Copy api\.env.example to api\.env and fill it in." }
        Write-Host "Uploading .env ..."
        scp @Ssh $envFile "${Target}:brainwake/api/.env"
        # Strip Windows line endings and a byte-order mark, which would corrupt the first setting.
        ssh @Ssh $Target "sed -i -e 's/\r$//' -e '1s/^\xEF\xBB\xBF//' ~/brainwake/api/.env && chmod 600 ~/brainwake/api/.env"
    }

    Write-Host "Building and starting the API ..."
    # 2>&1 on the remote side: docker prints progress on stderr, which PowerShell 5 treats as an error.
    ssh @Ssh $Target "test -f ~/brainwake/api/.env || { echo MISSING: run again with -WithEnv; exit 1; }; (docker network inspect web > /dev/null 2>&1 || docker network create web) && cd ~/brainwake/api && docker compose up -d --build 2>&1 && sleep 5 && docker compose ps"
    Write-Host "Check: open https://<your server name>/brainwake/health in a browser; it should show ok: true."
}
finally {
    Pop-Location
}
