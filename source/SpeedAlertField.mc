using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Attention;
using Toybox.Application;

class SpeedAlertField extends WatchUi.DataField {

    private const MPS_TO_KMH = 3.6;
    private const MPS_TO_MPH = 2.236936;
    // compute() runs at 1 Hz; the guard tolerates minor tick jitter while
    // still preventing a second tone inside the same tick.
    private const TONE_MIN_INTERVAL_MS = 900;

    private var _label;
    private var _unitTop = "km";
    private var _unitFactor = MPS_TO_KMH;
    private var _thresholdMps = 40.0 / 3.6;
    private var _thresholdTime = 5;

    private var _overCount = 0;
    private var _alerting = false;
    private var _lastToneMs = null;
    private var _speedText = "0.0";

    function initialize() {
        DataField.initialize();
        _label = WatchUi.loadResource(Rez.Strings.SpeedLabel).toUpper();
        loadSettings();
    }

    // Re-read properties and unit setting; also called from
    // AppBase.onSettingsChanged when the user edits settings mid-ride.
    function loadSettings() {
        var units = System.getDeviceSettings().paceUnits;
        var statute = (units == System.UNIT_STATUTE);
        _unitFactor = statute ? MPS_TO_MPH : MPS_TO_KMH;
        _unitTop = statute ? "mp" : "km";

        var speed = readNumber("thresholdSpeed", 40.0);
        var time = readNumber("thresholdTime", 5);
        _thresholdMps = speed.toFloat() / _unitFactor;
        _thresholdTime = time.toNumber();
        _overCount = 0;
        _alerting = false;
    }

    private function readNumber(key, fallback) {
        var value = null;
        try {
            value = Application.Properties.getValue(key);
        } catch (e) {
            value = null;
        }
        if (value == null || !(value instanceof Toybox.Lang.Number
                || value instanceof Toybox.Lang.Float
                || value instanceof Toybox.Lang.Long
                || value instanceof Toybox.Lang.Double)) {
            return fallback;
        }
        return value;
    }

