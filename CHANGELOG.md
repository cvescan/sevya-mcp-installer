# Changelog — Sevya MCP Installer

## v1.2.1 — 2025-09-10

- Fix: Harden `get_opportunities` to accept varied response shapes from the Edge Function:
  - Accept arrays at root or under `opportunities`, `data`, `items`, `results`, `records`, `list`, `rows`.
  - Handle nested containers like `opportunities.nodes` or `opportunities.edges[].node`.
  - Normalize `null` opportunities to an empty list.
- Schema: Allow `null` for `estimated_amount` and `client_id` in opportunities.
- DX: Enrich S4 error with top-level keys to speed up diagnosis.
- Dependencies: Bump `@modelcontextprotocol/sdk` and `zod` versions in installer.

## v1.2.2 — 2025-09-10

- Feature: Add `count_only` option to `get_opportunities` to return only the number of opportunities created in a given period (based on `created_at`).
- UX: Clarify header to explicitly state “opportunités créées” and add a note that status breakdown reflects the current state, not conversions during the period.

## v1.2.3 — 2025-09-10

- Feature: Display postal code in `get_opportunities` when available.
  - Reads from common fields: `zip_code`, `zipcode`, `postal_code`, `postcode`, `cp`, or `address.*`.
  - Fallback: extract from `notes` or custom fields (heuristic), matching a 5-digit FR pattern.

## v1.2.0 — 2025-09-02

- Feature: Expose `utm` (JSON) and `form_id` for opportunities in the MCP server schema.
- Feature: Enriched `get_opportunities` formatting with marketing tracking details:
  - 📊 UTM: `utm_source`, `utm_medium`, `utm_campaign`, `utm_term`, `utm_content`, `utm_id`
  - 🔗 `gclid` and 📘 `fbclid` (also surfaced from top‑level fields if not in `utm`)
  - 🌐 URL source (`page_url`/`landing_url`/`url` fallback)
  - 📝 Form ID (`form_id`)
- Feature: Add `get_current_date` tool to avoid time‑context mistakes by the agent.
- UX: Prepend today’s date to headers of `get_opportunities`, `get_clients`, `get_purchases` outputs.
- Docs: Update README one‑liner and document included features.

Install (one‑liner):

```
curl -fsSL https://raw.githubusercontent.com/cvescan/sevya-mcp-installer/main/scripts/install-sevya-mcp.sh | bash
```

After install, add your `SEVYA_API_KEY` to Claude’s config and restart the app.
