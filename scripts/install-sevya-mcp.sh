#!/bin/bash

# Script d'installation automatique du serveur MCP Sevya CRM
# Version: 1.2.0 - Support UTM, form_id et outil get_current_date
# Usage:
#   ./install-sevya-mcp.sh
# Remarque: la clé API est ajoutée manuellement dans le fichier Claude.

set -euo pipefail

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Installation automatique du serveur MCP Sevya CRM${NC}"
echo "=================================================="

# Aucun argument requis

USERNAME=$(whoami)
echo -e "${YELLOW}📋 Utilisateur détecté: ${USERNAME}${NC}"

# Chemins
# Chemins (macOS)
DOCUMENTS_DIR="${HOME}/Documents"
MCP_DIR="${DOCUMENTS_DIR}/sevya-mcp-server"
CLAUDE_CONFIG_DIR="${HOME}/Library/Application Support/Claude"
CLAUDE_CONFIG_FILE="${CLAUDE_CONFIG_DIR}/claude_desktop_config.json"

echo -e "${YELLOW}📁 Dossier d'installation: ${MCP_DIR}${NC}"

# Vérifier si Node.js est installé
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js n'est pas installé. Veuillez installer Node.js d'abord.${NC}"
    echo "Téléchargez depuis: https://nodejs.org/"
    exit 1
fi

echo -e "${GREEN}✅ Node.js détecté: $(node --version)${NC}"

# Vérifier si npm est installé
if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm n'est pas installé.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ npm détecté: $(npm --version)${NC}"

# Vérifier la version de Node (>=18)
REQUIRED_NODE_MAJOR=18
NODE_VERSION_RAW=$(node -v | sed 's/^v//')
NODE_MAJOR=$(echo "$NODE_VERSION_RAW" | cut -d. -f1)
if [ "$NODE_MAJOR" -lt "$REQUIRED_NODE_MAJOR" ]; then
  echo -e "${RED}❌ Node.js >= 18 requis (trouvé v${NODE_VERSION_RAW}).${NC}"
  exit 1
fi

# Créer le dossier d'installation
echo -e "${BLUE}📂 Création du dossier d'installation...${NC}"
mkdir -p "${MCP_DIR}"
cd "${MCP_DIR}"

# Initialiser le projet npm
echo -e "${BLUE}📦 Initialisation du projet npm...${NC}"
npm init -y

# Mettre à jour package.json
cat > package.json << 'EOF'
{
  "name": "sevya-mcp-server",
  "version": "1.0.0",
  "description": "MCP Server pour Sevya CRM",
  "main": "build/index.js",
  "type": "module",
  "bin": {
    "sevya-mcp": "./build/index.js"
  },
  "scripts": {
    "build": "tsc && chmod 755 build/index.js",
    "start": "node build/index.js"
  },
  "keywords": ["mcp", "crm", "sevya"],
  "author": "Sevya Team",
  "license": "ISC",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "zod": "^3.22.4"
  },
  "devDependencies": {
    "@types/node": "^20.19.11",
    "typescript": "^5.9.2"
  },
  "files": ["build"]
}
EOF

# Installer les dépendances
echo -e "${BLUE}📦 Installation des dépendances...${NC}"
npm install @modelcontextprotocol/sdk zod@3
npm install -D @types/node typescript

# Créer tsconfig.json
echo -e "${BLUE}⚙️ Configuration TypeScript...${NC}"
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "lib": ["ES2022", "DOM"],
    "outDir": "./build",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}
EOF

# Créer le dossier src
mkdir -p src

# Créer le serveur MCP
echo -e "${BLUE}🔧 Création du serveur MCP...${NC}"
cat > src/index.ts << 'EOF'
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const SEVYA_API_BASE = process.env.SEVYA_API_BASE || "https://tceelmvnduayksvnciwx.supabase.co/functions/v1";
const API_KEY = process.env.SEVYA_API_KEY || "";
const SERVER_NAME = process.env.SEVYA_PROFILE_NAME || "sevya-crm";
const ENABLE_WRITES = process.env.SEVYA_ENABLE_WRITES === '1';

// Create server instance
const server = new McpServer({
  name: SERVER_NAME,
  version: "1.0.0",
  capabilities: {
    resources: {},
    tools: {},
  },
});

