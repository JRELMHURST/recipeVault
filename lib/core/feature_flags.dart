// lib/core/feature_flags.dart

/// Centralised feature flags for runtime toggles.
///
/// ⚠️ Note: These are **compile-time constants**. Changing them requires a
/// rebuild of the app. They’re intended for development / staged rollouts,
/// not remote config.
///
/// For dynamic toggles, consider Firebase Remote Config instead.
library;

/// Controls whether onboarding/tutorial bubbles are enabled.
/// If `false`, all bubble/tutorial UI should be skipped.
const bool kOnboardingBubblesEnabled = false;

/// Controls whether the "Daily Tip" banner auto-closes after a timeout.
/// If `false`, only manual close (via buttons) will dismiss it.
const bool kDailyTipAutoCloseEnabled = true;

/// Controls whether debug logs for banners are shown in console.
const bool kDailyTipDebugLogging = true;
