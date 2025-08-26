// lib/data/services/usage_service.dart
// Live usage counters (monthly) for the signed-in user.
// Sources:
//   - Firestore: /users/{uid}/{recipeUsage|translatedRecipeUsage|imageUsage}/usage
//
// Notes:
//   • Read-only from client (rules block client writes).
//   • Handles auth changes and signs out safely.
//   • Computes counts for the current YYYY-MM bucket.
//   • Designed to be consumed by UI (e.g., UsageMetricsWidget).

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UsageService extends ChangeNotifier {
  // ── Singleton (optional, mirrors your other services) ─────────────────────
  static final UsageService _instance = UsageService._internal();
  factory UsageService() => _instance;
  UsageService._internal();

  // ── Deps ─────────────────────────────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // ── State ────────────────────────────────────────────────────────────────
  String? _uid; // current user for which listeners are attached
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _recipeSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _translatedSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _imageSub;
  StreamSubscription<User?>? _authSub;

  // Current YYYY-MM key (should match backend’s usage_service.ts)
  String get _monthKey {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    return '${now.year}-$m';
  }

  // Exposed usage counters (current month)
  int _recipesUsed = 0;
  int _translatedRecipesUsed = 0;
  int _imagesUsed = 0;

  // For consumers
  int get recipesUsed => _recipesUsed;
  int get translatedRecipesUsed => _translatedRecipesUsed;
  int get imagesUsed => _imagesUsed;

  bool _initialised = false;
  bool get isInitialised => _initialised;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // Attach to current auth state first.
    _applyUser(_auth.currentUser);

    // Listen for future auth changes to switch listeners seamlessly.
    _authSub = _auth.authStateChanges().listen(
      _applyUser,
      onError: (e) => _log('⚠️ authStateChanges error: $e'),
    );
  }

  @override
  void dispose() {
    _detachAll();
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }

  // ── Public helpers ───────────────────────────────────────────────────────
  /// Force a one-shot refresh (reads docs once). Usually not needed because
  /// snapshot listeners will push updates, but handy right after a callable
  /// that incremented usage to reflect counts immediately.
  Future<void> refreshOnce() async {
    final uid = _uid;
    if (uid == null) return;
    await Future.wait([
      _readOnce(uid, 'recipeUsage').then((v) {
        if (v != _recipesUsed) {
          _recipesUsed = v;
          notifyListeners();
        }
      }),
      _readOnce(uid, 'translatedRecipeUsage').then((v) {
        if (v != _translatedRecipesUsed) {
          _translatedRecipesUsed = v;
          notifyListeners();
        }
      }),
      _readOnce(uid, 'imageUsage').then((v) {
        if (v != _imagesUsed) {
          _imagesUsed = v;
          notifyListeners();
        }
      }),
    ]);
  }

  // ── Internals ────────────────────────────────────────────────────────────
  void _applyUser(User? user) {
    // If user unchanged, ignore.
    final nextUid = (user == null || user.isAnonymous) ? null : user.uid;
    if (_uid == nextUid) return;

    // Switch listeners safely.
    _detachAll();
    _uid = nextUid;

    if (_uid == null) {
      // Signed out → zero everything so UI hides/clears promptly.
      _recipesUsed = 0;
      _translatedRecipesUsed = 0;
      _imagesUsed = 0;
      notifyListeners();
      _log('📴 UsageService detached (signed out).');
      return;
    }

    // Attach for new user.
    _attachForUser(_uid!);
  }

  void _attachForUser(String uid) {
    _log('📡 UsageService attaching usage listeners for $uid');

    _recipeSub = _usageDoc(uid, 'recipeUsage').snapshots().listen(
      (snap) {
        final v = _extractMonthValue(snap);
        if (v != _recipesUsed) {
          _recipesUsed = v;
          notifyListeners();
        }
      },
      onError: (e) {
        // Ignore permission-denied on sign-out race.
        _log('⚠️ recipeUsage stream error: $e');
      },
    );

    _translatedSub = _usageDoc(uid, 'translatedRecipeUsage').snapshots().listen(
      (snap) {
        final v = _extractMonthValue(snap);
        if (v != _translatedRecipesUsed) {
          _translatedRecipesUsed = v;
          notifyListeners();
        }
      },
      onError: (e) {
        _log('⚠️ translatedRecipeUsage stream error: $e');
      },
    );

    _imageSub = _usageDoc(uid, 'imageUsage').snapshots().listen(
      (snap) {
        final v = _extractMonthValue(snap);
        if (v != _imagesUsed) {
          _imagesUsed = v;
          notifyListeners();
        }
      },
      onError: (e) {
        _log('⚠️ imageUsage stream error: $e');
      },
    );
  }

  void _detachAll() {
    _recipeSub?.cancel();
    _translatedSub?.cancel();
    _imageSub?.cancel();
    _recipeSub = null;
    _translatedSub = null;
    _imageSub = null;
  }

  DocumentReference<Map<String, dynamic>> _usageDoc(String uid, String kind) {
    return _fs.collection('users').doc(uid).collection(kind).doc('usage');
  }

  int _extractMonthValue(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return 0;
    final data = snap.data();
    if (data == null) return 0;
    final raw = data[_monthKey];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  Future<int> _readOnce(String uid, String kind) async {
    try {
      final snap = await _usageDoc(uid, kind).get();
      return _extractMonthValue(snap);
    } catch (e) {
      _log('⚠️ one-shot read error [$kind]: $e');
      return 0;
    }
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('📊 [UsageService] $msg');
  }
}
