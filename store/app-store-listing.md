# Sundiver — App Store Listing Copy

Paste-ready metadata for App Store Connect. Character limits noted in parentheses.

---

## App Name (30)
`Sundiver`

## Subtitle (30)
`One-tap solar orbit arcade`

## Promotional Text (170)
> Now with 4 difficulty levels and pulse orbs to blast your way out of trouble. Unlock comet trails, sun themes, and starfields as you chase your best score. No ads, no IAP.

## Keywords (100, comma-separated, no spaces)
`sundiver,orbit,arcade,one tap,reflex,space,endless,dodge,ring,high score,casual,comet,tap,twitch,sun`

## Description (4000)
Leap between orbits. Don't get burned.

Sundiver is a one-tap arcade game about timing and nerve. Your comet circles a blazing sun on two rings — tap to dive between them, thread the solar flares, and grab every ember before the whole thing speeds up and pulls you in.

One more run. Every time.

FEATURES
• One-tap controls — instantly playable, endlessly hard to master
• 4 difficulty levels — Easy through Extreme, each with its own tuning and its own high score
• Pulse orbs — bank a charge and blast the flare ahead of you when a dive gets too tight
• Pure neon-on-black style — glowing comet trails, particle bursts, screen shake
• 6 unlockable comet colors — earned by pushing your high score, from Comet Blue to the legendary Prism White
• An Ember Shop — spend the embers you collect on 5 comet trails, 5 sun themes, and 5 starfield themes
• Shield embers — grab the rare white ember for a one-hit shield against the next flare
• Two goals at once — score for prestige colors, embers for cosmetics
• Play anywhere — iPhone and iPad, with your progress saved

No ads. No in-app purchases. No tracking. Pay once, dive forever.

How close can you get before the sun wins?

## What's New (v1.1)
`Choose your challenge with 4 difficulty levels, each with its own high score. Bank pulse orbs and blast a flare out of your path when a dive gets too tight. New sun and starfield themes to unlock in the redesigned Ember Shop.`

## What's New (v1.0)
`Initial release. Tap in and chase your first high score.`

---

## App Store Connect settings
- **Price:** Tier 1 — $0.99 USD
- **Primary category:** Games → Arcade
- **Secondary category:** Games → Action (optional)
- **Age rating:** 4+ (no objectionable content)
- **Privacy:** Data Not Collected
- **In-App Purchases:** None
- **Support URL:** https://stoopsj462.github.io/sundiver/
- **Marketing URL (optional):** https://stoopsj462.github.io/sundiver/
- **Privacy Policy URL:** https://stoopsj462.github.io/sundiver/privacy.html

> These URLs go live once the `sundiver` repo is pushed to GitHub and Pages is enabled
> (Settings → Pages → main → /docs). Same outstanding step as orbitor-game/plaingame.

## Screenshots
> Pending re-capture for v1.1 — the menu, shop, and HUD were redesigned (difficulty
> picker, pulse orb button, Ember Shop grid), so the existing PNGs in
> `store/screenshots/appstore/` are stale and need to be replaced before this update
> is submitted.

Captured from simulators, then resized to the exact pixel sizes App Store Connect's
screenshot uploader actually asks for on this account (no alpha channel, flattened):

| Device | Size (px) | Simulator used | Notes |
|---|---|---|---|
| iPhone (6.5" slot) | 1284 × 2778 | iPhone 17 Pro Max, native 1320×2868, resized down | ASC asked for 1242×2688/2688×1242/1284×2778/2778×1284 — same slot Orbitor uses |
| iPad 13" slot | 2064 × 2752 | iPad Pro 13-inch (M5), native resolution, no resize needed | |

Captured with a fresh app install and a short delay before each shot to avoid the
simulator's occasional system notification banner sneaking into frame — check any
newly captured screenshot for that before uploading.

Four shots per device, in `store/screenshots/appstore/`: **menu**, **mid-run gameplay**,
**game over / new best**, **the shop**.

## Bundle / App record (already done via API, 2026-09-15)
- Bundle ID `com.jasonstoops.sundiver` registered (Developer Portal, id `HPPPC42LX3`).
- **App Store Connect app record still needs to be created manually** — the Apps API only
  allows `GET`/`UPDATE`, not `CREATE` (Apple restricts this to the website). Steps for Jason:
  1. appstoreconnect.apple.com → My Apps → **+** → New App
  2. Platform: iOS. Name: `Sundiver`. Primary language: English (U.S.)
  3. Bundle ID: pick `com.jasonstoops.sundiver` (already registered, will appear in the list)
  4. SKU: `sundiver-ios-001`
  5. User Access: Full Access
- Once created, the rest (localized description/keywords, category, age rating, pricing) can
  be set via the App Store Connect API using the same Admin key — no more browser automation
  needed for metadata, since `apps` supports `UPDATE` once the record exists.
