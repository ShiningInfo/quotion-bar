# MiniMax Token Plan Provider

`MiniMaxProvider` reads MiniMax Token Plan quota from the already-authenticated main app WebView session.

## Session source

- Service name: `quota-bar.minimax`
- Session account marker: `session`
- Cookie source: the main app `WKWebsiteDataStore` cookie store
- Cookie scope: `platform.minimaxi.com` and `*.minimaxi.com`

The provider stores only a session marker in Keychain. It does not persist raw Cookie values or Authorization headers.

## Fetch order

1. GET `https://platform.minimaxi.com/console/usage` with the WebView Cookie header.
2. Treat HTTP `401` / `403`, or a returned login page, as `sessionExpired`.
3. Extract usage API hints from the page HTML, then try known candidate endpoints:
   - `/console/api/v1/usage/summary`
   - `/console/api/v1/usage/token-plan`
   - `/console/api/v1/token-plan/usage`
4. Parse the first usable JSON response.
5. If no JSON endpoint is usable, parse the Usage page HTML directly.

## Field mapping

| MiniMax value | QuotaBar field |
| --- | --- |
| Provider | `id = "minimax"`, `name = "MiniMax"` |
| Plan | `planType = "Token Plan"` or parsed plan label |
| Used tokens | `usedQuota` |
| Total tokens | `totalQuota` |
| Remaining tokens | computed by `ProviderQuota.remainingQuota` |
| Reset time | `resetAt` |
| Billing period | `period`, default `monthly` |
| Unit | `tokens` |
| Source | `sourceType = "webview_session"` |

## Parser behavior

`MiniMaxParser` supports both JSON/XHR and HTML fallback inputs. It recognizes common English and Chinese labels for used, total, remaining, plan, period, and reset date.

If required quota fields cannot be identified, it throws `MiniMaxParserError.missingRequiredFields` with:

- the failed URL
- the expected selector/label names
- a short response snippet for diagnostics

## Current limitations

MiniMax does not publish a stable personal Token Plan usage API. The provider therefore depends on the console page and its private XHR payloads. If MiniMax changes the Usage page labels or response field names, parsing can fail with `syncFailed` until the parser rules are updated.

Logs must not include full Cookie values or Authorization headers. Diagnostic errors include only URL and short page snippets.
