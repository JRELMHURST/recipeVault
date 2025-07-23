import 'package:flutter/material.dart';
import 'package:recipe_vault/screens/recipe_vault/vault_recipe_service.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/model/category_model.dart';

enum ViewMode { list, grid, compact }

class RecipeVaultController extends ChangeNotifier {
  // ──────────────────────────────────────────────────────────────────────────────
  /// State
  bool _isLoading = true;
  bool _showScanBubble = false;
  bool _showViewToggleBubble = false;
  bool _showLongPressBubble = false;
  String? _upgradeMessage;

  ViewMode _viewMode = ViewMode.list;
  List<CategoryModel> _customCategories = [];
  Map<String, RecipeCardModel> _allRecipes = {};

  // ──────────────────────────────────────────────────────────────────────────────
  /// Getters
  bool get isLoading => _isLoading;
  bool get showScanBubble => _showScanBubble;
  bool get showViewToggleBubble => _showViewToggleBubble;
  bool get showLongPressBubble => _showLongPressBubble;
  ViewMode get viewMode => _viewMode;
  String? get upgradeMessage => _upgradeMessage;
  List<CategoryModel> get customCategories => _customCategories;
  Map<String, RecipeCardModel> get allRecipes => _allRecipes;
  int get customCategoryCount => _customCategories.length;

  // ──────────────────────────────────────────────────────────────────────────────
  /// Initial load
  Future<void> initialise() async {
    _viewMode = ViewMode.values[UserPreferencesService.getViewMode()];

    _showScanBubble = await UserPreferencesService.shouldShowBubble('scan');
    _showViewToggleBubble = await UserPreferencesService.shouldShowBubble(
      'viewToggle',
    );
    _showLongPressBubble = await UserPreferencesService.shouldShowBubble(
      'longPress',
    );

    await _loadCustomCategories();
    await _loadAllRecipes();

    _isLoading = false;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// Load categories
  Future<void> _loadCustomCategories() async {
    _customCategories = await CategoryService.getAllCategories();
  }

  /// Load merged user + global recipes
  Future<void> _loadAllRecipes() async {
    final loadedList = await VaultRecipeService.loadAndMergeAllRecipes();
    _allRecipes = {for (final recipe in loadedList) recipe.id: recipe};
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// View mode
  void setViewMode(ViewMode mode) {
    _viewMode = mode;
    UserPreferencesService.setViewMode(mode.index);
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// Bubble dismissals
  Future<void> dismissScanBubble() async {
    _showScanBubble = false;
    await UserPreferencesService.markBubbleDismissed('scan');
    notifyListeners();
  }

  Future<void> dismissViewToggleBubble() async {
    _showViewToggleBubble = false;
    await UserPreferencesService.markBubbleDismissed('viewToggle');
    notifyListeners();
  }

  Future<void> dismissLongPressBubble() async {
    _showLongPressBubble = false;
    await UserPreferencesService.markBubbleDismissed('longPress');
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────────
  /// Optional: Trigger upgrade notice
  void setUpgradeMessage(String? message) {
    _upgradeMessage = message;
    notifyListeners();
  }
}
