# Memory — Sevya MCP Installer

Context: Production issues surfaced when calling `get_opportunities` due to response shape variations from the Edge Function.

What changed (v1.2.1–v1.2.3)
- Normalization: Accept arrays at root or under `opportunities`, `data`, `items`, `results`, `records`, `list`, `rows`. Support nested `opportunities.nodes` and `opportunities.edges[].node`. Convert `null` to `[]`.
- Schema: `estimated_amount` and `client_id` are now nullable in the Zod schema for opportunities.
- Diagnostics: When schema parsing fails (S4), include the top-level keys of the payload to speed diagnosis.
- Installer: Embeds the updated server code and bumps SDK/Zod versions.
 - Option: `count_only` for `get_opportunities` to return just the number of opportunities created within the period (based on `created_at`).
 - Clarity: Header explicitly mentions “opportunités créées” and adds a note that status counts are current-state snapshots, not period conversions.
 - Postal code: `get_opportunities` now displays `Code postal` when present (common fields and `address.*`), with heuristic fallback from `notes`/custom fields.

Files affected
- `scripts/install-sevya-mcp.sh`: embedded `src/index.ts` and package.json template updated.
- `CHANGELOG.md`: new entry `v1.2.1`.

Impact
- Fixes S4 errors for `get_opportunities` caused by Edge Function response differences.
- Improves resilience to backend changes without requiring immediate MCP updates.
