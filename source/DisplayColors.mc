using Toybox.Graphics;

// Alarm background per display type, selected at build time from the SDK's
// per-device bitsPerPixel (see monkey.jungle). Connect IQ exposes no runtime
// API for display color depth, so this is the sanctioned lookup.
(:colorDisplay) const ALERT_BG = Graphics.COLOR_RED;
(:monoDisplay)  const ALERT_BG = Graphics.COLOR_BLACK;
const ALERT_FG = Graphics.COLOR_WHITE;

// Debug-only test mode: the field loops 3 s normal / 2 s alerting so the
// alarm rendering and tone can be checked without simulating speed data.
(:debug) const TEST_MODE = true;
