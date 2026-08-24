$ErrorActionPreference = "Stop"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker Desktop is required. Install Docker Desktop, start it, then run this script again."
}

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example. Replace ADMIN_API_TOKEN before sharing this environment."
}

docker compose up --build