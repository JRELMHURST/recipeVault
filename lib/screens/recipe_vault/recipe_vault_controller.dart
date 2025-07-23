import 'package:flutter/material.dart';
import 'package:recipe_vault/screens/recipe_vault/vault_recipe_service.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/model/category_model.dart';

enum ViewMode { list, grid, compact }

class RecipeVaultController extends ChangeNotifier {
  /// State
  bool _isLoading = true;
  bool _showScanBubble = false;
  bool _showViewToggleBubble = false;
  bool _showLongPressBubble = false;
  String? _upgradeMessage;

  ViewMode _viewMode = ViewMode.list;
  List<CategoryModel> _customCategories = [];
  Map<String, RecipeCardModel> _allRecipes = {};

  /// Cached dismissal flags (once fetched)
  bool _hasFetchedBubbles = false;

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

  /// Initial load
  Future<void> initialise() async {
    _viewMode = ViewMode.values[UserPreferencesService.getViewMode()];

    if (!_hasFetchedBubbles) {
      final scanDismissed = await UserPreferencesService.hasDismissedBubble(
        'scan',
      );
      final viewToggleDismissed =
          await UserPreferencesService.hasDismissedBubble('viewToggle');
      final longPressDismissed =
          await UserPreferencesService.hasDismissedBubble('longPress');

      debugPrint('🔍 Bubble state on load:');
      debugPrint('   • Scan dismissed: $scanDismissed');
      debugPrint('   • ViewToggle dismissed: $viewToggleDismissed');
      debugPrint('   • LongPress dismissed: $longPressDismissed');

      _showScanBubble = !scanDismissed;
      _showViewToggleBubble = !viewToggleDismissed;
      _showLongPressBubble = !longPressDismissed;
      _hasFetchedBubbles = true;

      debugPrint('📌 Bubble display state after init:');
      debugPrint('   • showScanBubble = $_showScanBubble');
      debugPrint('   • showViewToggleBubble = $_showViewToggleBubble');
      debugPrint('   • showLongPressBubble = $_showLongPressBubble');
    }

    await _loadCustomCategories();
    await _loadAllRecipes();

    _isLoading = false;
    notifyListeners();
  }

  /// Load categories
  Future<void> _loadCustomCategories() async {
    _customCategories = await CategoryService.getAllCategories();
  }

  /// Load merged user + global recipes
  Future<void> _loadAllRecipes() async {
    final loadedList = await VaultRecipeService.loadAndMergeAllRecipes();
    _allRecipes = {for (final recipe in loadedList) recipe.id: recipe};
  }

  /// Change view mode and persist
  void setViewMode(ViewMode mode) {
    _viewMode = mode;
    UserPreferencesService.setViewMode(mode.index);
    notifyListeners();
  }

  /// Bubble dismissals
  void dismissScanBubble() {
    _showScanBubble = false;
    UserPreferencesService.markBubbleDismissed('scan');
    debugPrint('❌ Scan bubble dismissed');
    notifyListeners();
  }

  void dismissViewToggleBubble() {
    _showViewToggleBubble = false;
    UserPreferencesService.markBubbleDismissed('viewToggle');
    debugPrint('❌ ViewToggle bubble dismissed');
    notifyListeners();
  }

  void dismissLongPressBubble() {
    _showLongPressBubble = false;
    UserPreferencesService.markBubbleDismissed('longPress');
    debugPrint('❌ LongPress bubble dismissed');
    notifyListeners();
  }

  /// Optional: Trigger upgrade notice
  void setUpgradeMessage(String? message) {
    _upgradeMessage = message;
    notifyListeners();
  }
}
