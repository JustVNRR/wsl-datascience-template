# Firefox, the privacy settings

[← Back to the README](../../../README.md#optional-tooling)

`fox` opens Firefox on the **light** set. `pfox` opens a private window on the
**strict** set, with the check page first. The install leaves the light set in
place; the rest of the pack is [the browser and the tunnel](web.md).

```bash
gmake fox_tweak_on    # the strict set, by hand
gmake fox_tweak_off   # everything out - stock browser
```

## The two sets

|  | Light | Strict |
| :--- | :---: | :---: |
| Strict tracking protection — trackers, fingerprinters, cryptominers, social trackers, email pixels | ✓ | ✓ |
| URL tracking parameters stripped (`fbclid`, `utm_*`…), every window | ✓ | ✓ |
| Pings and Beacon off | ✓ | ✓ |
| No prefetch, no DNS pre-resolution | ✓ | ✓ |
| HTTPS-only | ✓ | ✓ |
| DoH off — the DNS is the tunnel's | ✓ | ✓ |
| No camera/microphone enumeration | ✓ | ✓ |
| Geolocation denied by default | ✓ | ✓ |
| Telemetry and studies off, GPC on | ✓ | ✓ |
| Dark interface | ✓ | ✓ |
| Anti-fingerprinting — RFP + letterboxing (UTC/en-US, generic UA, canvas noise, standard window sizes) | — | ✓ |
| WebRTC off — no calls in the browser | — | ✓ |

## How the switch works

- `/usr/lib/firefox/defaults/pref/fox-privacy.js` is a link to
  `~/.config/fox-privacy.js`. Choosing a set replaces that file: written once
  (the install, or the first launch), no password afterwards.
- `fox` writes the light set; `pfox` the strict set. `pfox` refuses while
  Firefox runs: the settings count at the next start.
- Both sets are defaults: `about:config` wins.

## The check page

`pfox` opens `privacy-check.html` first. A page cannot read the preferences,
so it measures the effects. Expected, strict set:

| Measured | Expected |
| :--- | :--- |
| Time zone | Atlantic/Reykjavik (RFP's UTC+0) |
| Language | en-US |
| User-agent | the plain Firefox one |
| Window a site sees | a multiple of 200 × 100 |
| RTCPeerConnection | undefined |
| Canvas, read twice | random both times |
| Geolocation permission | denied |
| doubleclick.net, example.com as control | blocked |

The footer shows the exit IP, its city and country, and the DNS resolver read
when the window opened. DNS leaks are not testable from a page; raw values:
`about:config`.

## The strict set, day to day

| You will notice | Preference |
| :--- | :--- |
| Pages in English, times in UTC | `privacy.resistFingerprinting` |
| Grey margins around pages | `privacy.resistFingerprinting.letterboxing` |
| A warning page on an http-only site | `dom.security.https_only_mode` |
| Location requests refused | `permissions.default.geo` |
| No calls (Jitsi, Meet) | `media.peerconnection.enabled` |

Firefox's own DoH is off: the DNS is the tunnel's ([the tunnel's page](vpn.md)).

## Removing the pack

`remove_pack` takes the link, the file it points at and the sound preference
back. `~/.mozilla` stays.
