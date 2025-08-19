// lib/auth/access_controller.dart
// ignore_for_file: avoid_print

import 'dart:async'; // for unawaited
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Cross-check with RevenueCat snapshot to avoid false downgrades
import 'package:recipe_vault/billing/subscription_service.dart';

enum EntitlementStatus { checking, active, inactive }

class AccessController extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  EntitlementStatus _status = EntitlementStatus.checking;
  String? _tier;
  bool _ready = false;

  // Keep whether this user ever had access (persists in SharedPreferences)
  bool _everHadAccess = false;

  // ── Public getters used by router/boot screen ─────────────────────────────
  EntitlementStatus get status => _status;
  bool get ready => _ready;
  bool get hasAccess => _status == EntitlementStatus.active;
  String? get tier => _tier;

  bool get isLoggedIn => _auth.currentUser != null;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  // New user = created within the last 12 hours (same window your redirects use)
  static const _newUserWindow = Duration(hours: 12);
  bool get isNewlyRegistered {
    final u = _auth.currentUser;
    final created = u?.metadata.creationTime;
    if (u == null || created == null) return false;
    return DateTime.now().difference(created).abs() <= _newUserWindow;
  }

  bool get everHadAccess => _everHadAccess;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  void start() {
    // Warm RC so we can cross-check entitlement quickly.
    unawaited(SubscriptionService().init());

    _authSub = _auth.authStateChanges().listen((_) {
      scheduleMicrotask(refresh);
    });

    if (_auth.currentUser != null) {
      refresh();
    } else {
      _everHadAccess = false;
      _setState(EntitlementStatus.inactive, tier: null, ready: true);
    }
  }

  /// Public: re-run entitlement checks & (re)attach user doc listener.
  Future<void> refresh() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _userDocSub?.cancel();
      _everHadAccess = false;
      _setState(EntitlementStatus.inactive, tier: null, ready: true);
      return;
    }

    await _loadEverHadAccess();
    _setState(EntitlementStatus.checking, ready: false);
    _listenToUserDoc(user.uid);
  }

  void _listenToUserDoc(String uid) {
    _userDocSub?.cancel();
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snap) async {
            // If Firestore is missing/lagging, don’t downgrade if RC is active.
            if (!snap.exists) {
              final rc = SubscriptionService();
              if (rc.hasActiveSubscription) {
                _setState(EntitlementStatus.active, tier: rc.tier, ready: true);
                _markEverHadAccess(uid);
                debugPrint(
                  '🔁 Firestore missing doc, but RC active → staying ACTIVE (${rc.tier})',
                );
                return;
              }
              _setState(EntitlementStatus.inactive, tier: null, ready: true);
              return;
            }

            final data = snap.data();
            final fsTier = (data?['tier'] ?? 'none') as String;
            final fsActive = fsTier != 'none';

            // Cross-check with current RC snapshot (already warmed by init()).
            final rc = SubscriptionService();
            final rcActive = rc.hasActiveSubscription;
            final rcTier = rc.tier;

            if (!fsActive && rcActive) {
              _setState(EntitlementStatus.active, tier: rcTier, ready: true);
              _markEverHadAccess(uid);
              debugPrint(
                '🛡️ Prevented downgrade: Firestore=none, RC=$rcTier → ACTIVE',
              );
              return;
            }

            if (fsActive && !_everHadAccess) {
              _markEverHadAccess(uid);
            }

            _setState(
              fsActive ? EntitlementStatus.active : EntitlementStatus.inactive,
              tier: fsTier,
              ready: true,
            );
          },
          onError: (e) {
            debugPrint('⚠️ Firestore entitlement error: $e');
            // Be conservative on errors: if RC is active keep access, else inactive.
            final rc = SubscriptionService();
            if (rc.hasActiveSubscription) {
              _setState(EntitlementStatus.active, tier: rc.tier, ready: true);
            } else {
              _setState(EntitlementStatus.inactive, tier: null, ready: true);
            }
          },
        );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _setState(EntitlementStatus s, {String? tier, bool? ready}) {
    final oldStatus = _status;
    final oldTier = _tier;

    _status = s;
    _tier = tier ?? _tier;
    if (ready != null) _ready = ready;

    debugPrint('🔑 Access state → status=$_status, tier=$_tier, ready=$_ready');
    if (oldStatus != _status || oldTier != _tier) {
      debugPrint('🔁 Access flip: $oldStatus/$oldTier → $_status/$_tier');
    }

    _safeNotify();
  }

  void _safeNotify() {
    // Avoid “markNeedsBuild during build”
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!hasListeners) return;
        notifyListeners();
      });
    }
  }

  Future<void> _loadEverHadAccess() async {
    final u = _auth.currentUser;
    if (u == null) {
      _everHadAccess = false;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _everHadAccess = prefs.getBool('everHadAccess_${u.uid}') ?? false;
    } catch (_) {
      _everHadAccess = false;
    }
  }

  Future<void> _markEverHadAccess(String uid) async {
    _everHadAccess = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('everHadAccess_$uid', true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
