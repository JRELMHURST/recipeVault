// lib/screens/recipe_vault/vault_controller.dart
// ignore_for_file: duplicate_ignore

import 'dart:async';
import 'dart:collection';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/features/recipe_vault/categories.dart';

// UI enum lives here
import 'package:recipe_vault/features/recipe_vault/vault_view_mode_notifier.dart'
    show ViewMode;

// Centralised prefs adapter
import 'package:recipe_vault/features/recipe_vault/view_mode_prefs.dart';

// Repository (local Hive + remote Firestore)
import 'package:recipe_vault/data/repositories/vault_repository.dart';
import 'package:recipe_vault/data/services/image_processing_service.dart';

/// Controller for Recipe Vault — app-logic only (no BuildContext/UI side-effects).
class RecipeVaultController extends ChangeNotifier {
  RecipeVaultController({VaultRepository? repo})
    : _repo = repo ?? VaultRepository.forCurrentUser();

  // ── Data source ──────────────────────────────────────────────────────────
  VaultRepository _repo;

  // ── State ────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _upgradeMessage;

  ViewMode _viewMode = ViewMode.grid;

  /// Category names (keys), e.g. 'All', 'Breakfast', plus custom ones.
  List<String> _allCategories = const [CategoryKeys.all];

  /// Selected category key
  String _selectedCategory = CategoryKeys.all;

  /// Search text
  String _searchQuery = '';

  /// Recipes map by id
  Map<String, RecipeCardModel> _allRecipes = <String, RecipeCardModel>{};

  /// Remote (Firestore) listener
  String? _currentUserId;
  StreamSubscription<List<RecipeCardModel>>? _remoteSub;

  /// Init guard
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

  /// Idempotent initial load. Optionally pass a `userId` and an `initialViewMode`.
  Future<void> initialise({String? userId, ViewMode? initialViewMode}) async {
    if (_initialised) return;
    _initialised = true;

    // Build a repo bound to this user (null → local-only).
    _repo = VaultRepository.forUser(userId);

    // View mode
    _viewMode = initialViewMode ?? await ViewModePrefs.load();

    // Categories & local recipes
    await Future.wait([
      _initializeDefaultCategories(), // no-op; CategoryService.init seeds user defaults
      _loadCustomCategories(),
      _loadAllLocalRecipes(),
    ]);

    // Remote sync (if signed in)
    if (userId != null && userId.isNotEmpty) {
      await startRemoteSync(userId);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Start/replace the live Firestore listener for a user.
  Future<void> startRemoteSync(String userId) async {
    if (_currentUserId == userId && _remoteSub != null) return;

    _currentUserId = userId;
    _repo = VaultRepository.forUser(userId);

    await _remoteSub?.cancel();
    final stream = _repo.watchRemoteRecipes();
    if (stream == null) return;

    _remoteSub = stream.listen(
      _onRemoteRecipesList,
      onError: (e) => debugPrint('⚠️ Recipe stream error: $e'),
    );
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    super.dispose();
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Kept for compatibility; CategoryService.init() handles seeding user defaults.
  Future<void> _initializeDefaultCategories() async {
    // no-op
    return;
  }

  Future<void> _loadCustomCategories() async {
    final savedNames = await _repo.loadAllCategoryNames();
    final hidden = await _repo.loadHiddenDefaultCategories();
    final hiddenSet = hidden.toSet();

    // Build list:
    // - Always include "All"
    // - Include protected system categories unless hidden (Favourites/Translated)
    // - Include ALL user categories (including seeded Breakfast/Main/Dessert)
    _allCategories = [
      CategoryKeys.all,
      ...CategoryKeys.systemOnly.where((c) => !hiddenSet.contains(c)),
      ...savedNames.where((c) => !CategoryKeys.allSystem.contains(c)),
    ];
  }

  Future<void> _loadAllLocalRecipes() async {
    final list = await _repo.loadLocalRecipes();
    _allRecipes = {for (final r in list) r.id: r};
  }

  Future<void> _onRemoteRecipesList(List<RecipeCardModel> remote) async {
    try {
      final merged = await _repo.mergeRemoteWithLocal(remote);
      _allRecipes = {for (final r in merged) r.id: r};
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Live recipe merge failed: $e');
    }
  }

  // ── Mutations ────────────────────────────────────────────────────────────

  Future<void> deleteRecipe(RecipeCardModel recipe) async {
    // Optimistic UI
    _allRecipes.remove(recipe.id);
    notifyListeners();

    await _repo.deleteLocal(recipe.id);
    await _repo.deleteRemote(recipe.id);

    if (recipe.imageUrl?.isNotEmpty == true) {
      try {
        await FirebaseStorage.instance.refFromURL(recipe.imageUrl!).delete();
      } catch (_) {}
    }
  }

  Future<void> toggleFavourite(RecipeCardModel recipe) async {
    final updated = recipe.copyWith(isFavourite: !recipe.isFavourite);
    _allRecipes[updated.id] = updated;
    notifyListeners();

    await _repo.saveLocal(updated);
    await _repo.upsertRemote(updated);
  }

  Future<void> assignCategories(
    RecipeCardModel recipe,
    List<String> categories,
  ) async {
    final updated = recipe.copyWith(categories: categories);
    _allRecipes[updated.id] = updated;
    notifyListeners();

    await _repo.saveLocal(updated);
    await _repo.upsertRemote(updated);
  }

  /// Needs BuildContext for the image picker dialog.
  Future<void> addOrUpdateImage(
    RecipeCardModel recipe, {
    required Object /* BuildContext */ context,
  }) async {
    final newUrl = await ImageStorageBridge.pickAndUploadSingleImage(
      // ignore: avoid_dynamic_calls
      context: context as dynamic,
      recipeId: recipe.id,
    );
    if (newUrl == null) return;

    final updated = recipe.copyWith(imageUrl: newUrl);
    _allRecipes[updated.id] = updated;
    notifyListeners();

    await _repo.saveLocal(updated);
    await _repo.upsertRemote(updated);
  }

  Future<void> hideDefaultCategory(String key) async {
    await _repo.hideDefaultCategory(key);
    await _loadCustomCategories();
    notifyListeners();
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

  /// Re-fetch categories and local recipes (keeps remote listener).
  /// If [resetFilters] is true, clears search and resets category to "All".
  Future<void> refresh({bool resetFilters = false}) async {
    _isLoading = true;
    notifyListeners();

    if (resetFilters) {
      _searchQuery = '';
      _selectedCategory = CategoryKeys.all;
    }

    await Future.wait([_loadCustomCategories(), _loadAllLocalRecipes()]);

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
