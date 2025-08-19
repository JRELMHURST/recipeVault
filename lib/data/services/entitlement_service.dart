import 'package:cloud_firestore/cloud_firestore.dart';

class Entitlement {
  final String tier; // 'none' | 'home_chef' | 'master_chef'
  final String? productId;
  final String? status; // 'active' | 'expired' | 'none' (optional if you add)
  final Timestamp? graceUntil;

  Entitlement({
    required this.tier,
    this.productId,
    this.status,
    this.graceUntil,
  });

  factory Entitlement.from(Map<String, dynamic>? d) {
    final data = d ?? const {};
    return Entitlement(
      tier: (data['tier'] ?? 'none') as String,
      productId: data['productId'] as String?,
      status: data['entitlementStatus'] as String?,
      graceUntil: data['graceUntil'] as Timestamp?,
    );
  }
}

Stream<Entitlement> watchEntitlement(String uid) {
  return FirebaseFirestore.instance
      .doc('users/$uid')
      .snapshots()
      .map((snap) => Entitlement.from(snap.data()));
}
