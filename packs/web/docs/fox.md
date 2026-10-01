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
| :--- | :--- | :--- |
| In it | tracking protection, URL cleaning, pings and prefetch off, HTTPS-only, DoH off, telemetry off, geolocation denied, dark interface | light **plus** anti-fingerprinting and WebRTC off |
| You notice | nothing | [the table below](#the-strict-set-day-to-day) |

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

## The preferences

**Light set** — the Strict tracking preset (trackers, fingerprinters,
cryptominers, social trackers, email pixels), URL tracking parameters stripped
in every window, pings and Beacon off, no prefetch, HTTPS-only, DoH off, no
camera/microphone enumeration, geolocation denied by default, telemetry and
studies off, GPC on, dark interface.

**Strict set adds** — `privacy.resistFingerprinting` with
`privacy.resistFingerprinting.letterboxing` (UTC/en-US, generic user-agent,
canvas noise, standard window sizes), and `media.peerconnection.enabled`
false.

## uBlock Origin

Not in the sets. Two clicks from
[addons.mozilla.org](https://addons.mozilla.org/firefox/addon/ublock-origin/);
then in its dashboard: *AdGuard Tracking Protection*, the malware/phishing
lists, *uBlock filters - Annoyances*, *AdGuard - Cookie Notices*, *Fanboy's
Social Blocking List*, and *Settings → Uncloak canonical names*. With
Firefox's URL cleaner, that covers what ClearURLs did.

## Removing the pack

`remove_pack` takes the link, the file it points at and the sound preference
back. `~/.mozilla` stays.
