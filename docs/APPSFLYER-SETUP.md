# AppsFlyer + SKAdNetwork — Goldn setup and handover notes

Integration added 2026-09-08 so TikTok Ads campaigns for Goldn can be measured.
Same design as ControlDopamine (`controldopamine/docs/APPSFLYER-SETUP.md`), with
two deliberate differences explained in section 2.

---

## 1. What was changed (1.1.2, build 20)

| File | Change |
|---|---|
| `SOLA/Services/Analytics/AppsFlyerConfig.swift` | New. Dev key + Apple App ID (public client keys, same convention as `TikTokAdsConfig`). |
| `SOLA/Services/Analytics/AppsFlyerEvent.swift` | New. Event → AppsFlyer name/parameter mapping. Pure Foundation, no SDK dependency. |
| `SOLA/Services/Analytics/AppsFlyerTracker.swift` | New. SDK init, ATT wait, session start, RevenueCat bridge, app delegate. |
| `SOLA/Services/Analytics/AppsFlyerSmoke.swift` | New. DEBUG smoke-asserts (`SOLA_ANALYTICS_SMOKE`), same pattern as `TikTokAnalyticsSmoke`. |
| `SOLA/SOLAApp.swift` | Attaches the app delegate via `@UIApplicationDelegateAdaptor`; runs the smoke. |
| `SOLA/Services/PurchaseManager.swift` | Logs `af_purchase` / `af_start_trial` on a successful purchase. |
| `SOLA/Services/Analytics/TikTokAnalytics.swift` | `disableSKAdNetworkSupport()` on the TikTok SDK — see 2.2. |
| `App-Info.plist` | AppsFlyer SKAN postback endpoint; SKAdNetwork IDs for TikTok (`mj797d8u6f`) and Pangle (`22mmun2rn5`, `238da6jt44` — only the last one was present before). |
| `SOLA.xcodeproj` | `AppsFlyerFramework` 7.0.2 via SPM (product `AppsFlyerLib`); version 1.1.1 (19) → 1.1.2 (20). |

`PrivacyInfo.xcprivacy` was **not** changed: `NSPrivacyTracking` was already
`true` and `DeviceID` was already declared for third-party advertising. AppsFlyer
domains must **not** be added to `NSPrivacyTrackingDomains` — iOS would then block
the SDK entirely for non-consenting users, killing SKAN and organic install data.

---

## 2. Decisions worth knowing about

### 2.1 Standard SDK, not Strict — because ATT is already there

ControlDopamine links `AppsFlyerFramework-Strict` (no IDFA, no ATT prompt).
Goldn already shows the system ATT prompt for the TikTok Business SDK and
declares `NSPrivacyTracking = true`, so there is nothing to gain from Strict and
real attribution to lose. The standard SDK is linked and
`waitForATTUserAuthorization(timeoutInterval: 60)` holds the install report
until the user answers the prompt (shown ~0.5 s after the scene becomes active,
see `RootView`). Consenting users are attributed by IDFA; everyone else by SKAN.

### 2.2 Only one SDK may drive SKAdNetwork conversion values

Apple honours only the **first** caller of `updatePostbackConversionValue`. The
TikTok Business SDK calls it by default (`SKAdNetworkSupportEnabled = YES`), and
so does AppsFlyer. Two callers corrupt the postback, so the TikTok SDK's SKAN
support is switched off in `TikTokBusinessSink.initializeSDK()` and AppsFlyer
owns the conversion-value schema (Conversion Studio). The TikTok SDK keeps doing
what it did before: pixel-style events (`ViewContent`, `StartTrial`,
`CompletePayment`…) after ATT.

Do not add conversion-value code to the app either.

---

## 3. Dashboard

### 3.1 App + dev key — done 2026-09-08

Goldn (`id6779321701`) was added to the buyer's AppsFlyer account (BRL, UTC,
not directed at children — same as ControlDopamine). The dev key is
account-level and identical to ControlDopamine's: `fDFVLwWGpwQqKnYoNP2Czi`,
read back from App Settings. It is hardcoded in `AppsFlyerConfig.swift`.

### 3.2 TikTok For Business — Advanced SRN

