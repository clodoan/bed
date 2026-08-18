# Bed

A Mac menu-bar radio with two sources:

- **Stations** — free curated internet radio (SomaFM's deep house / downtempo /
  lounge channels, Nightride synthwave). No account, no API key, works out of
  the box. Skip cycles stations. These are donation-supported stations —
  somafm.com and nightride.fm.
- **AI** — type what you want to hear; it generates a looping instrumental
  (Stable Audio 2.5 via Replicate, ~90s, loops until you skip or change the
  prompt). Needs a Replicate API token:
  https://replicate.com/account/api-tokens

```sh
./scripts/bundle.sh
open Bed.app
```
