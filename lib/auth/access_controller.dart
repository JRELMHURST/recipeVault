// ignore_for_file: avoid_print

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EntitlementStatus { checking, active, inactive }

class AccessController extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  EntitlementStatus _status = EntitlementStatus.checking;
  String? _tier;
  bool _ready = false;

  // Persistence: has this user ever had access?
  bool _everHadAccess = false;

  // ── Public getters ─────────────────────────────────────────────
  EntitlementStatus get status => _status;
  bool get ready => _ready;
  bool get hasAccess => _status == EntitlementStatus.active;
  String? get tier => _tier;

  bool get isLoggedIn => _auth.currentUser != null;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  // New user = created within last 12 hours
  static const _newUserWindow = Duration(hours: 12);
  bool get isNewlyRegistered {
    final u = _auth.currentUser;
    final created = u?.metadata.creationTime;
    if (u == null || created == null) return false;
    return DateTime.now().difference(created).abs() <= _newUserWindow;
  }

  bool get everHadAccess => _everHadAccess;

  // ── Lifecycle ──────────────────────────────────────────────────
  void start() {
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

  /// Public: re-run entitlement checks & user doc listener.
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
          (snap) {
            if (!snap.exists) {
              _setState(EntitlementStatus.inactive, tier: null, ready: true);
              return;
            }

            final data = snap.data();
            final tier = (data?['tier'] ?? 'none') as String;
            final isActive = tier != 'none';

            if (isActive && !_everHadAccess) {
              _everHadAccess = true;
              _saveEverHadAccess(uid);
            }

            _setState(
              isActive ? EntitlementStatus.active : EntitlementStatus.inactive,
              tier: tier,
              ready: true,
            );
          },
          onError: (e) {
            debugPrint('⚠️ Firestore entitlement error: $e');
            _setState(EntitlementStatus.inactive, tier: null, ready: true);
          },
        );
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

  Future<void> _saveEverHadAccess(String uid) async {
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
