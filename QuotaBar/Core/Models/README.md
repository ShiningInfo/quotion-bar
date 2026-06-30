# Quota Snapshot Schema

`SharedSnapshotStore` writes a JSON array of `QuotaSnapshot` objects to the App Group file named by `ConfigKeys.snapshotFilename`.

Dates use `JSONEncoder.DateEncodingStrategy.iso8601` and `JSONDecoder.DateDecodingStrategy.iso8601`.

## Provider IDs

- `codex`
- `minimax`
- `deepseek`

## Source Types

- `api`
- `webview_session`

## Snapshot Object

```json
{
  "provider": "codex",
  "displayName": "Codex",
  "planType": "ChatGPT Plus/Codex",
  "used": 25,
  "remaining": 75,
  "total": 100,
  "unit": "requests",
  "resetAt": "2026-06-30T18:00:00Z",
  "period": "5h",
  "lastSyncedAt": "2026-06-30T13:00:00Z",
  "sourceType": "webview_session",
  "status": "synced",
  "errorMessage": null
}
```

Optional numeric/date fields may be `null` or omitted by Swift encoding when the value is `nil`.

## Fields

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `provider` | String | Yes | Provider ID: `codex`, `minimax`, or `deepseek`. |
| `displayName` | String | Yes | Human-readable provider name. |
| `planType` | String | Yes | Plan label such as `Token Plan`, `API Pay-as-you-go`, or `ChatGPT Plus/Codex`. |
| `used` | Number or null | No | Used amount in `unit`. |
| `remaining` | Number or null | No | Remaining amount in `unit`. |
| `total` | Number or null | No | Total quota for the period in `unit`. |
| `unit` | String | Yes | Unit label such as `requests`, `tokens`, or `USD`. |
| `resetAt` | ISO-8601 date or null | No | Next reset time when the provider exposes one. |
| `period` | String or null | No | Quota period such as `5h`, `weekly`, or `monthly`. |
| `lastSyncedAt` | ISO-8601 date | Yes | Time this snapshot was produced. |
| `sourceType` | String | Yes | `api` or `webview_session`. |
| `status` | String | Yes | One of the Provider status values below. |
| `errorMessage` | String or null | No | User-displayable sync/configuration failure detail. |

## Provider Status Values

- `notConfigured`
- `needsLogin`
- `authenticated`
- `syncing`
- `synced`
- `sessionExpired`
- `syncFailed`

## State Machine

| Current | Allowed Next | Typical Trigger |
| --- | --- | --- |
| `notConfigured` | `needsLogin`, `authenticated` | User configures provider or saves API credentials. |
| `needsLogin` | `authenticated`, `notConfigured` | Login succeeds or user clears config. |
| `authenticated` | `syncing`, `needsLogin`, `sessionExpired`, `notConfigured` | Refresh begins, credentials are missing, session expires, or user logs out. |
| `syncing` | `synced`, `syncFailed`, `sessionExpired` | Fetch succeeds, fetch fails, or auth expires during fetch. |
| `synced` | `syncing`, `sessionExpired`, `needsLogin`, `notConfigured` | Scheduled refresh, session expiry, login required, or user logs out. |
| `sessionExpired` | `needsLogin`, `authenticated`, `notConfigured` | User is prompted, reauth succeeds, or provider is removed. |
| `syncFailed` | `syncing`, `needsLogin`, `sessionExpired`, `notConfigured` | Retry, auth required, session expiry, or user logs out. |

`ProviderStatus.transition(on:)` encodes the common event-driven transitions used by tests and by future scheduler work.