// --- Rate limiting (simple, en mémoire) ---
const RATE_LIMIT_MAX = 3;
const RATE_LIMIT_WINDOW_MS = 2000; // 2 secondes
const callsHistory = new Map<string, number[]>();

function checkRateLimit(tool: string): boolean {
  const now = Date.now();
  const arr = callsHistory.get(tool) || [];
  const fresh = arr.filter((t) => now - t < RATE_LIMIT_WINDOW_MS);
  if (fresh.length >= RATE_LIMIT_MAX) return false;
  fresh.push(now);
  callsHistory.set(tool, fresh);
  return true;
}

// --- Schémas Zod pour valider les réponses ---
const OpportunitySchema = z.object({
  name: z.string().optional(),
  status: z.string().optional(),
  estimated_amount: z.union([z.number(), z.string()]).optional(),
  client_id: z.union([z.number(), z.string()]).optional(),
  notes: z.string().optional().nullable(),
  source: z.string().optional().nullable(),
  created_at: z.string().optional().nullable(),
  utm: z.record(z.any()).optional().nullable(),
  form_id: z.string().optional().nullable(),
}).passthrough();

const ClientSchema = z.object({
  name: z.string().optional(),
  first_name: z.string().optional().nullable(),
  email: z.string().optional().nullable(),
  phone: z.string().optional().nullable(),
  status: z.string().optional().nullable(),
  created_at: z.string().optional().nullable(),
}).passthrough();

const PurchaseClientUnion = z.union([ClientSchema, z.array(ClientSchema)]).optional();
const PurchaseSchema = z.object({
  id: z.union([z.number(), z.string()]).optional(),
  order_number: z.string().optional().nullable(),
  total_amount: z.union([z.number(), z.string()]).optional(),
  currency_code: z.string().optional().nullable(),
  status: z.string().optional().nullable(),
  clients: PurchaseClientUnion,
  opportunity_id: z.union([z.number(), z.string()]).optional().nullable(),
  date: z.string().optional().nullable(),
  created_at: z.string().optional().nullable(),
}).passthrough();

const OpportunitiesResponse = z.object({ opportunities: z.array(OpportunitySchema).default([]) });
const ClientsResponse = z.object({ clients: z.array(ClientSchema).default([]) });
const PurchasesResponse = z.object({ purchases: z.array(PurchaseSchema).default([]) });

// --- Utilitaires / journalisation ---
function parseDate(v?: string | null): Date | null {
  if (!v) return null;
  const d = new Date(v);
  return isNaN(d.getTime()) ? null : d;
}

let LAST_ERROR_CODE: string | null = null;

function buildError(code: string, text: string) {
  LAST_ERROR_CODE = code;
  console.error(`[MCP][${code}] ${text}`);
  return { content: [{ type: "text", text: `Erreur (${code}) : ${text}` }] } as const;
}

// Helper function for making Sevya API requests (with timeout + robust errors)
async function makeSevyaRequest<T>(endpoint: string, method: string = "GET", data?: any, extraHeaders?: Record<string,string>): Promise<T | null> {
  if (!API_KEY) {
    console.error("SEVYA_API_KEY manquante. Définissez-la dans la config Claude.");
    return null as any;
  }

  const headers: Record<string,string> = {
    "Authorization": `ApiKey ${API_KEY}`,
    "Content-Type": "application/json",
  };
  if (extraHeaders) {
    for (const [k,v] of Object.entries(extraHeaders)) headers[k] = v;
  }

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    const options: RequestInit = {
      method,
      headers,
      signal: controller.signal,
    };

    if (data) {
      options.body = JSON.stringify(data);
    }
    const response = await fetch(`${SEVYA_API_BASE}${endpoint}`, options);
    clearTimeout(timeout);
    
    if (!response.ok) {
      if (response.status === 401) {
        LAST_ERROR_CODE = 'S2';
        console.error(`[MCP][S2] 401 Unauthorized`);
      } else {
        LAST_ERROR_CODE = 'S3';
        console.error(`[MCP][S3] HTTP error ${response.status}`);
      }
      return null;
    }
    
    LAST_ERROR_CODE = null;
    return (await response.json()) as T;
  } catch (error: any) {
    if (error && (error.name === 'AbortError' || error.code === 'ABORT_ERR')) {
      LAST_ERROR_CODE = 'S1';
      console.error('[MCP][S1] network timeout');
    } else {
      LAST_ERROR_CODE = 'S5';
      console.error('[MCP][S5] network error', error);
    }
    return null;
  }
}

