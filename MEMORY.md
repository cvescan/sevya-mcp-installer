# Memory — Sevya MCP Installer

Context: Production issues surfaced when calling `get_opportunities` due to response shape variations from the Edge Function.

What changed (v1.2.1)
- Normalization: Accept arrays at root or under `opportunities`, `data`, `items`, `results`, `records`, `list`, `rows`. Support nested `opportunities.nodes` and `opportunities.edges[].node`. Convert `null` to `[]`.
- Schema: `estimated_amount` and `client_id` are now nullable in the Zod schema for opportunities.
- Diagnostics: When schema parsing fails (S4), include the top-level keys of the payload to speed diagnosis.
- Installer: Embeds the updated server code and bumps SDK/Zod versions.

Files affected
- `scripts/install-sevya-mcp.sh`: embedded `src/index.ts` and package.json template updated.
- `CHANGELOG.md`: new entry `v1.2.1`.

Impact
- Fixes S4 errors for `get_opportunities` caused by Edge Function response differences.
- Improves resilience to backend changes without requiring immediate MCP updates.

