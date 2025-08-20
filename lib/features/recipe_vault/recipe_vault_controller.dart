// lib/screens/recipe_vault/vault_controller.dart
// ignore_for_file: duplicate_ignore

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/features/recipe_vault/categories.dart';

// UI enum lives here
import 'package:recipe_vault/features/recipe_vault/vault_view_mode_notifier.dart'
    show ViewMode;

// Centralised prefs adapter
import 'package:recipe_vault/features/recipe_vault/view_mode_prefs.dart';

// Services (local Hive + remote Firestore handled here)
import 'package:recipe_vault/data/services/category_service.dart';
import 'package:recipe_vault/features/recipe_vault/vault_recipe_service.dart';
import 'package:recipe_vault/data/services/image_processing_service.dart';

/// Controller for Recipe Vault — app-logic only (no BuildContext/UI side-effects).
// lib/screens/recipe_vault/vault_controller.dart
// ignore_for_file: duplicate_ignore

// ... imports stay the same ...

class RecipeVaultController extends ChangeNotifier {
  RecipeVaultController();

  // ── State ────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _upgradeMessage;

  ViewMode _viewMode = ViewMode.grid;
  List<String> _allCategories = const [CategoryKeys.all];
  String _selectedCategory = CategoryKeys.all;
  String _searchQuery = '';
  Map<String, RecipeCardModel> _allRecipes = <String, RecipeCardModel>{};

  String? _currentUserId;
  StreamSubscription<void>? _remoteSub;
  bool _initialised = false;

  // ── Getters ──────────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  ViewMode get viewMode => _viewMode;
  String? get upgradeMessage => _upgradeMessage;

  UnmodifiableListView<String> get categories =>
      UnmodifiableListView(_allCategories);

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  UnmodifiableMapView<String, RecipeCardModel> get allRecipes =>
      UnmodifiableMapView(_allRecipes);

