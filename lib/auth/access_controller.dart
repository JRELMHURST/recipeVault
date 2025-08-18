// lib/access_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum EntitlementStatus { checking, active, inactive }

class AccessController extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  EntitlementStatus _status = EntitlementStatus.checking;
  String? _tier;
  bool _ready = false;

  // Track whether each source has produced a result this cycle
  bool _rcResolved = false;
  bool _fsResolved = false;

  // Public
  EntitlementStatus get status => _status;
  bool get ready => _ready;
  bool get hasAccess => _status == EntitlementStatus.active;

  /// NEW: Whether an authenticated Firebase user exists.
  bool get isLoggedIn => _auth.currentUser != null;

  String? get tier => _tier;

  /// Call once at app start (e.g., in your top-level Provider setup).
  void start() {
    // Re-check whenever auth state changes.
    _authSub = _auth.authStateChanges().listen((_) {
      // Defer to next microtask so we don't notify during build.
      scheduleMicrotask(refresh);
    });

    // RevenueCat pushes updates
    Purchases.addCustomerInfoUpdateListener(_applyCustomerInfo);

    // Initial kick
    if (_auth.currentUser != null) {
      refresh();
    } else {
      // Not logged in: no entitlement checks; app can route to /login.
      _setState(EntitlementStatus.inactive, tier: null, ready: true);
    }
  }

  /// Public: re-run entitlement checks & user doc listener.
  Future<void> refresh() async {
    // Reset resolution flags for this cycle
    _rcResolved = false;
    _fsResolved = false;

    final user = _auth.currentUser;
    if (user == null) {
      await _userDocSub?.cancel();
      _setState(EntitlementStatus.inactive, tier: null, ready: true);
      return;
    }

    _setState(EntitlementStatus.checking, ready: false);

    // If Firestore never emits or RC throws, never hang: fallback after 3s
    unawaited(
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!_ready && _status == EntitlementStatus.checking) {
          debugPrint('⏱️ AccessController fallback timeout → marking ready.');
          _setState(
            hasAccess ? EntitlementStatus.active : EntitlementStatus.inactive,
            tier: _tier,
            ready: true,
          );
        }
      }),
    );

    _listenToUserDoc(user.uid);
    unawaited(_refreshFromRevenueCat());
  }

  void _listenToUserDoc(String uid) {
    _userDocSub?.cancel();
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snap) {
            final data = snap.data();
            final docTier = (data?['Tier'] ?? data?['tier']) as String?;

            _fsResolved = true;

            // If Firestore says no tier -> inactive; else active with tier.
            if (docTier == null || docTier == 'none') {
              _setState(EntitlementStatus.inactive, tier: null);
            } else {
              _setState(EntitlementStatus.active, tier: docTier);
            }
            _maybeMarkReady('firestore');
          },
          onError: (e) {
            debugPrint('⚠️ Firestore access check error: $e');
            _fsResolved = true;
            // Don’t block the app on errors.
            _maybeMarkReady('firestore-error');
          },
        );
  }

  Future<void> _refreshFromRevenueCat() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _applyCustomerInfo(info);
    } catch (e) {
      debugPrint('⚠️ RevenueCat getCustomerInfo failed: $e');
      _rcResolved = true;
      _maybeMarkReady('rc-error');
    }
  }

  void _applyCustomerInfo(CustomerInfo info) {
    _rcResolved = true;

    // If RC finds any active entitlement, prefer "active".
    final active = info.entitlements.active;
    if (active.isNotEmpty) {
      final keys = active.keys.map((k) => k.toLowerCase()).toList();
      String resolvedTier = 'home_chef';
      if (keys.any((k) => k.contains('master'))) resolvedTier = 'master_chef';
      _setState(EntitlementStatus.active, tier: resolvedTier);
    }

    _maybeMarkReady('rc');
  }

  void _maybeMarkReady(String source) {
    // Mark ready as soon as at least ONE source answered.
    if (!_ready && (_fsResolved || _rcResolved)) {
      debugPrint(
        '✅ AccessController ready via $source '
        '(rc=$_rcResolved, fs=$_fsResolved) → status=$_status, tier=$_tier',
      );
      _setState(_status, tier: _tier, ready: true);
    }
  }

  void _setState(EntitlementStatus s, {String? tier, bool? ready}) {
    _status = s;
    _tier = tier ?? _tier;
    if (ready != null) _ready = ready;

    debugPrint('🔑 Access state → status=$_status, tier=$_tier, ready=$_ready');

    _safeNotify();
  }

  // Avoid "notify during build" crashes.
  void _safeNotify() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!hasListeners) return;
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
