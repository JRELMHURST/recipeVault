// ignore_for_file: unnecessary_null_comparison

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../model/recipe_card_model.dart';

/// User-only recipe fetches (no global/community merging).
class RecipeService {
  static final _firestore = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _userColl {
    final uid = _uid;
    if (uid == null) {
      throw StateError('No signed-in user for RecipeService');
    }
    return _firestore.collection('users').doc(uid).collection('recipes');
  }

  /// Fetch all user recipes (optionally limited), newest first.
  static Future<List<RecipeCardModel>> getAllRecipes({int? limit}) async {
    final uid = _uid;
    if (uid == null) return [];

    try {
      Query<Map<String, dynamic>> q = _userColl.orderBy(
        'createdAt',
        descending: true,
      );
      if (limit != null) q = q.limit(limit);

      final snap = await q.get();
      final list = snap.docs.map((doc) {
        final data = doc.data();

        // Ensure id is present even if not stored in the doc
        final merged = <String, dynamic>{
          ...data,
          'id': data['id'] ?? doc.id,
          // Mark as user-owned explicitly if your model uses it
          'isGlobal': false,
        };

        return RecipeCardModel.fromJson(merged);
      }).toList();

      // If your model's createdAt is nullable, keep a stable desc sort
      list.sort((a, b) {
        final da = a.createdAt;
        final db = b.createdAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      return list;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ RecipeService.getAllRecipes failed: $e');
      }
      return [];
    }
  }

  /// Fetch a single user recipe by id.
  static Future<RecipeCardModel?> getById(String id) async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      final doc = await _userColl.doc(id).get();
      final data = doc.data();
      if (data == null) return null;

      final merged = <String, dynamic>{
        ...data,
        'id': data['id'] ?? doc.id,
        'isGlobal': false,
      };
      return RecipeCardModel.fromJson(merged);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ RecipeService.getById("$id") failed: $e');
      return null;
    }
  }

  // 🧹 Legacy no-op kept for compatibility if still referenced somewhere.
  // With user-only data, there’s nothing to hide/unhide.
  static Future<void> setGlobalHidden(String recipeId, bool hidden) async {
    if (kDebugMode) {
      debugPrint(
        'ℹ️ setGlobalHidden("$recipeId", $hidden) called but global recipes are disabled.',
      );
    }
  }
}
