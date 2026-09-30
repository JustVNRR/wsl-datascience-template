# Firefox, the privacy defaults

[← Back to the README](../../../README.md#optional-tooling)

Two targets, one file, and a switch between them: `gmake fox_tweak_on` writes
the pack's privacy preferences where Firefox reads its own, `gmake
fox_tweak_off` takes them back out. Nothing is applied by the install — the
defaults are opt-in, and the browser the pack ships stays stock until one of
these runs. The rest of the pack is [the browser and the tunnel](web.md).

```bash
gmake fox_tweak_on                           # every profile; about:config still wins
gmake fox_tweak_off                          # the browser's own defaults again
```

Close and reopen Firefox for either to take effect — preferences are read at
startup, like the sound one.

## The file

`/usr/lib/firefox/defaults/pref/fox-privacy.js`, beside the sound preference
the install leaves in the same directory — and for the same reason: what lives
there is a **default**, not an order.

- It applies to **every profile**, present and future — no profile name to
  guess, and a profile created later inherits it with nothing to do.
- A value set in `about:config` **wins over it**: relaxing one preference for
  one site is a one-line exception.
- `fox_tweak_off` is the file leaving: Firefox is back to its own defaults in
  one move — no `prefs.js` to rewrite, nothing half-applied.

A `user.js` in a profile would force the values instead. The pack did not
choose it: the profile only exists after a first launch, a running Firefox has
to be refused, and taking one value back means editing `prefs.js` by hand.

## What changes while you browse

| You will notice | Why |
| :--- | :--- |
| Pages in English, times in UTC | The anti-fingerprinting trade: one language and one time zone for everyone |
| Grey margins around pages | Letterboxing — the window's size is standardized, and the margins fill the rest |
| A warning page on an http-only site | HTTPS-only, with a button through |
| A location request refused | Geolocation denied by default; one site can be allowed through the padlock |
| Calls that will not work (Jitsi, Meet) | WebRTC is off — this instance has no camera anyway |

The DNS is the tunnel's business: Firefox's own DNS-over-HTTPS is turned off so
it cannot step around the tunnel ([the tunnel's page](vpn.md)).

## The preferences

**Tracking protection** — the Strict preset: `browser.contentblocking.category`
and the engines it names (trackers, suspected fingerprinters, cryptominers,
social trackers, email pixels). URL tracking parameters (`fbclid`, `utm_*`…)
are stripped in every window, private or not.

**Pings** — `browser.send_pings` and `beacon.enabled`: no notification when you
click a link, no Beacon API.

**Prefetch** — `network.prefetch-next`, `network.dns.disablePrefetch`: Firefox
neither preloads pages you have not clicked nor resolves their names early.

**TLS and DNS** — `dom.security.https_only_mode`, `network.trr.mode` (5: DoH
off, see above).

**What a page may read** — `media.navigator.enabled` (no camera/microphone
enumeration), `permissions.default.geo` (2: denied unless allowed by hand).

**Telemetry and studies** — `datareporting.healthreport.uploadEnabled`,
`app.shield.optoutstudies.enabled`, and `privacy.globalprivacycontrol.enabled`
(the do-not-sell signal on).

**Anti-fingerprinting** — `privacy.resistFingerprinting` and
`privacy.resistFingerprinting.letterboxing`: the UTC/en-US trade above, a
generic user-agent, canvas noise, standardized window sizes.

**WebRTC** — `media.peerconnection.enabled` false.

## uBlock Origin, and the rest

Ad blocking is not in the file: uBlock Origin is two clicks from
[addons.mozilla.org](https://addons.mozilla.org/firefox/addon/ublock-origin/)
and updates itself. In its dashboard, beyond the lists that are on by default:
*AdGuard Tracking Protection*, the two malware/phishing lists, and — under
*Annoyances* — *uBlock filters - Annoyances*, *AdGuard - Cookie Notices* and
*Fanboy's Social Blocking List*; *Settings → Uncloak canonical names* closes
the CNAME trick. With Firefox's own URL cleaner above, that covers what
ClearURLs used to do — without one more extension reading every page.

## Removing the pack

`remove_pack` takes the file back with the sound preference. Your profile —
`~/.mozilla`, bookmarks, passwords, history — stays, as always.