  List<RecipeCardModel> get filteredRecipes {
    final q = _searchQuery.trim().toLowerCase();
    return _allRecipes.values.where((r) {
      final inCat =
          _selectedCategory == CategoryKeys.all ||
          (_selectedCategory == CategoryKeys.fav && r.isFavourite) ||
          r.categories.contains(_selectedCategory);
      final inSearch = q.isEmpty || r.matchesQuery(q);
      return inCat && inSearch;
    }).toList();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────
  Future<void> initialise({String? userId, ViewMode? initialViewMode}) async {
    if (_initialised) return;
    _initialised = true;

    _viewMode = initialViewMode ?? await ViewModePrefs.load();

    await Future.wait([
      _initializeDefaultCategories(),
      _loadCustomCategories(),
      _reloadFromSource(),
    ]);

    if (userId != null && userId.isNotEmpty) {
      await startRemoteSync(userId);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> startRemoteSync(String userId) async {
    if (_currentUserId == userId && _remoteSub != null) return;

    _currentUserId = userId;
    await _remoteSub?.cancel();
    VaultRecipeService.cancelVaultListener();

    VaultRecipeService.listenToVaultChanges(() async {
      try {
        await _reloadFromSource();
        notifyListeners();
      } catch (e) {
        debugPrint('⚠️ Live recipe refresh failed: $e');
      }
    });

    _remoteSub = Stream<void>.empty().listen((_) {});
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    VaultRecipeService.cancelVaultListener();
    super.dispose();
  }

  // ── Private helpers ──────────────────────────────────────────────────────
  Future<void> _initializeDefaultCategories() async {
    return;
  }

  Future<void> _loadCustomCategories() async {
    final saved = await CategoryService.getAllCategories();
    final savedNames = saved.map((c) => c.name).toList(growable: false);

    final hidden = await CategoryService.getHiddenDefaultCategories();
    final hiddenSet = hidden.toSet();

    _allCategories = [
      CategoryKeys.all,
      ...CategoryKeys.systemOnly.where((c) => !hiddenSet.contains(c)),
      ...savedNames.where((c) => !CategoryKeys.allSystem.contains(c)),
    ];
  }

  Future<void> _reloadFromSource() async {
    final merged = await VaultRecipeService.loadAndMergeAllRecipes();
    _allRecipes = {for (final r in merged) r.id: r};
  }

  // ── Mutations ────────────────────────────────────────────────────────────
  Future<void> deleteRecipe(RecipeCardModel recipe) async {
    _allRecipes.remove(recipe.id);
    notifyListeners();
    await VaultRecipeService.delete(recipe);
  }

  Future<void> toggleFavourite(RecipeCardModel recipe) async {
    final updated = recipe.copyWith(isFavourite: !recipe.isFavourite);
    _allRecipes[updated.id] = updated;
    notifyListeners();
    await VaultRecipeService.save(updated);
  }

  Future<void> assignCategories(
    RecipeCardModel recipe,
    List<String> categories,
  ) async {
    final updated = recipe.copyWith(categories: categories);
    _allRecipes[updated.id] = updated;
    notifyListeners();
    await VaultRecipeService.save(updated);
  }

  Future<void> addOrUpdateImage(
    RecipeCardModel recipe, {
    required Object /* BuildContext */ context,
  }) async {
    final newUrl = await ImageStorageBridge.pickAndUploadSingleImage(
      context: context as dynamic,
      recipeId: recipe.id,
    );
    if (newUrl == null) return;

    final updated = recipe.copyWith(imageUrl: newUrl);
    _allRecipes[updated.id] = updated;
    notifyListeners();
    await VaultRecipeService.save(updated);
  }

  Future<void> hideDefaultCategory(String key) async {
    await CategoryService.hideDefaultCategory(key);
    await _loadCustomCategories();
    notifyListeners();
  }

  /// 🚀 New: Delete a custom category entirely
  Future<void> deleteCustomCategory(String key) async {
    try {
      await CategoryService.deleteCategory(key); // remove from Hive + Firestore
      await _loadCustomCategories();

      // reset selection if the deleted one was active
      if (_selectedCategory == key) {
        _selectedCategory = CategoryKeys.all;
      }

      // also clean up recipes still pointing to this category
      final updated = <String, RecipeCardModel>{};
      for (final r in _allRecipes.values) {
        if (r.categories.contains(key)) {
          final newCats = r.categories.where((c) => c != key).toList();
          final newR = r.copyWith(categories: newCats);
          updated[newR.id] = newR;
          await VaultRecipeService.save(newR);
        }
      }
      _allRecipes.addAll(updated);

      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Failed to delete custom category $key: $e');
    }
  }

  // ── View & Filters ───────────────────────────────────────────────────────
  Future<void> setViewMode(ViewMode mode) async {
    if (_viewMode == mode) return;
    _viewMode = mode;
    await ViewModePrefs.save(mode);
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setSelectedCategory(String key) {
    _selectedCategory = key;
    notifyListeners();
  }

  Future<void> refresh({bool resetFilters = false}) async {
    _isLoading = true;
    notifyListeners();

    if (resetFilters) {
      _searchQuery = '';
      _selectedCategory = CategoryKeys.all;
    }

    await Future.wait([_loadCustomCategories(), _reloadFromSource()]);

    _isLoading = false;
    notifyListeners();
  }
}

/* ───────────────────────────── UI bridge for image picking ───────────────────────────── */
class ImageStorageBridge {
  static Future<String?> pickAndUploadSingleImage({
    required dynamic context, // BuildContext
    required String recipeId,
  }) async {
    return await _realPickAndUpload(context as dynamic, recipeId);
  }

  static Future<String?> _realPickAndUpload(
    dynamic context,
    String recipeId,
  ) async {
    return await ImageProcessingService.pickAndUploadSingleImage(
      context: context,
      recipeId: recipeId,
    );
  }
}
