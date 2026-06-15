#!/usr/bin/env bash
set -euo pipefail
set -a && source .env && set +a

if [[ -z "$REGISTRY_PASSWORD" ]]; then
  echo "ERROR: Set REGISTRY_PASSWORD before running this script."
  echo "  export REGISTRY_PASSWORD='your-secure-password'"
  exit 1
fi

echo "==> Creating htpasswd credentials for user: $REGISTRY_USERNAME"
docker run --rm \
  httpd:alpine \
  htpasswd -Bbn "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD" > infra/registry/auth/htpasswd

chmod 600 infra/registry/auth/htpasswd

echo ""
echo "==> Setup complete. Start the registry with:"
echo "    docker compose up -d"
echo ""
echo "==> Push an image:"
echo "    docker login $REGISTRY_DOMAIN:5000 -u $REGISTRY_USERNAME"
echo "    docker tag myimage $REGISTRY_DOMAIN:5000/myimage:latest"
echo "    docker push $REGISTRY_DOMAIN:5000/myimage:latest"