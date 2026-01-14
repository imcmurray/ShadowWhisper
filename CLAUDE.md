# ShadowWhisper

## 🚨 STOP 🚨 READ THIS FIRST 🚨

### Browser Testing - USE DOCKER MCP ONLY

**DO NOT install Playwright locally. The Docker container handles everything.**

❌ WRONG: `npx playwright install`
❌ WRONG: `npm install playwright`
❌ WRONG: `npx playwright install chromium`
❌ WRONG: Any local browser installation command

✅ RIGHT: Use MCP Playwright tools directly:
- `mcp__playwright-mcp__browser_navigate`
- `mcp__playwright-mcp__browser_click`
- `mcp__playwright-mcp__browser_snapshot`
- `mcp__playwright-mcp__browser_type`

The Docker container (`mcr.microsoft.com/playwright/mcp`) already has all browsers pre-installed.
Local installation will FAIL and waste time.

---