// Register CRM tools
server.tool(
  "get_current_date",
  "Retourne la date et l'heure actuelles du système",
  {},
  async () => {
    const now = new Date();
    const formatted = now.toLocaleString('fr-FR', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      timeZoneName: 'short'
    });
    const iso = now.toISOString();

    return {
      content: [{
        type: "text",
        text: `📅 Date actuelle: ${formatted}\n🕐 ISO: ${iso}\n📆 Année: ${now.getFullYear()}`
      }]
    } as const;
  },
);

server.tool(
  "get_opportunities",
  "Récupère les opportunités commerciales (données masquées)",
  {
    limit: z.number().optional().describe("Nombre max d'opportunités à récupérer"),
    offset: z.number().optional().describe("Décalage de départ (pagination)"),
    status: z.string().optional().describe("Filtrer par statut"),
    from_date: z.string().optional().describe("Filtrer à partir de cette date (ISO)"),
    to_date: z.string().optional().describe("Filtrer jusqu'à cette date (ISO)"),
  },
  async ({ limit, offset, status, from_date, to_date }): Promise<any> => {
    if (!checkRateLimit("get_opportunities")) {
      return buildError('S6', "Trop d'appels rapprochés. Réessayez dans quelques secondes.");
    }
    const opportunities = await makeSevyaRequest<any>("/opportunities");
    
    if (!opportunities) {
      return buildError(LAST_ERROR_CODE || 'S3', "Impossible de récupérer les opportunités. Vérifiez votre connexion.");
    }
    const parsed = OpportunitiesResponse.safeParse(opportunities);
    if (!parsed.success) {
      return buildError('S4', "Réponse inattendue du serveur pour les opportunités.");
    }
    const from = parseDate(from_date ?? undefined);
    const to = parseDate(to_date ?? undefined);
    const normalizedStatus = status ? String(status).toLowerCase() : null;
    let list = parsed.data.opportunities.filter((o) => {
      const okStatus = normalizedStatus ? String(o.status || '').toLowerCase() === normalizedStatus : true;
      const d = parseDate(o.created_at || undefined);
      const okFrom = from ? (d ? d >= from : false) : true;
      const okTo = to ? (d ? d <= to : false) : true;
      return okStatus && okFrom && okTo;
    });
    const total = list.length;
    const byStatus: Record<string, number> = {};
    for (const o of list) {
      const s = (o.status || 'inconnu').toString();
      byStatus[s] = (byStatus[s] || 0) + 1;
    }
    if (typeof offset === 'number' && offset > 0) list = list.slice(offset);
    const limitedList = typeof limit === 'number' ? list.slice(0, limit) : list;
    
    const formattedOpportunities = limitedList.map((opp: any) => {
      let formatted = `Opportunité: ${opp.name ?? "—"}\nStatut: ${opp.status ?? "—"}\nMontant estimé: ${opp.estimated_amount ?? "—"}€\nClient: ${opp.client_id ?? "—"}`;
      
      // Ajouter les notes si présentes
      if (opp.notes && String(opp.notes).trim()) {
        formatted += `\nNotes: ${opp.notes}`;
      }
      
      // Ajouter la source si présente
      if (opp.source) {
        formatted += `\nSource: ${opp.source}`;
      }
      
      // Ajouter la date de création
      if (opp.created_at) {
        const date = new Date(opp.created_at).toLocaleDateString('fr-FR');
        formatted += `\nCréée le: ${date}`;
      }

      // Ajouter les paramètres UTM si présents
      if (opp.utm && typeof opp.utm === 'object') {
        const utmEntries = Object.entries(opp.utm)
          .filter(([key, value]) => value && key.startsWith('utm_'))
          .map(([key, value]) => `${key.replace('utm_', '').toUpperCase()}: ${value}`);

        if (utmEntries.length > 0) {
          formatted += `\n📊 UTM: ${utmEntries.join(', ')}`;
        }

        // Ajouter d'autres paramètres de tracking
        if (opp.utm.gclid) formatted += `\n🔗 GCLID: ${opp.utm.gclid}`;
        if (opp.utm.fbclid) formatted += `\n📘 FBCLID: ${opp.utm.fbclid}`;
        if (opp.utm.page_url) formatted += `\n🌐 URL source: ${opp.utm.page_url}`;
      }

      // Ajouter l'ID du formulaire si présent
      if (opp.form_id) {
        formatted += `\n📝 ID Formulaire: ${opp.form_id}`;
      }

      return formatted + '\n---';
    }).join("\n");

    const header = `Résumé: total=${total}${normalizedStatus ? `, statut=${normalizedStatus}` : ''}${from_date ? `, depuis=${from_date}` : ''}${to_date ? `, jusqu'au=${to_date}` : ''}\nPar statut: ${JSON.stringify(byStatus)}`;
    return { content: [{ type: "text", text: `${header}\n\n${formattedOpportunities}` }] } as const;
  },
);

