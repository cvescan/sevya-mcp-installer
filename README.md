# Sevya MCP Installer (public)

Installation en 1 ligne :

curl -fsSL https://raw.githubusercontent.com/cvescan/sevya-mcp-installer/main/scripts/install-sevya-mcp.sh | bash

## Scripts inclus
- scripts/install-sevya-mcp.sh
- scripts/add-sevya-mcp-account.sh (optionnel)

## Inclus dans l'installation
- Serveur MCP local (STDIO) pour Claude Desktop
- Outils: get_opportunities, get_clients, get_purchases, get_current_date
- Support tracking marketing dans les opportunités:
  - 📊 UTM: utm_source, utm_medium, utm_campaign, utm_term, utm_content, utm_id
  - 🔗 GCLID et 📘 FBCLID
  - 🌐 URL source (page_url/landing_url)
  - 📝 form_id

Après installation, ajoutez votre clé API dans la config Claude Desktop (SEVYA_API_KEY) et redémarrez l'application.
