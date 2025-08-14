// ignore_for_file: unnecessary_null_comparison

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/recipe_card_model.dart';

class RecipeService {
  static final _firestore = FirebaseFirestore.instance;
  static const _globalCollection = 'global_recipes';

  /// Returns the merged recipe list:
  /// - Global recipes (excluding user's hidden globals)
  /// - User recipes
  /// - If IDs clash, user recipe overrides the global one
  /// - Sorted by `createdAt` desc (when available)
  static Future<List<RecipeCardModel>> getAllRecipes({int? limit}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    try {
      // 1) Hidden global IDs for this user
      final hiddenSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('hiddenGlobalRecipes')
          .get();
      final hiddenIds = hiddenSnap.docs.map((d) => d.id).toSet();

      // 2) Global recipes (ordered if possible)
      Query<Map<String, dynamic>> globalQuery = _firestore.collection(
        _globalCollection,
      );
      // Only order when field exists for most docs; Firestore is OK even if some missing.
      globalQuery = globalQuery.orderBy('createdAt', descending: true);
      if (limit != null) globalQuery = globalQuery.limit(limit);

      final globalSnap = await globalQuery.get();
      final globalRecipes = globalSnap.docs
          .where((doc) => !hiddenIds.contains(doc.id))
          .map((doc) {
            final data = {
              ...doc.data(),
              // Ensure an id exists in model if you rely on it
              'id': doc.data()['id'] ?? doc.id,
              'isGlobal': true,
            };
            return RecipeCardModel.fromJson(data);
          })
          .toList();

      // 3) User recipes (ordered if possible)
      Query<Map<String, dynamic>> userQuery = _firestore
          .collection('users')
          .doc(uid)
          .collection('recipes')
          .orderBy('createdAt', descending: true);

      if (limit != null) userQuery = userQuery.limit(limit);

      final userSnap = await userQuery.get();
      final userRecipes = userSnap.docs.map((doc) {
        final data = {
          ...doc.data(),
          'id': doc.data()['id'] ?? doc.id,
          'isGlobal': false,
        };
        return RecipeCardModel.fromJson(data);
      }).toList();

      // 4) Merge with user overrides
      final Map<String, RecipeCardModel> merged = {
        for (final r in globalRecipes) r.id: r,
        for (final r in userRecipes) r.id: r, // user wins
      };

      // 5) Stable sort by createdAt desc when present
      final list = merged.values.toList();
      list.sort((a, b) {
        final da = a.createdAt; // adjust if your model uses DateTime? createdAt
        final db = b.createdAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da); // desc
      });

      return list;
    } catch (e) {
      // Non-fatal: just return what we safely have
      // (You can hook in local cache/Hive here if desired)
      // debugPrint('⚠️ RecipeService.getAllRecipes failed: $e');
      return [];
    }
  }

  /// Convenience: fetch a single recipe by id (prefers user copy).
  static Future<RecipeCardModel?> getById(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      // Prefer user recipe
      final userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('recipes')
          .doc(id)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = {'id': id, ...userDoc.data()!};
        return RecipeCardModel.fromJson(data);
      }

      // Fallback to global (but respect hidden)
      final hidden = await _firestore
          .collection('users')
          .doc(uid)
          .collection('hiddenGlobalRecipes')
          .doc(id)
          .get();
      if (hidden.exists) return null;

      final globalDoc = await _firestore
          .collection(_globalCollection)
          .doc(id)
          .get();
      if (!globalDoc.exists || globalDoc.data() == null) return null;

      final data = {'id': id, ...globalDoc.data()!, 'isGlobal': true};
      return RecipeCardModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Hide/unhide a global recipe for the current user.
  static Future<void> setGlobalHidden(String recipeId, bool hidden) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final coll = _firestore
        .collection('users')
        .doc(uid)
        .collection('hiddenGlobalRecipes');

    if (hidden) {
      await coll.doc(recipeId).set({'hidden': true});
    } else {
      await coll.doc(recipeId).delete();
    }
  }
}