server.tool(
  "get_clients",
  "Récupère les clients (données masquées)",
  {
    limit: z.number().optional().describe("Nombre max de clients à récupérer"),
    offset: z.number().optional().describe("Décalage de départ (pagination)"),
    status: z.string().optional().describe("Filtrer par statut"),
    from_date: z.string().optional().describe("Créés après cette date (ISO)"),
    to_date: z.string().optional().describe("Créés avant cette date (ISO)"),
    inactive_label: z.string().optional().describe("Libellé statut considéré comme inactif (par défaut: inactive/inactif)"),
  },
  async ({ limit, offset, status, from_date, to_date, inactive_label }): Promise<any> => {
    if (!checkRateLimit("get_clients")) {
      return buildError('S6', "Trop d'appels rapprochés. Réessayez dans quelques secondes.");
    }
    const clients = await makeSevyaRequest<any>("/clients");
    
    if (!clients) {
      return buildError(LAST_ERROR_CODE || 'S3', "Impossible de récupérer les clients. Vérifiez votre connexion.");
    }
    const parsed = ClientsResponse.safeParse(clients);
    if (!parsed.success) {
      return buildError('S4', "Réponse inattendue du serveur pour les clients.");
    }
    const from = parseDate(from_date ?? undefined);
    const to = parseDate(to_date ?? undefined);
    const normalizedStatus = status ? String(status).toLowerCase() : null;
    let list = parsed.data.clients.filter((c) => {
      const okStatus = normalizedStatus ? String(c.status || '').toLowerCase() === normalizedStatus : true;
      const d = parseDate(c.created_at || undefined);
      const okFrom = from ? (d ? d >= from : false) : true;
      const okTo = to ? (d ? d <= to : false) : true;
      return okStatus && okFrom && okTo;
    });
    const total = list.length;
    const byStatus: Record<string, number> = {};
    for (const c of list) {
      const s = (c.status || 'inconnu').toString();
      byStatus[s] = (byStatus[s] || 0) + 1;
    }
    const inactiveRegex = new RegExp(inactive_label || '(?:inactive|inactif)s?','i');
    const inactiveCount = list.filter((c) => inactiveRegex.test(String(c.status || ''))).length;
    if (typeof offset === 'number' && offset > 0) list = list.slice(offset);
    const limitedList = typeof limit === 'number' ? list.slice(0, limit) : list;
    
    const formattedClients = limitedList.map((client: any) => {
      let formatted = `Client: ${client.name ?? "—"}`;
      
      // Ajouter le prénom si présent
      if (client.first_name) {
        formatted += ` ${client.first_name}`;
      }
      
      formatted += `\nEmail: ${client.email ?? "—"}\nTéléphone: ${client.phone ?? "—"}`;
      
      // Ajouter le statut si présent
      if (client.status) {
        formatted += `\nStatut: ${client.status}`;
      }
      
      // Ajouter la date de création
      if (client.created_at) {
        const date = new Date(client.created_at).toLocaleDateString('fr-FR');
        formatted += `\nCréé le: ${date}`;
      }
      
      return formatted + '\n---';
    }).join("\n");

    const header = `Résumé: total=${total}${normalizedStatus ? `, statut=${normalizedStatus}` : ''}${from_date ? `, depuis=${from_date}` : ''}${to_date ? `, jusqu'au=${to_date}` : ''} | Inactifs (statut): ${inactiveCount}\nPar statut: ${JSON.stringify(byStatus)}`;
    return { content: [{ type: "text", text: `${header}\n\n${formattedClients}` }] } as const;
  },
);