Collaborate → Partner Marketplace → **TikTok For Business - Advanced SRN**
(`tiktokglobal_int`) → Integration → TikTok App ID. Use the *numeric* TikTok
App ID from TikTok Ads Manager (Assets → App), **not** the App Store ID. Goldn's
value is the one already in `TikTokAdsConfig.tiktokAppID` (`7664919269825691656`).

The "Attribution link" tab stays locked for SRNs by design — TikTok attributes
on its own platform; once the App ID is saved the AppsFlyer side is finished.

The onboarding "Tiktok" tile leads to Pangle — do not use it.

### 3.3 RevenueCat → AppsFlyer — done 2026-09-09

RevenueCat project `c3328722` → Integrations → AppsFlyer → **App configuration**
(iOS App key = the dev key above, iOS App ID `id6779321701`, default event
names, gross revenue). Status reads "Active iOS app".

The RevenueCat form has **no per-event on/off switch** — every event is sent,
only its name is editable — so the events are kept on RevenueCat's default
`rc_*` names and never collide with the app's `af_purchase` /
`af_start_trial`:

| Event | Sent by | AppsFlyer name |
|---|---|---|
| Initial purchase / trial start | **the app** (on-device, drives SKAN) | `af_purchase` / `af_start_trial` |
| Initial purchase / trial start | RevenueCat (server, duplicate signal) | `rc_initial_purchase_event` / `rc_trial_started_event` |
| Trial → paid, renewal, cancellation, expiration, billing issue, product change | **RevenueCat** | `rc_trial_converted_event`, `rc_renewal_event`, … |

TikTok postbacks and the SKAN schema key on `af_*` only, so they are not
double-counted. The one known side effect: AppsFlyer's own revenue widgets sum
`af_revenue` across all events, so an initial (non-trial) purchase shows up
twice there — once from the app, once from `rc_initial_purchase_event`.
Renewals and trial conversions are counted once. Do **not** rename the
RevenueCat events to `af_purchase` — that would double the TikTok signal too.

The app stamps the AppsFlyer device ID on the RevenueCat subscriber
(`setAppsflyerID`) on every session so these server-side events land on the
right install.

### 3.4 SKAN Conversion Studio

Cannot be configured until AppsFlyer has *seen* `af_start_trial` /
`af_purchase` from real devices — the "In-app event" dropdown only lists events
already received (fake S2S events do not count, learned on ControlDopamine).
Once they appear, build a funnel schema: install → `af_start_trial` →
`af_purchase`. Goldn's weekly plan has a free trial; annual and lifetime do not,
so `af_purchase` carries real revenue from day 0 on those.

---

## 4. Events sent

| App moment | AppsFlyer event | Parameters |
|---|---|---|
| Purchase with no trial (annual, lifetime, promo) | `af_purchase` | `af_revenue`, `af_currency`, `af_content_id` |
| Subscription started in free trial (weekly) | `af_start_trial` | `af_price`, `af_currency`, `af_content_id` |
| App install | *(automatic)* | — |

A trial sends `af_price`, never `af_revenue`. `af_currency` is omitted (with the
amount) when StoreKit reports no currency, rather than defaulted — the account
currency is BRL and the app sells in EUR, so a silent default would mislabel
every purchase.

---

## 5. Verifying

1. Real device only — the simulator has no SKAdNetwork and no receipt.
2. DEBUG builds set `isDebug = true`; filter the console for `AppsFlyer`.
3. AppsFlyer dashboard → the install appears within minutes as organic.
4. Sandbox purchase → `af_purchase` or `af_start_trial` in the events tab.
5. SKAN postbacks take 24–48h+ and are withheld below Apple's privacy threshold.
6. Mapping smoke-asserts: `SIMCTL_CHILD_SOLA_ANALYTICS_SMOKE=1 xcrun simctl launch --console-pty --terminate-running-process booted com.meflabs.SOLA`
   → `✅ AppsFlyerSmoke OK`.

---

## 6. Known gaps

- OneLink / deep links, uninstall measurement — not wired.
- Cost API: connect the TikTok ad account under AppsFlyer → Cost for spend/ROAS.
