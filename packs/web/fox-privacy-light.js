// The web pack's LIGHT privacy settings - what `fox` puts in place, and what
// the pack's install leaves there. Nothing in this set is noticed day to day:
// no anti-fingerprinting (no English pages, no UTC, no letterboxing) and no
// WebRTC switch - those two are the strict set, which `pfox` (and `gmake
// fox_tweak_on`) puts in place instead. Defaults, not orders: a value set in
// about:config wins over them. The full story is in docs/fox.md.

// --- Tracking protection: the Strict preset, named pref by pref ---
// (the category line is what the Settings page shows; the engines read the
// prefs, so both are set)
pref("browser.contentblocking.category", "strict");
pref("privacy.trackingprotection.enabled", true);
pref("privacy.trackingprotection.fingerprinting.enabled", true);
pref("privacy.trackingprotection.cryptomining.enabled", true);
pref("privacy.trackingprotection.socialtracking.enabled", true);
pref("privacy.trackingprotection.emailtracking.enabled", true);

// --- Tracking parameters stripped from URLs, in every window ---
pref("privacy.query_stripping.enabled", true);
pref("privacy.query_stripping.enabled.pbmode", true);

// --- Clicks and pages that would phone home ---
pref("browser.send_pings", false);
pref("beacon.enabled", false);

// --- Connections a page did not ask for ---
pref("network.prefetch-next", false);
pref("network.dns.disablePrefetch", true);

// --- TLS and DNS ---
// HTTPS-only in every window: a site served over plain http gets a warning
// page with a way through. DoH is off on purpose - the DNS of this instance is
// the tunnel's business (docs/vpn.md), and Firefox answering it itself would
// step around the tunnel.
pref("dom.security.https_only_mode", true);
pref("network.trr.mode", 5);

// --- What a page may read of the machine ---
// No camera/microphone enumeration (WSLg serves neither), and geolocation
// denied by default - one site can still be allowed through the padlock.
pref("media.navigator.enabled", false);
pref("permissions.default.geo", 2);

// --- Telemetry, studies, and the do-not-sell signal ---
pref("datareporting.healthreport.uploadEnabled", false);
pref("app.shield.optoutstudies.enabled", false);
pref("privacy.globalprivacycontrol.enabled", true);