server.tool(
  "get_purchases",
  "Récupère les ventes/achats (données masquées)",
  {
    limit: z.number().optional().describe("Nombre max de ventes à récupérer"),
    offset: z.number().optional().describe("Décalage de départ (pagination)"),
    status: z.string().optional().describe("Filtrer par statut"),
    from_date: z.string().optional().describe("Filtrer à partir de cette date (ISO)"),
    to_date: z.string().optional().describe("Filtrer jusqu'à cette date (ISO)"),
  },
  async ({ limit, offset, status, from_date, to_date }): Promise<any> => {
    if (!checkRateLimit("get_purchases")) {
      return { content: [{ type: "text", text: "Erreur (S6) : Trop d'appels rapprochés. Réessayez dans quelques secondes." }] } as const;
    }
    const purchases = await makeSevyaRequest<any>("/purchases");
    
    if (!purchases) {
      return { content: [{ type: "text", text: `Erreur (${LAST_ERROR_CODE || 'S3'}) : Impossible de récupérer les ventes. Vérifiez votre connexion.` }] } as const;
    }
    const parsed = PurchasesResponse.safeParse(purchases);
    if (!parsed.success) {
      return { content: [{ type: "text", text: "Erreur (S4) : Réponse inattendue du serveur pour les ventes." }] } as const;
    }
    const from = parseDate(from_date ?? undefined);
    const to = parseDate(to_date ?? undefined);
    const normalizedStatus = status ? String(status).toLowerCase() : null;
    let list = parsed.data.purchases.filter((p) => {
      const okStatus = normalizedStatus ? String(p.status || '').toLowerCase() === normalizedStatus : true;
      // Utiliser la date de vente si disponible, sinon la date de création
      const d = parseDate(p.date || p.created_at || undefined);
      const okFrom = from ? (d ? d >= from : false) : true;
      const okTo = to ? (d ? d <= to : false) : true;
      return okStatus && okFrom && okTo;
    });
    const total = list.length;
    const byStatus: Record<string, number> = {};
    for (const p2 of list) {
      const s2 = (p2.status || 'inconnu').toString();
      byStatus[s2] = (byStatus[s2] || 0) + 1;
    }
    if (typeof offset === 'number' && offset > 0) list = list.slice(offset);
    const limitedList = typeof limit === 'number' ? list.slice(0, limit) : list;
    
    const formattedPurchases = limitedList.map((purchase: any) => {
      let formatted = `Vente: ${purchase.order_number || purchase.id || "—"}\nMontant: ${purchase.total_amount ?? "—"}${purchase.currency_code || '€'}\nStatut: ${purchase.status ?? "—"}`;
      
      // Ajouter le client si présent
      if (purchase.clients) {
        const client = Array.isArray(purchase.clients) ? purchase.clients[0] : purchase.clients;
        if (client) {
          formatted += `\nClient: ${client.name ?? "—"}`;
          if (client.first_name) {
            formatted += ` ${client.first_name}`;
          }
          formatted += `\nEmail client: ${client.email ?? "—"}`;
        }
      }
      
      // Ajouter l'opportunité liée si présente
      if (purchase.opportunity_id) {
        formatted += `\nOpportunité liée: ${purchase.opportunity_id}`;
      }
      
      // Ajouter la date de vente (préférée) ou à défaut la date de création
      if (purchase.date || purchase.created_at) {
        const baseDate = purchase.date || purchase.created_at;
        const date = new Date(baseDate).toLocaleDateString('fr-FR');
        const label = purchase.date ? 'Réalisée le' : 'Créée le';
        formatted += `\n${label}: ${date}`;
      }
      
      return formatted + '\n---';
    }).join("\n");

    const header = `Résumé: total=${total}${normalizedStatus ? `, statut=${normalizedStatus}` : ''}${from_date ? `, depuis=${from_date}` : ''}${to_date ? `, jusqu'au=${to_date}` : ''}\nPar statut: ${JSON.stringify(byStatus)}`;
    return { content: [{ type: "text", text: `${header}\n\n${formattedPurchases}` }] } as const;
  },
);

