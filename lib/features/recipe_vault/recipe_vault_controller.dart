// lib/screens/recipe_vault/vault_controller.dart
// ignore_for_file: duplicate_ignore, use_build_context_synchronously

import 'dart:async';
import 'dart:collection';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/data/services/usage_service.dart';
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
  Timer? _debounce; // debounce for live refresh bursts
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

    // Load everything in parallel
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

    // Cancel any previous stream and vault listener
    await _remoteSub?.cancel();
    _remoteSub = null;
    VaultRecipeService.cancelVaultListener();

    // Attach vault listener — debounce actual reloads
    VaultRecipeService.listenToVaultChanges(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () async {
        try {
          // guard: if user changed during debounce, skip
          if (_currentUserId != userId) return;
          await _reloadFromSource();
          notifyListeners();
        } catch (e) {
          debugPrint('⚠️ Live recipe refresh failed: $e');
        }
      });
    });

    // Hold a no-op subscription just so dispose() can always cancel safely.
    _remoteSub = Stream<void>.empty().listen((_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _remoteSub?.cancel();
    VaultRecipeService.cancelVaultListener();
    super.dispose();
  }

  // ── Private helpers ──────────────────────────────────────────────────────
  Future<void> _initializeDefaultCategories() async {
    // CategoryService ensures defaults & migration in its onAuthChanged path.
    return;
  }

  Future<void> _loadCustomCategories() async {
    try {
      final saved = await CategoryService.getAllCategories();
      final savedNames = saved.map((c) => c.name).toList(growable: false);

      final hidden = await CategoryService.getHiddenDefaultCategories();
      final hiddenSet = hidden.toSet();

      // Compose, de-dupe, and sort user-visible categories
      final userVisibleSystem = CategoryKeys.systemOnly
          .where((c) => !hiddenSet.contains(c))
          .toSet();

      final userCustom = savedNames
          .where((c) => !CategoryKeys.allSystem.contains(c))
          .toSet();

      final combined = <String>{
        CategoryKeys.all,
        ...userVisibleSystem,
        ...userCustom,
      }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      // Ensure "All" is first
      combined.remove(CategoryKeys.all);
      _allCategories = [CategoryKeys.all, ...combined];
    } catch (e) {
      debugPrint('⚠️ Failed loading categories: $e');
      // fall back to safe minimal set
      _allCategories = const [CategoryKeys.all];
    }
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
    required BuildContext context,
  }) async {
    final newUrl = await ImageStorageBridge.pickAndUploadSingleImage(
      context: context,
      recipeId: recipe.id,
    );
    if (newUrl == null) return;

    final updated = recipe.copyWith(imageUrl: newUrl);
    _allRecipes[updated.id] = updated;
    notifyListeners();
    await VaultRecipeService.save(updated);

    // ✅ Refresh usage after success
    unawaited(context.read<UsageService>().refreshOnce());
  }

  Future<void> hideDefaultCategory(String key) async {
    await CategoryService.hideDefaultCategory(key);
    await _loadCustomCategories();
    notifyListeners();
  }

  /// Delete a custom category entirely and scrub it from recipes.
  Future<void> deleteCustomCategory(String key) async {
    try {
      await CategoryService.deleteCategory(key); // Hive + Firestore
      await _loadCustomCategories();

      // Reset selection if the deleted one was active
      if (_selectedCategory == key) {
        _selectedCategory = CategoryKeys.all;
      }

      // Clean up recipes still pointing to this category
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
    required BuildContext context,
    required String recipeId,
  }) {
    return _realPickAndUpload(context, recipeId);
  }

  static Future<String?> _realPickAndUpload(
    BuildContext context,
    String recipeId,
  ) {
    return ImageProcessingService.pickAndUploadSingleImage(
      context: context,
      recipeId: recipeId,
    );
  }
}
