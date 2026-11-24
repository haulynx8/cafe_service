#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .env ]]; then
  echo 'Missing .env. Copy .env.example to .env and add the project URL and publishable key.'
  exit 1
fi

set -a
source .env
set +a

flutter run -d linux\
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY" \
  "$@"
