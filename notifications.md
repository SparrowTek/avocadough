# Push Notifications Plan (No Server)

## The iOS Reality

iOS **will not** let you hold a persistent WebSocket open in the background. Apple requires APNs for reliable push delivery, full stop. So there's no way to get instant, 100%-reliable notifications without *some* server talking to APNs.

**But** — you can get a pretty solid experience with a two-tier local approach:

---

## Tier 1: Real-time (foreground / brief background)

NIP-47 added a `notifications` subscription — the NWC relay can push `payment_received` events over the existing WebSocket. While the app is open (or in the ~30s iOS grace period after backgrounding):

1. Subscribe to NWC notifications on the relay connection
2. When a `payment_received` event arrives, fire a **local notification** via `UNUserNotificationCenter`
3. User sees the notification even if they've swiped to another app (within that grace window)

**Caveat:** The current `WalletConnectManager` from nostr-sdk-ios doesn't appear to have a `notifications` subscription. This would need to be added to the nip-47 branch — or implemented directly at the Nostr event level.

## Tier 2: Background polling (best-effort)

Use `BGAppRefreshTask` to periodically wake the app:

1. Register a background task in `AvocadoughApp.init`
2. When iOS wakes the app (every ~15min to hours — iOS decides), connect to the NWC relay
3. Call `list_transactions`, compare against the latest `settledAt` in SwiftData
4. Fire local notifications for any new incoming transactions
5. Schedule the next refresh

This isn't instant, but it catches payments that arrived while the app was suspended.

## Tier 3: Catch-up on launch

On every app launch, diff transactions and show a summary notification or in-app banner for anything missed.

---

## What This Gets You

| Scenario | Notification Delay |
|---|---|
| App in foreground | Instant |
| App just backgrounded (<30s) | Instant |
| App suspended | 15min – few hours (iOS decides) |
| App killed | Next launch |

---

## Alternatives Considered & Rejected

- **PushKit (VoIP)** — Apple will reject the app; it's only for actual VoIP
- **Silent pushes** — Still needs a server sending through APNs
- **Persistent background WebSocket** — iOS kills it
- **Live Activities** — Cool for tracking an in-progress payment, not for receiving unexpected ones

## If You Ever Want Instant + Reliable

The lightest server option would be something like a tiny Cloudflare Worker or Lambda that subscribes to the NWC relay, watches for `payment_received` events, and sends an APNs push. Minimal infra, no always-on server.

---

## Implementation Steps

1. **Add `notifications` subscription support** to nostr-sdk-ios (or implement at the event layer in-app)
2. **Create a `NotificationManager`** — request permissions, handle local notification scheduling
3. **Wire up Tier 1** — subscribe on connect, fire local notifications on payment events
4. **Wire up Tier 2** — register `BGAppRefreshTask`, poll + diff + notify
5. **Add background mode** — `BGTaskSchedulerPermittedIdentifiers` in Info.plist, `fetch` background mode
