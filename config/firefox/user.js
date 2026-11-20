// Preferences the Firefox theme needs. Firefox reads user.js at startup and
// copies the values into prefs.js; it never writes user.js itself, which is why
// a symlink into the repo is safe here (unlike prefs.js, which is state).

// Without this, Firefox ignores userChrome.css and userContent.css entirely.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Dark chrome and dark content, so the CSS is not fighting a light theme.
user_pref("browser.theme.content-theme", 0);
user_pref("browser.theme.toolbar-theme", 0);

// Websites that support it get their dark variant, which is what the palette
// expects; the content theme alone does not tell pages we prefer dark.
user_pref("layout.css.prefers-color-scheme.content-override", 0);

// Compact density, the same instinct as the bar's 28 px pills.
user_pref("browser.uidensity", 1);
user_pref("browser.compactmode.show", true);

// Hardware video decoding. vainfo on this Vega 8 lists H.264, HEVC and VP9
// (profile 0 and 2) but no AV1, so Twitch/YouTube in H.264 or VP9 can be
// decoded by the GPU and AV1 cannot. Off by default in Firefox on Linux, and
// the HUD's video-engine row is how it is verified: it sits at 0 % while the
// CPU burns on the same stream.
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.rdd-ffmpeg.enabled", true);
