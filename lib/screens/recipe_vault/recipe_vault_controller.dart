import 'package:flutter/material.dart';
import 'package:recipe_vault/screens/recipe_vault/vault_recipe_service.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/model/category_model.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/services/image_processing_service.dart';

enum _Step { none, viewToggle, longPress, scan, done }

class RecipeVaultController extends ChangeNotifier {
  /// State
  bool _isLoading = true;
  String? _upgradeMessage;

  // single-source-of-truth: which bubble to show
  _Step _step = _Step.none;

  ViewMode _viewMode = ViewMode.grid;
  List<CategoryModel> _customCategories = [];
  Map<String, RecipeCardModel> _allRecipes = {};

  bool _hasFetchedBubbles = false;
  VoidCallback? _upgradeListener;

  /// Getters
  bool get isLoading => _isLoading;
  bool get showScanBubble => _step == _Step.scan;
  bool get showViewToggleBubble => _step == _Step.viewToggle;
  bool get showLongPressBubble => _step == _Step.longPress;
  ViewMode get viewMode => _viewMode;
  String? get upgradeMessage => _upgradeMessage;
  List<CategoryModel> get customCategories => _customCategories;
  Map<String, RecipeCardModel> get allRecipes => _allRecipes;
  int get customCategoryCount => _customCategories.length;

  /// Initial load
  Future<void> initialise() async {
    // Listen once to the upgrade banner (UI banner elsewhere)
    _upgradeListener ??= () {
      _upgradeMessage = ImageProcessingService.upgradeBannerMessage.value;
      notifyListeners();
    };
    ImageProcessingService.upgradeBannerMessage.addListener(_upgradeListener!);

    _viewMode = await UserPreferencesService.getSavedViewMode();

    // Load data first so we can decide the *first* bubble sensibly
    await _loadCustomCategories();
    await _loadAllRecipes();

    // Bubble eligibility is set by UserSessionService; wait a moment to be safe
    await UserPreferencesService.waitForBubbleFlags();

    if (!_hasFetchedBubbles) {
      final tier = SubscriptionService().tier; // 'free' shows onboarding
      final hasShownOnce = await UserPreferencesService.hasShownBubblesOnce;
      final tutorialComplete =
          await UserPreferencesService.hasCompletedVaultTutorial();

      // Decide if we should show anything at all
      final canShow = tier == 'free' && !hasShownOnce && !tutorialComplete;

      if (canShow) {
        // If there are zero recipes, push the "scan" (add/import) first.
        if (_allRecipes.isEmpty) {
          _step = _Step.scan;
        } else {
          _step = _Step.viewToggle; // then long‑press, then scan
        }
      } else {
        _step = _Step.none;
      }

      _hasFetchedBubbles = true;
    }

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
  Future<void> setViewMode(ViewMode mode) async {
    _viewMode = mode;
    await UserPreferencesService.saveViewMode(mode);
    notifyListeners();
  }

  // ───────── Onboarding bubble stepper ─────────

  void _advance() async {
    switch (_step) {
      case _Step.viewToggle:
        _step = _Step.longPress;
        break;
      case _Step.longPress:
        _step = _Step.scan;
        break;
      case _Step.scan:
        _step = _Step.done;
        await UserPreferencesService.markVaultTutorialCompleted();
        break;
      case _Step.none:
      case _Step.done:
        break;
    }
    notifyListeners();
  }

  void dismissViewToggleBubble() {
    UserPreferencesService.markBubbleDismissed('viewToggle');
    _advance();
  }

  void dismissLongPressBubble() {
    UserPreferencesService.markBubbleDismissed('longPress');
    _advance();
  }

  void dismissScanBubble() {
    UserPreferencesService.markBubbleDismissed('scan');
    _advance();
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
