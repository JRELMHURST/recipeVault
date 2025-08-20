import 'package:flutter/foundation.dart';

/// --- Daily Tip banner behaviour ---
const bool kDailyTipAutoCloseEnabled = bool.fromEnvironment(
  'DAILY_TIP_AUTO_CLOSE',
  defaultValue: true,
);

/// Auto-close delay in milliseconds (only used when kDailyTipAutoCloseEnabled is true).
/// Keep as an int env to stay const-friendly.
const int kDailyTipAutoCloseMs = int.fromEnvironment(
  'DAILY_TIP_AUTO_CLOSE_MS',
  defaultValue: 6000, // 6 seconds
);

/// Debug logging for tip/banner controllers.
const bool kDailyTipDebugLogging = bool.fromEnvironment(
  'DAILY_TIP_DEBUG_LOGGING',
  // Default to true in debug, false otherwise.
  defaultValue: kDebugMode,
);

/// --- Router/paywall guard behaviour ---
/// Keep entitlement hard-gate on by default (matches your router-first design).
const bool kEntitlementHardGateEnabled = bool.fromEnvironment(
  'ENTITLEMENT_HARD_GATE',
  defaultValue: true,
);

/// If true, show a slightly more verbose route-guard log line in debug builds.
const bool kRouterDebugLogs = bool.fromEnvironment(
  'ROUTER_DEBUG_LOGS',
  defaultValue: kDebugMode,
);

/// --- Daily Tip selection ---
/// If true, use per-user seeded rotation so different users get different tips the same day.
const bool kDailyTipSeedByUser = bool.fromEnvironment(
  'DAILY_TIP_SEED_BY_USER',
  defaultValue: true,
);

/// Convenience helpers (non-const) for places that want derived values.
class FeatureFlags {
  FeatureFlags._();

  /// Duration built from kDailyTipAutoCloseMs.
  static Duration get dailyTipAutoCloseDuration =>
      Duration(milliseconds: kDailyTipAutoCloseMs);

  /// Whether we should log verbose details for banners/overlays.
  static bool get tipLogs => kDailyTipDebugLogging && kDebugMode;

  /// Whether we should log router redirect decisions.
  static bool get routerLogs => kRouterDebugLogs && kDebugMode;
}
