import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:recipe_vault/model/category_model.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/screens/recipe_vault/vault_recipe_service.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:recipe_vault/services/hive_recipe_service.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';

/// Controller for Recipe Vault screen — bubble-free & user-only.
/// - Uses prefs for view mode
/// - Loads user recipes (no global) via VaultRecipeService/Hive
/// - Surfaces upgrade banner via ImageProcessingService
class RecipeVaultController extends ChangeNotifier {
  // ── State ────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _upgradeMessage;

  ViewMode _viewMode = ViewMode.grid;
  List<CategoryModel> _customCategories = <CategoryModel>[];
  Map<String, RecipeCardModel> _allRecipes = <String, RecipeCardModel>{};

  VoidCallback? _upgradeListener;
  bool _initialised = false;

  // ── Getters (read-only to outside) ───────────────────────────────────────
  bool get isLoading => _isLoading;
  ViewMode get viewMode => _viewMode;
  String? get upgradeMessage => _upgradeMessage;

  /// Unmodifiable views to prevent accidental external mutation.
  UnmodifiableListView<CategoryModel> get customCategories =>
      UnmodifiableListView(_customCategories);

  UnmodifiableMapView<String, RecipeCardModel> get allRecipes =>
      UnmodifiableMapView(_allRecipes);

  int get customCategoryCount => _customCategories.length;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Idempotent initial load.
  Future<void> initialise() async {
    if (_initialised) return;
    _initialised = true;

    // Hook upgrade banner listener once.
    _upgradeListener ??= () {
      _upgradeMessage = ImageProcessingService.upgradeBannerMessage.value;
      notifyListeners();
    };
    ImageProcessingService.upgradeBannerMessage.addListener(_upgradeListener!);
    _upgradeMessage = ImageProcessingService.upgradeBannerMessage.value;

    // Load prefs
    _viewMode = await UserPreferencesService.getSavedViewMode();

    // Load data
    await _loadCustomCategories();
    await _loadAllRecipes();

    _isLoading = false;
    notifyListeners();
  }

  /// Manual refresh (categories + recipes).
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await Future.wait([_loadCustomCategories(), _loadAllRecipes()]);
    _isLoading = false;
    notifyListeners();
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadCustomCategories() async {
    _customCategories = await CategoryService.getAllCategories();
  }

  /// Load user recipes and cache; no global recipes.
  Future<void> _loadAllRecipes() async {
    // Ensure service has loaded/synced anything needed, then read Hive.
    await VaultRecipeService.load();
    final list = await HiveRecipeService.getAll();
    _allRecipes = {for (final r in list) r.id: r};
  }

  // ── Mutations ────────────────────────────────────────────────────────────

  /// Change view mode and persist.
  Future<void> setViewMode(ViewMode mode) async {
    if (_viewMode == mode) return;
    _viewMode = mode;
    await UserPreferencesService.saveViewMode(mode);
    notifyListeners();
  }

  /// Optional: Trigger/clear upgrade notice manually (e.g., after actions).
  void setUpgradeMessage(String? message) {
    _upgradeMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_upgradeListener != null) {
      ImageProcessingService.upgradeBannerMessage.removeListener(
        _upgradeListener!,
      );
      _upgradeListener = null;
    }
    super.dispose();
  }
}
