#!/bin/bash
set -e

echo "Starting Sonic Atlas in development mode..."

if [ ! -f .env ]; then
    echo ".env file not found. Copying from .env.example..."
    cp .env.example .env
    echo "Created .env - please edit it with your settings"
    exit 1
fi

mkdir -p storage/{originals,cache,metadata}

# Todo add --build option to force rebuilds

docker compose -f docker-compose.dev.yml up

echo "Sonic Atlas is running!"
echo "Web: http://localhost:5173"
echo "API: http://localhost:3000"
echo "Transcoder: http://localhost:8000"