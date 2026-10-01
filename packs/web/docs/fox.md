# Firefox, the privacy settings

[← Back to the README](../../../README.md#optional-tooling)

Two sets, one at a time, and the launcher picks: `fox` opens the browser on
the **light** set, `pfox` opens a private window on the **strict** one.
Nothing to activate by hand — the settings are read as Firefox starts, so
opening the browser with one of these *is* choosing the set, and the install
leaves the light one in place. The rest of the pack is
[the browser and the tunnel](web.md).

```bash
gmake fox_tweak_on                           # the strict set, put in place by hand
gmake fox_tweak_off                          # everything out - the browser stock again
```

## The two sets

|  | The light set | The strict set |
| :--- | :--- | :--- |
| What it holds | tracking protection, URL cleaning, pings and prefetch off, HTTPS-only, DoH off, telemetry off, geolocation denied | the light set **plus** anti-fingerprinting and WebRTC off |
| What you notice | nothing | English pages, UTC hours, grey margins, no calls in the browser |

## How the switch works

- The browser's directory holds one **link** —
  `/usr/lib/firefox/defaults/pref/fox-privacy.js` — pointing at a file of your
  own, `~/.config/fox-privacy.js`. A set is put in place by replacing *that*
  file: the link is written once (by the install, or by the first launch), and
  after that **a switch costs no password**.
- **`fox`** puts the light set back, then opens the browser. **`pfox`** puts
  the strict set, then opens a private window — and refuses to launch while
  Firefox is already running: the settings count at the next start, and a
  "strict" `pfox` opening a light session would be silently wrong.
- Both sets are *defaults*, not orders: a value set in `about:config` wins,
  and a browser keeps the set it started with until it is closed — which is
  why the launcher is what picks.

## What changes while you browse

The strict set is the one with visible effects:

| You will notice | The preference behind it |
| :--- | :--- |
| Pages in English, times in UTC | `privacy.resistFingerprinting` |
| Grey margins around pages | `privacy.resistFingerprinting.letterboxing` |
| A warning page on an http-only site | `dom.security.https_only_mode` |
| Location requests refused | `permissions.default.geo` |
| No calls (Jitsi, Meet) | `media.peerconnection.enabled` |

The DNS is the tunnel's business: Firefox's own DNS-over-HTTPS is turned off so
it cannot step around the tunnel ([the tunnel's page](vpn.md)).

## The preferences

**Both sets** — the Strict tracking preset, named pref by pref (trackers,
suspected fingerprinters, cryptominers, social trackers, email pixels); URL
tracking parameters (`fbclid`, `utm_*`…) stripped in every window, private or
not; pings and the Beacon API off; no prefetch or DNS pre-resolution;
HTTPS-only in every window; DoH off; no camera/microphone enumeration;
geolocation denied by default (one site can still be allowed through the
padlock); telemetry and studies off; the do-not-sell signal on.

**The strict set adds** — `privacy.resistFingerprinting` with
`privacy.resistFingerprinting.letterboxing`: the UTC/en-US trade, a generic
user-agent, canvas noise, standardized window sizes. And
`media.peerconnection.enabled` false: no real-time connections from a page.

## uBlock Origin, and the rest

Ad blocking is not in the sets: uBlock Origin is two clicks from
[addons.mozilla.org](https://addons.mozilla.org/firefox/addon/ublock-origin/)
and updates itself. In its dashboard, beyond the lists that are on by default:
*AdGuard Tracking Protection*, the two malware/phishing lists, and — under
*Annoyances* — *uBlock filters - Annoyances*, *AdGuard - Cookie Notices* and
*Fanboy's Social Blocking List*; *Settings → Uncloak canonical names* closes
the CNAME trick. With Firefox's own URL cleaner above, that covers what
ClearURLs used to do — without one more extension reading every page.

## Removing the pack

`remove_pack` takes the link, the file it points at and the sound preference
back. Your profile — `~/.mozilla`, bookmarks, passwords, history — stays, as
always.
