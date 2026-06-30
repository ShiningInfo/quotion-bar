# Codex / ChatGPT Provider

## Session source

`CodexProvider` uses the main app `WKWebsiteDataStore` cookie store for `chatgpt.com` and records only a local Keychain session handle under `service=quota-bar.codex`, `account=local-session`. It does not persist raw ChatGPT cookies, session tokens, or authorization headers.

## Fetch flow

1. Read `chatgpt.com` cookies from the shared WebKit data store.
2. Load `https://chatgpt.com/codex/settings/usage` and `https://chatgpt.com/#settings/Billing` with those cookies.
3. Extract internal API hints from the returned HTML.
4. Try known candidate endpoints first:
   - `https://chatgpt.com/backend-api/codex/usage`
   - `https://chatgpt.com/backend-api/billing/credit_summary`
   - `https://chatgpt.com/api/codex/usage`
   - `https://chatgpt.com/api/billing/credit_summary`
5. Fall back to parsing the usage or billing HTML when no stable API response is recognized.

## Field mapping

- `provider`: `codex`
- `displayName`: `Codex (ChatGPT)`
- `planType`: parsed from plan, subscription, tier, or page text; defaults to `ChatGPT Codex`
- `used`, `remaining`, `total`: parsed from credits/messages fields
- `unit`: `credits` or `messages`
- `resetAt`: parsed from reset, refresh, renew, or expiry fields
- `period`: parsed as `5h`, `weekly`, or `unknown`
- `sourceType`: `webview_session`

## Error handling

- Missing cookies, HTTP 401/403, login pages, Cloudflare challenge pages, or second-factor prompts return `sessionExpired`.
- Unrecognized API or HTML structure returns `syncFailed` with a short location/snippet message.
- Logs and error messages must not include raw Cookie headers, `Authorization`, or `__Secure-next-auth.session-token` values.

## Current limits

OpenAI does not expose a stable personal ChatGPT Codex quota API equivalent to organization usage/cost APIs. This provider treats internal ChatGPT endpoints and page structure as best-effort inputs and keeps parser failures explicit so platform changes are visible during sync.
