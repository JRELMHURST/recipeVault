import 'dart:async';
import 'package:flutter/foundation.dart';
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

  EntitlementStatus get status => _status;
  bool get ready => _ready;
  bool get hasAccess => _status == EntitlementStatus.active;
  String? get tier => _tier;

  void start() {
    _authSub = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        _setState(EntitlementStatus.inactive, tier: null, ready: true);
        _userDocSub?.cancel();
        return;
      }
      _setState(EntitlementStatus.checking, tier: null, ready: false);
      _listenToUserDoc(user.uid);
      await _refreshFromRevenueCat();
    });

    Purchases.addCustomerInfoUpdateListener(_applyCustomerInfo);

    if (_auth.currentUser != null) {
      _listenToUserDoc(_auth.currentUser!.uid);
      _refreshFromRevenueCat();
    }
  }

  void _listenToUserDoc(String uid) {
    _userDocSub?.cancel();
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
          final data = snap.data();
          final docTier = (data?['Tier'] ?? data?['tier']) as String?;
          if (_status != EntitlementStatus.active) {
            if (docTier == null || docTier == 'none') {
              _setState(EntitlementStatus.inactive, tier: null, ready: true);
            } else {
              _setState(EntitlementStatus.active, tier: docTier, ready: true);
            }
          } else {
            if (docTier != null && docTier != 'none') {
              _tier = docTier;
              notifyListeners();
            }
          }
        });
  }

  Future<void> _refreshFromRevenueCat() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _applyCustomerInfo(info);
    } catch (_) {
      _ready = true;
      notifyListeners();
    }
  }

  void _applyCustomerInfo(CustomerInfo info) {
    final active = info.entitlements.active;
    if (active.isEmpty) {
      _setState(EntitlementStatus.inactive, tier: null, ready: true);
      return;
    }
    final keys = active.keys.map((k) => k.toLowerCase()).toList();
    String resolvedTier = 'home_chef';
    if (keys.any((k) => k.contains('master'))) resolvedTier = 'master_chef';
    _setState(EntitlementStatus.active, tier: resolvedTier, ready: true);
  }

  void _setState(EntitlementStatus s, {String? tier, bool? ready}) {
    _status = s;
    _tier = tier ?? _tier;
    if (ready != null) _ready = ready;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
