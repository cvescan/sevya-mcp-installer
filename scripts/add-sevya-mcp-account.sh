#!/bin/bash

# add-sevya-mcp-account.sh
#
# Ajoute un nouveau serveur MCP Sevya dans la configuration de Claude Desktop,
# permettant d'utiliser plusieurs comptes (plusieurs clés API) en parallèle.
#
# Usage:
#   scripts/add-sevya-mcp-account.sh --name sevya-crm-clientA --api-key sk_live_xxx \
#     [--api-base https://.../functions/v1] [--binary /chemin/vers/build/index.js]
#
# Par défaut, le binaire pointe sur ~/Documents/sevya-mcp-server/build/index.js

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAME=""
API_KEY=""
API_BASE="https://tceelmvnduayksvnciwx.supabase.co/functions/v1"
BINARY_DEFAULT="${HOME}/Documents/sevya-mcp-server/build/index.js"
BINARY_PATH="${BINARY_DEFAULT}"

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --name)
      NAME="${2:-}"
      shift 2
      ;;
    --api-key)
      API_KEY="${2:-}"
      shift 2
      ;;
    --api-base)
      API_BASE="${2:-}"
      shift 2
      ;;
    --binary)
      BINARY_PATH="${2:-}"
      shift 2
      ;;
    *)
      echo -e "${YELLOW}ℹ️  Option inconnue ignorée: $1${NC}"
      shift 1
      ;;
  esac
done

if [[ -z "${NAME}" ]]; then
  echo -e "${RED}❌ --name est requis (ex: --name sevya-crm-clientA).${NC}"
  exit 1
fi

if [[ -z "${API_KEY}" ]] || [[ "${API_KEY}" != sk_live_* ]]; then
  echo -e "${RED}❌ --api-key est requis et doit commencer par 'sk_live_'.${NC}"
  exit 1
fi

if [[ ! -f "${BINARY_PATH}" ]]; then
  echo -e "${RED}❌ Binaire introuvable: ${BINARY_PATH}${NC}"
  echo -e "${YELLOW}ℹ️  (Recompilez via scripts/install-sevya-mcp.sh ou précisez --binary)${NC}"
  exit 1
fi

CLAUDE_CONFIG_DIR="${HOME}/Library/Application Support/Claude"
CLAUDE_CONFIG_FILE="${CLAUDE_CONFIG_DIR}/claude_desktop_config.json"

mkdir -p "${CLAUDE_CONFIG_DIR}"

echo -e "${BLUE}🛠️  Ajout du serveur MCP '${NAME}' dans la configuration Claude...${NC}"

# Sauvegarde
BACKUP_CREATED=false
if [ -f "${CLAUDE_CONFIG_FILE}" ]; then
  cp "${CLAUDE_CONFIG_FILE}" "${CLAUDE_CONFIG_FILE}.backup"
  BACKUP_CREATED=true
fi

node << NODE
const fs = require('fs');
const path = ${JSON.stringify("${CLAUDE_CONFIG_FILE}")};
let obj = {};
try { obj = JSON.parse(fs.readFileSync(path, 'utf8')); } catch {}
if (typeof obj !== 'object' || obj === null) obj = {};
if (!obj.mcpServers || typeof obj.mcpServers !== 'object') obj.mcpServers = {};

obj.mcpServers[${JSON.stringify(NAME)}] = {
  command: 'node',
  args: [${JSON.stringify("${BINARY_PATH}")}],
  env: {
    SEVYA_API_KEY: ${JSON.stringify("${API_KEY}")},
    SEVYA_API_BASE: ${JSON.stringify("${API_BASE}")},
    // Optionnel, si le serveur supporte un nom de profil dynamique
    SEVYA_PROFILE_NAME: ${JSON.stringify(NAME)}
  }
};

fs.writeFileSync(path, JSON.stringify(obj, null, 2));
console.log('OK');
NODE

# Validation JSON
if ! python3 -m json.tool "${CLAUDE_CONFIG_FILE}" > /dev/null 2>&1; then
  echo -e "${RED}❌ Erreur d'écriture du JSON de configuration Claude.${NC}"
  if [ "$BACKUP_CREATED" = true ]; then
    echo -e "${YELLOW}🔄 Restauration de la sauvegarde...${NC}"
    cp "${CLAUDE_CONFIG_FILE}.backup" "${CLAUDE_CONFIG_FILE}"
  fi
  exit 1
fi

echo -e "${GREEN}✅ Serveur MCP '${NAME}' ajouté. Redémarrez Claude Desktop.${NC}"

