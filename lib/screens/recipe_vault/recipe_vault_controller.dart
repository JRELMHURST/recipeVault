import 'package:flutter/material.dart';
import 'package:recipe_vault/screens/recipe_vault/vault_recipe_service.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/model/category_model.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/services/hive_recipe_service.dart';

/// Controller for Recipe Vault screen — bubble-free & user-only.
class RecipeVaultController extends ChangeNotifier {
  // State
  bool _isLoading = true;
  String? _upgradeMessage;

  ViewMode _viewMode = ViewMode.grid;
  List<CategoryModel> _customCategories = [];
  Map<String, RecipeCardModel> _allRecipes = {};

  VoidCallback? _upgradeListener;

  // Getters
  bool get isLoading => _isLoading;
  ViewMode get viewMode => _viewMode;
  String? get upgradeMessage => _upgradeMessage;
  List<CategoryModel> get customCategories => _customCategories;
  Map<String, RecipeCardModel> get allRecipes => _allRecipes;
  int get customCategoryCount => _customCategories.length;

  /// Initial load
  Future<void> initialise() async {
    // Listen for “upgrade” banner messages
    _upgradeListener ??= () {
      _upgradeMessage = ImageProcessingService.upgradeBannerMessage.value;
      notifyListeners();
    };
    ImageProcessingService.upgradeBannerMessage.addListener(_upgradeListener!);

    // Load prefs
    _viewMode = await UserPreferencesService.getSavedViewMode();

    // Load data
    await _loadCustomCategories();
    await _loadAllRecipes();

    _isLoading = false;
    notifyListeners();
  }

  /// Load categories
  Future<void> _loadCustomCategories() async {
    _customCategories = await CategoryService.getAllCategories();
  }

  /// Load user recipes and cache; no global recipes.
  Future<void> _loadAllRecipes() async {
    // If your VaultRecipeService returns list directly, do:
    // final list = await VaultRecipeService.loadUserAndCacheAllRecipes();
    // Otherwise, call a load() that fills Hive, then read from Hive:
    await VaultRecipeService.load();
    final list = await HiveRecipeService.getAll();

    _allRecipes = {for (final r in list) r.id: r};
  }

  /// Change view mode and persist
  Future<void> setViewMode(ViewMode mode) async {
    _viewMode = mode;
    await UserPreferencesService.saveViewMode(mode);
    notifyListeners();
  }

  /// Optional: Trigger/clear upgrade notice manually
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
