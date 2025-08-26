import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UsageRepo {
  final FirebaseFirestore firestore;
  UsageRepo(this.firestore);

  Future<Map<String, Map<String, int>>> loadAll(String uid) async {
    final kinds = ['recipeUsage', 'translatedRecipeUsage', 'imageUsage'];
    final result = <String, Map<String, int>>{};
    for (final k in kinds) {
      try {
        final snap = await firestore
            .collection('users')
            .doc(uid)
            .collection(k)
            .doc('usage')
            .get();
        result[k] = Map<String, int>.from(snap.data() ?? {});
      } catch (e) {
        debugPrint('⚠️ Failed to load $k: $e');
        result[k] = {};
      }
    }
    return result;
  }

  Future<Map<String, int>> loadTierLimits(String tier) async {
    if (tier.isEmpty || tier == 'none') {
      return {'recipeUsage': 0, 'translatedRecipeUsage': 0, 'imageUsage': 0};
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('tierLimits')
          .doc(tier)
          .get();
      if (!snap.exists) return {};
      return Map<String, int>.from(snap.data() ?? {});
    } catch (_) {
      return {};
    }
  }
}
