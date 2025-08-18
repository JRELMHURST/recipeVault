// lib/screens/recipe_vault/vault_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/services/hive_recipe_service.dart';
import 'package:recipe_vault/services/category_service.dart';

/// Repository facade for the Vault.
/// - Reads/writes **local** cache via HiveRecipeService
/// - Reads/writes **remote** data via Firestore (per-user subcollection)
/// - Exposes a Firestore **stream** for live updates
///
/// This layer is side-effect free (no BuildContext/UI).
class VaultRepository {
  VaultRepository._({
    required FirebaseFirestore firestore,
    required String? userId,
  }) : _firestore = firestore,
       _userId = userId;

  final FirebaseFirestore _firestore;
  final String? _userId;

  /// Create a repository for the **current** Firebase user (or local-only if null).
  factory VaultRepository.forCurrentUser([FirebaseFirestore? firestore]) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return VaultRepository._(
      firestore: firestore ?? FirebaseFirestore.instance,
      userId: uid,
    );
  }

  /// Create a repository for a **specific** user id (or local-only if null).
  factory VaultRepository.forUser(
    String? userId, [
    FirebaseFirestore? firestore,
  ]) {
    return VaultRepository._(
      firestore: firestore ?? FirebaseFirestore.instance,
      userId: userId,
    );
  }

  /* ───────────────────────────── Helpers ───────────────────────────── */

  CollectionReference<Map<String, dynamic>>? get _remoteCollection {
    if (_userId == null || _userId.isEmpty) return null;
    return _firestore.collection('users').doc(_userId).collection('recipes');
  }

  /* ───────────────────────────── Local (Hive) ───────────────────────────── */

  Future<List<RecipeCardModel>> loadLocalRecipes() async {
    // ensure boxes are ready through your app bootstrap
    return HiveRecipeService.getAll();
  }

  Future<void> saveLocal(RecipeCardModel recipe) =>
      HiveRecipeService.save(recipe);

  Future<void> deleteLocal(String id) => HiveRecipeService.delete(id);

  /* ───────────────────────────── Remote (Firestore) ───────────────────────── */

  /// Live stream of remote recipes ordered by creation desc.
  /// Returns `null` if there is no logged-in user (local-only mode).
  Stream<List<RecipeCardModel>>? watchRemoteRecipes() {
    final col = _remoteCollection;
    if (col == null) return null;

    return col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => RecipeCardModel.fromJson(d.data()))
              .toList(growable: false),
        );
  }

  Future<List<RecipeCardModel>> fetchRemoteOnce() async {
    final col = _remoteCollection;
    if (col == null) return const [];
    final snap = await col.orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((d) => RecipeCardModel.fromJson(d.data()))
        .toList(growable: false);
  }

  Future<void> upsertRemote(RecipeCardModel recipe) async {
    final col = _remoteCollection;
    if (col == null) return;
    await col.doc(recipe.id).set(recipe.toJson(), SetOptions(merge: true));
  }

  Future<void> deleteRemote(String id) async {
    final col = _remoteCollection;
    if (col == null) return;
    await col.doc(id).delete();
  }

  /* ───────────────────────────── Categories ───────────────────────────── */

  Future<List<String>> loadAllCategoryNames() async {
    final saved = await CategoryService.getAllCategories();
    return saved.map((c) => c.name).toList(growable: false);
  }

  Future<List<String>> loadHiddenDefaultCategories() =>
      CategoryService.getHiddenDefaultCategories();

  Future<void> hideDefaultCategory(String key) =>
      CategoryService.hideDefaultCategory(key);

  /* ───────────────────────────── Merge helpers ───────────────────────────── */

  /// Merge remote base with local toggles (favourite/categories) and persist locally.
  /// Returns merged list.
  Future<List<RecipeCardModel>> mergeRemoteWithLocal(
    List<RecipeCardModel> remote,
  ) async {
    final local = await loadLocalRecipes();
    final localIndex = {for (final r in local) r.id: r};

    final merged = <RecipeCardModel>[];
    for (final r in remote) {
      final l = localIndex[r.id];
      final m = (l == null)
          ? r
          : r.copyWith(isFavourite: l.isFavourite, categories: l.categories);
      merged.add(m);
      await saveLocal(m); // keep local cache in sync
    }
    return merged;
  }
}
