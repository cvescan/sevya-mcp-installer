# Changelog — Sevya MCP Installer

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
