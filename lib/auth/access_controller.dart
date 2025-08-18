// ignore_for_file: avoid_print

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Persisted flag: has this user ever had an active entitlement?
  bool _everHadAccess = false;

  // ── Public getters ────────────────────────────────────────────────────────
  EntitlementStatus get status => _status;
  bool get ready => _ready;
  bool get hasAccess => _status == EntitlementStatus.active;
  String? get tier => _tier;

  /// Whether an authenticated Firebase user exists.
  bool get isLoggedIn => _auth.currentUser != null;

  /// Whether the current user is anonymous.
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  /// Treat a user as “newly registered” for a short window after account creation.
  static const _newUserWindow = Duration(hours: 12);
  bool get isNewlyRegistered {
    final u = _auth.currentUser;
    final created = u?.metadata.creationTime;
    if (u == null || created == null) return false;
    final now = DateTime.now();
    return now.difference(created).abs() <= _newUserWindow;
  }

  bool get everHadAccess => _everHadAccess;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
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
      _everHadAccess = false;
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
      _everHadAccess = false;
      _setState(EntitlementStatus.inactive, tier: null, ready: true);
      return;
    }

    await _loadEverHadAccess(); // load persisted “ever had” flag for this uid
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

            if (docTier == null || docTier == 'none') {
              // No entitlement from Firestore.
              _setState(EntitlementStatus.inactive, tier: null);
            } else {
              // Firestore says they have a tier → mark active.
              _setState(EntitlementStatus.active, tier: docTier);
              if (!_everHadAccess) {
                _everHadAccess = true;
                unawaited(_saveEverHadAccess());
              }
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

      if (!_everHadAccess) {
        _everHadAccess = true;
        unawaited(_saveEverHadAccess());
      }
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

  // ── Persistence for "ever had access" ─────────────────────────────────────
  Future<void> _loadEverHadAccess() async {
    final u = _auth.currentUser;
    if (u == null) {
      _everHadAccess = false;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _everHadAccess = prefs.getBool('everHadAccess_${u.uid}') ?? false;
    } catch (e) {
      debugPrint('⚠️ Failed to load everHadAccess: $e');
      _everHadAccess = false;
    }
  }

  Future<void> _saveEverHadAccess() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('everHadAccess_${u.uid}', true);
    } catch (e) {
      debugPrint('⚠️ Failed to save everHadAccess: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
