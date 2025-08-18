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

  // Source resolution flags
  bool _rcResolved = false;

  // Source opinions
  bool _rcActive = false;
  String? _rcTier;
  String? _fsTier;

  // Persisted flag: has this user ever had an active entitlement?
  bool _everHadAccess = false;

  // ── Public getters ────────────────────────────────────────────────────────
  EntitlementStatus get status => _status;
  bool get ready => _ready;
  bool get hasAccess => _status == EntitlementStatus.active;
  String? get tier => _tier;

  bool get isLoggedIn => _auth.currentUser != null;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

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
    _authSub = _auth.authStateChanges().listen((_) {
      scheduleMicrotask(refresh);
    });

    Purchases.addCustomerInfoUpdateListener(_applyCustomerInfo);

    if (_auth.currentUser != null) {
      // Ensure RC identity matches Firebase UID before the first fetch
      _ensureRcIdentity().then((_) => refresh());
    } else {
      _everHadAccess = false;
      _setState(EntitlementStatus.inactive, tier: null, ready: true);
    }
  }

  /// Public: re-run entitlement checks & user doc listener.
  Future<void> refresh() async {
    _rcResolved = false;
    _rcActive = false;
    _rcTier = null;
    _fsTier = null;

    final user = _auth.currentUser;
    if (user == null) {
      await _userDocSub?.cancel();
      _everHadAccess = false;
      _setState(EntitlementStatus.inactive, tier: null, ready: true);
      return;
    }

    // Hydrate optimistic tier from cache (sticky across restarts).
    await _loadCachedTier(uid: user.uid);

    await _loadEverHadAccess();
    _setState(EntitlementStatus.checking, ready: false);

    // Fallback so UI never hangs forever if neither source returns.
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
            _fsTier = (data?['Tier'] ?? data?['tier']) as String?;

            // NOTE: don't setState here; decide in _resolveEntitlement()
            _resolveEntitlement(uid: uid);
          },
          onError: (e) {
            debugPrint('⚠️ Firestore access check error: $e');
            _resolveEntitlement(uid: uid);
          },
        );
  }

  Future<void> _refreshFromRevenueCat() async {
    try {
      // 🔒 Ensure RC identity matches Firebase UID
      await _ensureRcIdentity();

      final info = await Purchases.getCustomerInfo();
      _applyCustomerInfo(info);
    } catch (e) {
      debugPrint('⚠️ RevenueCat getCustomerInfo failed: $e');
      _rcResolved = true;
      _resolveEntitlement(uid: _auth.currentUser?.uid);
    }
  }

  /// Make sure RC is logged in with the same UID as FirebaseAuth
  Future<void> _ensureRcIdentity() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final appUserId = await Purchases.appUserID; // ✅ getter
      final isAnon = await Purchases.isAnonymous; // ✅ getter

      if (isAnon || appUserId != user.uid) {
        debugPrint(
          '🔄 RC identity mismatch (had=$appUserId, want=${user.uid}) → logging in',
        );
        await Purchases.logIn(user.uid);
        await Purchases.invalidateCustomerInfoCache();
      }
    } catch (e) {
      debugPrint('⚠️ _ensureRcIdentity failed: $e');
    }
  }

  void _applyCustomerInfo(CustomerInfo info) {
    _rcResolved = true;

    final active = info.entitlements.active;
    if (active.isNotEmpty) {
      final keys = active.keys.map((k) => k.toLowerCase()).toList();
      _rcActive = true;
      _rcTier = keys.any((k) => k.contains('master'))
          ? 'master_chef'
          : 'home_chef';

      if (!_everHadAccess) {
        _everHadAccess = true;
        unawaited(_saveEverHadAccess());
      }
    } else {
      _rcActive = false;
      _rcTier = null;
    }

    _resolveEntitlement(uid: _auth.currentUser?.uid);
  }

  /// Final decision-maker combining RC + Firestore with RC-first policy.
  void _resolveEntitlement({String? uid}) {
    // 1) RC says active → ACTIVE wins immediately.
    if (_rcActive) {
      _setState(EntitlementStatus.active, tier: _rcTier, ready: true);
      unawaited(_saveCachedTier(uid: uid, tier: _rcTier));
      return;
    }

    // 2) RC not resolved yet → keep checking; do NOT downgrade from Firestore=none.
    if (!_rcResolved) {
      _setState(EntitlementStatus.checking, tier: _tier, ready: false);
      return;
    }

    // 3) RC resolved and not active → fall back to Firestore tier.
    final fsActive = _fsTier != null && _fsTier != 'none';
    if (fsActive) {
      _setState(EntitlementStatus.active, tier: _fsTier, ready: true);
      unawaited(_saveCachedTier(uid: uid, tier: _fsTier));
      return;
    }

    // 4) Neither source shows access → inactive.
    _setState(EntitlementStatus.inactive, tier: null, ready: true);
    unawaited(_saveCachedTier(uid: uid, tier: 'none'));
  }

  void _setState(EntitlementStatus s, {String? tier, bool? ready}) {
    _status = s;
    _tier = tier ?? _tier;
    if (ready != null) _ready = ready;

    debugPrint('🔑 Access state → status=$_status, tier=$_tier, ready=$_ready');
    _safeNotify();
  }

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

  // ── Persistence helpers ───────────────────────────────────────────────────
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

  Future<void> _loadCachedTier({required String uid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('tier_$uid');
      if (cached != null && cached != 'none') {
        // Optimistically surface last known tier while we check RC.
        _tier = cached;
        _status = EntitlementStatus.checking; // still verifying
        _safeNotify();
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load cached tier: $e');
    }
  }

  Future<void> _saveCachedTier({
    required String? uid,
    required String? tier,
  }) async {
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tier_$uid', tier ?? 'none');
    } catch (e) {
      debugPrint('⚠️ Failed to save cached tier: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