// --- Outils d'écriture (opt-in) ---
const pendingTokens = new Map<string, any>();
function newToken() {
  try { return crypto.randomUUID(); } catch { return Math.random().toString(36).slice(2) + Date.now(); }
}

server.tool(
  "create_client",
  "Crée un client (contact) dans Sevya (écriture protégée)",
  {
    name: z.string().min(1).describe("Nom du client (entreprise ou personne)"),
    first_name: z.string().optional().describe("Prénom (si personne)"),
    email: z.string().email().optional().describe("Email (optionnel)"),
    phone: z.string().optional().describe("Téléphone (optionnel)"),
    status: z.string().optional().describe("Statut client (ex: actif, inactif)"),
    notes: z.string().optional().describe("Notes internes (max ~2000)"),
    confirm: z.boolean().optional().default(false).describe("Confirmer la création (2-temps)"),
    confirm_token: z.string().optional().describe("Jeton obtenu lors de l'étape 1"),
    idempotency_key: z.string().min(8).optional().describe("Clé d'idempotence pour éviter les doublons"),
  },
  async ({ name, first_name, email, phone, status, notes, confirm, confirm_token, idempotency_key }): Promise<any> => {
    if (!ENABLE_WRITES) {
      return buildError('W0', "Écritures désactivées (SEVYA_ENABLE_WRITES != '1').");
    }
    // Étape 1: prévisualisation
    const payload = { name, first_name, email, phone, status, notes } as any;
    if (!confirm) {
      const token = newToken();
      pendingTokens.set(token, payload);
      const preview = `Prévisualisation création client:\n- Nom: ${name}\n- Prénom: ${first_name ?? '—'}\n- Email: ${email ?? '—'}\n- Téléphone: ${phone ?? '—'}\n- Statut: ${status ?? '—'}\n- Notes: ${notes ? (String(notes).slice(0,140)+'…') : '—'}\n\nPour confirmer: relancez avec { confirm: true, confirm_token: "${token}" }`;
      return { content: [{ type: "text", text: preview }] } as const;
    }
    // Étape 2: confirmation
    const finalPayload = confirm_token && pendingTokens.get(confirm_token) ? pendingTokens.get(confirm_token) : payload;
    const headers: Record<string,string> = {};
    if (idempotency_key) headers['X-Idempotency-Key'] = idempotency_key;
    const created = await makeSevyaRequest<any>("/clients", "POST", finalPayload, headers);
    if (!created) {
      return buildError(LAST_ERROR_CODE || 'W5', "Échec création client (réseau/HTTP).");
    }
    if (confirm_token) pendingTokens.delete(confirm_token);
    const summary = `Client créé avec succès.\nID: ${created.id ?? 'inconnu'}\nNom: ${finalPayload.name}`;
    return { content: [{ type: "text", text: summary }] } as const;
  },
);