    function compute(info) {
        var speedMps = 0.0;
        if (info has :currentSpeed && info.currentSpeed != null) {
            speedMps = info.currentSpeed;
        }

        var display = speedMps * _unitFactor;
        _speedText = display.format(display >= 100 ? "%.0f" : "%.1f");

        if (speedMps > _thresholdMps) {
            _overCount++;
            if (_overCount > _thresholdTime) {
                _alerting = true;
            }
        } else {
            _overCount = 0;
            _alerting = false;
        }

        applyTestMode();
        debugLogCompute(speedMps);

        if (_alerting) {
            var now = System.getTimer();
            if (_lastToneMs == null || now - _lastToneMs >= TONE_MIN_INTERVAL_MS
                    || now < _lastToneMs) {
                if (Attention has :playTone) {
                    Attention.playTone(Attention.TONE_CANARY);
                    debugLogTone(true);
                } else {
                    debugLogTone(false);
                }
                _lastToneMs = now;
            }
        } else {
            _lastToneMs = null;
        }

        return null;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var bg;
        var fg;
        if (_alerting) {
            bg = $.ALERT_BG;
            fg = $.ALERT_FG;
        } else {
            bg = getBackgroundColor();
            fg = (bg == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        }

        dc.setColor(fg, bg);
        dc.clear();
        // Transparent text background — otherwise each drawText fills its
        // box and the overlapping "km"/"h" stack clips the h's ascender.
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);

        // Header font matches native per generation: Roboto glance font on
        // API 4.0+ Edges, condensed FONT_SMALL on older ones.
        var labelFont;
        if (Graphics has :createBufferedBitmap && Graphics has :FONT_GLANCE) {
            labelFont = Graphics.FONT_GLANCE;
        } else {
            labelFont = (h < 60) ? Graphics.FONT_XTINY : Graphics.FONT_SMALL;
        }
        var labelH = dc.getFontHeight(labelFont);
        dc.drawText(w / 2, labelH * 0.55, labelFont, _label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Unit stack ("km" over "h", or "mp" over "h") sits right of the value
        var unitFont = (h < 60) ? Graphics.FONT_XTINY : Graphics.FONT_TINY;
        var unitH = dc.getFontHeight(unitFont);
        var unitAscent = fontAscent(unitFont, unitH);
        var topW = dc.getTextWidthInPixels(_unitTop, unitFont);
        var botW = dc.getTextWidthInPixels("h", unitFont);
        var unitW = (topW > botW) ? topW : botW;
        var gap = (w > 200) ? 4 : 2;

        var valueFont = pickValueFont(dc, _speedText,
            w * 0.92 - unitW - gap, h - labelH);
        var valW = dc.getTextWidthInPixels(_speedText, valueFont);
        var valH = dc.getFontHeight(valueFont);
        var valY = labelH + (h - labelH) / 2;
        var x0 = (w - (valW + gap + unitW)) / 2;

        dc.drawText(x0, valY, valueFont, _speedText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bottom of "h" lands on the digit baseline, "km"/"mp" stacked above
        var baseline = valY - valH / 2 + fontAscent(valueFont, valH);
        var unitX = x0 + valW + gap;
        dc.drawText(unitX, baseline - unitAscent, unitFont, "h",
            Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(unitX, baseline - unitAscent - unitH * 0.85, unitFont,
            _unitTop, Graphics.TEXT_JUSTIFY_LEFT);

        debugDumpLayout(dc, w, h, labelH, unitFont, unitW, gap);
    }

    // Test mode (debug builds only): loop 3 s normal field, 2 s alerting.
    // Compiled out of release builds entirely.
    (:debug) private var _testTick = -1;

    (:release) private function applyTestMode() {
    }

    (:debug) private function applyTestMode() {
        if (!TEST_MODE) {
            return;
        }
        _testTick = (_testTick + 1) % 5;
        _alerting = (_testTick >= 3);
        if (_alerting) {
            _speedText = (_thresholdMps * _unitFactor + 5.0).format("%.1f");
        }
        System.println("TESTMODE tick=" + _testTick + " alerting=" + _alerting);
    }

    (:release) private function debugLogCompute(speedMps) {
    }

    (:debug) private function debugLogCompute(speedMps) {
        System.println("COMPUTE speed=" + speedMps + " thrMps=" + _thresholdMps
            + " thrTime=" + _thresholdTime + " over=" + _overCount
            + " alerting=" + _alerting);
    }

    (:release) private function debugLogTone(played) {
    }

    (:debug) private function debugLogTone(played) {
        System.println(played ? "TONE played" : "TONE unavailable (has :playTone false)");
    }

    (:release) private function debugDumpLayout(dc, w, h, labelH, unitFont, unitW, gap) {
    }

    (:debug) private function debugDumpLayout(dc, w, h, labelH, unitFont, unitW, gap) {
        var samples = ["0.0", "14.2", "88.8", "888"];
        for (var i = 0; i < samples.size(); i++) {
            var t = samples[i];
            var f = pickValueFont(dc, t, w * 0.92 - unitW - gap, h - labelH);
            var vw = dc.getTextWidthInPixels(t, f);
            var vh = dc.getFontHeight(f);
            var vy = labelH + (h - labelH) / 2;
            var x0 = (w - (vw + gap + unitW)) / 2;
            var bl = vy - vh / 2 + fontAscent(f, vh);
            var uh = dc.getFontHeight(unitFont);
            var ua = fontAscent(unitFont, uh);
            var unitTopY = bl - ua - uh * 0.85;
            System.println("LAYOUT " + t + " w=" + w + " h=" + h
                + " labelH=" + labelH + " valW=" + vw + " valH=" + vh
                + " x0=" + x0 + " right=" + (x0 + vw + gap + unitW)
                + " valTop=" + (vy - vh / 2) + " valBot=" + (vy + vh / 2)
                + " baseline=" + bl + " unitTopY=" + unitTopY);
        }
    }

    // Graphics.getFontAscent is a module function from CIQ 3.1; on the 2.4
    // Edge 520/1000/820 variants fall back to ~80% of the font box.
    private function fontAscent(font, fontHeight) {
        if (Graphics has :getFontAscent) {
            return Graphics.getFontAscent(font);
        }
        return fontHeight * 0.8;
    }

    // Largest number font that fits the width and remaining height. Ranked by
    // measured digit width, not enum order — built-in sizes vary per device.
    private function pickValueFont(dc, text, maxWidth, maxHeight) {
        var fonts = [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD, Graphics.FONT_MEDIUM, Graphics.FONT_TINY];
        var best = null;
        var bestDigit = -1;
        for (var i = 0; i < fonts.size(); i++) {
            var f = fonts[i];
            if (dc.getTextWidthInPixels(text, f) <= maxWidth
                    && dc.getFontHeight(f) <= maxHeight) {
                var digit = dc.getTextWidthInPixels("0", f);
                if (digit > bestDigit) {
                    bestDigit = digit;
                    best = f;
                }
            }
        }
        return (best != null) ? best : Graphics.FONT_XTINY;
    }
}
