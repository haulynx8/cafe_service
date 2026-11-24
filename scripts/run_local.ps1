if (-not (Test-Path '.env')) {
  Write-Error 'Missing .env. Copy .env.example to .env and add the project URL and publishable key.'
  exit 1
}

Get-Content '.env' | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
    [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
  }
}

flutter run -d "--dart-define=SUPABASE_URL=$env:SUPABASE_URL" "--dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY" @args