server.tool(
  "create_opportunity",
  "Crée une opportunité dans Sevya (écriture protégée)",
  {
    name: z.string().min(3).describe("Nom de l'opportunité"),
    client_id: z.union([z.string(), z.number()]).optional().describe("ID client existant (sinon fournir contact)"),
    contact: z.object({ full_name: z.string().optional(), email: z.string().email().optional(), phone: z.string().optional() }).optional(),
    estimated_amount: z.union([z.number(), z.string()]).optional().describe("Montant estimé"),
    status: z.string().optional().describe("Statut initial (ex: nouveau)"),
    source: z.string().optional().describe("Source (ex: Site web)"),
    notes: z.string().optional().describe("Notes internes (max ~2000)"),
    confirm: z.boolean().optional().default(false).describe("Confirmer la création (2-temps)"),
    confirm_token: z.string().optional().describe("Jeton obtenu lors de l'étape 1"),
    idempotency_key: z.string().min(8).optional().describe("Clé d'idempotence pour éviter les doublons"),
  },
  async ({ name, client_id, contact, estimated_amount, status, source, notes, confirm, confirm_token, idempotency_key }): Promise<any> => {
    if (!ENABLE_WRITES) {
      return buildError('W0', "Écritures désactivées (SEVYA_ENABLE_WRITES != '1').");
    }
    const payload: any = { name, client_id, estimated_amount, status, source, notes };
    if (contact) payload.contact = contact;
    if (!confirm) {
      const token = newToken();
      pendingTokens.set(token, payload);
      const preview = `Prévisualisation création opportunité:\n- Nom: ${name}\n- Client ID: ${client_id ?? '—'}\n- Contact: ${contact ? JSON.stringify(contact) : '—'}\n- Montant estimé: ${estimated_amount ?? '—'}\n- Statut: ${status ?? '—'}\n- Source: ${source ?? '—'}\n- Notes: ${notes ? (String(notes).slice(0,140)+'…') : '—'}\n\nPour confirmer: relancez avec { confirm: true, confirm_token: "${token}" }`;
      return { content: [{ type: "text", text: preview }] } as const;
    }
    const finalPayload = confirm_token && pendingTokens.get(confirm_token) ? pendingTokens.get(confirm_token) : payload;
    const headers: Record<string,string> = {};
    if (idempotency_key) headers['X-Idempotency-Key'] = idempotency_key;
    const created = await makeSevyaRequest<any>("/opportunities", "POST", finalPayload, headers);
    if (!created) {
      return buildError(LAST_ERROR_CODE || 'W5', "Échec création opportunité (réseau/HTTP).");
    }
    if (confirm_token) pendingTokens.delete(confirm_token);
    const summary = `Opportunité créée.\nID: ${created.id ?? 'inconnu'}\nNom: ${finalPayload.name}\nStatut: ${created.status ?? finalPayload.status ?? '—'}`;
    return { content: [{ type: "text", text: summary }] } as const;
  },
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Sevya CRM MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error in main():", error);
  process.exit(1);
});
EOF

# Compiler le serveur
echo -e "${BLUE}🔨 Compilation du serveur...${NC}"
npm run build

# Vérifier que la compilation a réussi
if [ ! -f "build/index.js" ]; then
    echo -e "${RED}❌ Erreur lors de la compilation du serveur.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Serveur MCP compilé avec succès !${NC}"

echo -e "${BLUE}ℹ️  Étape suivante: configuration manuelle de Claude Desktop (copier/coller).${NC}"

# Créer un script de test
echo -e "${BLUE}🧪 Création d'un script de test...${NC}"
cat > test-server.sh << 'EOF'
#!/bin/bash
echo "Test du serveur MCP Sevya CRM..."
echo "Démarrage du serveur (appuyez sur Ctrl+C pour quitter)."
node build/index.js
EOF
chmod +x test-server.sh

# Afficher le résumé
echo ""
echo -e "${GREEN}🎉 Installation terminée avec succès !${NC}"
echo "=================================================="
echo -e "${BLUE}📁 Serveur installé dans: ${MCP_DIR}${NC}"
echo ""
cat << 'INSTRUCTIONS'
📋 Étapes suivantes (manuelles, simples)

1) Ouvrez le fichier de configuration de Claude Desktop
   - macOS : ~/Library/Application Support/Claude/claude_desktop_config.json
   - Windows : %APPDATA%\Claude\claude_desktop_config.json
   - Linux : ~/.config/claude/claude_desktop_config.json

2) Copiez-collez le bloc suivant (adaptez UTILISATEUR et votre clé API)
{
  "mcpServers": {
    "sevya-crm": {
      "command": "node",
      "args": [
        "/Users/VOTRE_NOM_UTILISATEUR/Documents/sevya-mcp-server/build/index.js"
      ],
      "env": {
        "SEVYA_API_KEY": "sk_live_votreCleIci",
        "SEVYA_API_BASE": "https://tceelmvnduayksvnciwx.supabase.co/functions/v1",
        "SEVYA_PROFILE_NAME": "sevya-crm"
      }
    }
  }
}

3) Enregistrez le fichier puis redémarrez Claude Desktop

INSTRUCTIONS
echo -e "${GREEN}✅ Aucun changement n'a été fait automatiquement dans Claude.${NC}"
