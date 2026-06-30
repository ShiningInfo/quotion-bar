# DeepSeek Provider

`DeepSeekProvider` implements `ProviderProtocol` and reads the API key from Keychain using:

- service: `quota-bar.deepseek`
- account: `deepseek_api_key`

The provider calls `GET https://api.deepseek.com/user/balance` with `Authorization: Bearer <api-key>`.

## Field Mapping

DeepSeek returns `balance_infos` entries with `currency`, `total_balance`, `granted_balance`, and `topped_up_balance`.

QuotaBar maps the preferred balance entry to:

- `id`: `deepseek`
- `name`: `DeepSeek`
- `totalQuota`: `granted_balance + topped_up_balance`
- `usedQuota`: `max(0, totalQuota - total_balance)`
- `remainingQuota`: computed by `ProviderQuota` as `totalQuota - usedQuota`
- `unit`: DeepSeek `currency` (`USD` or `CNY`)
- `status`: `active` when `is_available` is true, otherwise `inactive`
- `period`: `pay-as-you-go`
- `sourceType`: `api`

If multiple currencies are returned, USD is preferred; otherwise the first entry is used.

## Error Handling

- Missing API key: returns `sessionExpired` with a reauthorization message.
- HTTP 401/403: returns `sessionExpired` with a reauthorization message.
- HTTP 5xx or other non-200 responses: returns `syncFailed` and includes the HTTP code.
- Network failures and invalid JSON: returns `syncFailed` with the localized error.

## Current Limits

DeepSeek's balance API does not provide a fixed reset date for pay-as-you-go billing. `resetAt` is not represented in the current `ProviderQuota` model, so downstream UI should treat the reset period as not provided.

Usage-page scraping and CSV export parsing are intentionally out of scope for this provider implementation.
