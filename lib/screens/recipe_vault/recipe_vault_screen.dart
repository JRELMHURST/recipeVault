// RecipeVaultScreen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ✅ Fixed import (was .dart.dart)
import 'package:recipe_vault/core/daily_message_bubble.dart.dart';

import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/rev_cat/upgrade_banner.dart';
import 'package:recipe_vault/screens/recipe_vault/category_speed_dial.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_chip_filter_bar.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_compact_view.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_dialog.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_grid_view.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_list_view.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_search_bar.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_vault_bubbles.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:recipe_vault/services/hive_recipe_service.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:recipe_vault/widgets/empty_vault_placeholder.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';

/// Drives which onboarding bubble is visible (top-level — not inside a class)
enum _OnboardingStep { none, viewToggle, longPress, scan, done }

class RecipeVaultScreen extends StatefulWidget {
  final ViewMode viewMode;
  const RecipeVaultScreen({super.key, required this.viewMode});

  @override
  State<RecipeVaultScreen> createState() => _RecipeVaultScreenState();
}

class _RecipeVaultScreenState extends State<RecipeVaultScreen> {
  String? userId;
  late final CollectionReference<Map<String, dynamic>> recipeCollection;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _recipeStreamSubscription;

  // Internal category keys
  static const String kAll = 'All';
  static const String kFav = 'Favourites';
  static const String kTranslated = 'Translated';
  static const String kBreakfast = 'Breakfast';
  static const String kMain = 'Main';
  static const String kDessert = 'Dessert';

  String _selectedCategory = kAll;
  String _searchQuery = '';

  static const List<String> _defaultCategories = [
    kFav,
    kTranslated,
    kBreakfast,
    kMain,
    kDessert,
  ];

  List<String> _allCategories = const [kAll, kFav, kTranslated];
  List<RecipeCardModel> _allRecipes = [];

  // ---------- Onboarding bubbles: state machine ----------
  _OnboardingStep _step = _OnboardingStep.none;
  bool _hasLoadedBubbles = false;

  // ---------- Anchors for future bubble positioning ----------
  final GlobalKey _keyFab = GlobalKey();
  final GlobalKey _keyViewToggle = GlobalKey();
  final GlobalKey _keyFirstCardArea = GlobalKey();

  // ✅ Search: title, ingredients, instructions, hints
  List<RecipeCardModel> get _filteredRecipes {
    final q = _searchQuery.trim();
    return _allRecipes.where((recipe) {
      final matchesCategory =
          _selectedCategory == kAll ||
          (_selectedCategory == kFav && recipe.isFavourite) ||
          recipe.categories.contains(_selectedCategory);

      final matchesSearch = q.isEmpty || recipe.matchesQuery(q);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  // --- Localisation mapping helpers (keys <-> labels) ---
  String _labelFor(String key, AppLocalizations t) {
    switch (key) {
      case kAll:
        return t.systemAll;
      case kFav:
        return t.favourites;
      case kTranslated:
        return t.translated; // or t.systemTranslated if you use that
      case kBreakfast:
        return t.defaultBreakfast;
      case kMain:
        return t.defaultMain;
      case kDessert:
        return t.defaultDessert;
      default:
        return key;
    }
  }

  String _keyFor(String label, AppLocalizations t) {
    if (label == t.systemAll) return kAll;
    if (label == t.favourites) return kFav;
    if (label == t.translated) return kTranslated; // match above mapping
    if (label == t.defaultBreakfast) return kBreakfast;
    if (label == t.defaultMain) return kMain;
    if (label == t.defaultDessert) return kDessert;
    return label;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initVault());
  }

  @override
  void dispose() {
    _recipeStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _deleteRecipe(RecipeCardModel recipe) async {
    setState(() => _allRecipes.removeWhere((r) => r.id == recipe.id));
    await HiveRecipeService.delete(recipe.id);
    await recipeCollection.doc(recipe.id).delete();
    if (recipe.imageUrl?.isNotEmpty == true) {
      final ref = FirebaseStorage.instance.refFromURL(recipe.imageUrl!);
      await ref.delete().catchError((_) => null);
    }
  }

  Future<void> _toggleFavourite(RecipeCardModel recipe) async {
    final updated = recipe.copyWith(isFavourite: !recipe.isFavourite);
    await HiveRecipeService.save(updated);
    await recipeCollection
        .doc(updated.id)
        .set(updated.toJson(), SetOptions(merge: true));
    setState(() {
      final index = _allRecipes.indexWhere((r) => r.id == updated.id);
      if (index != -1) _allRecipes[index] = updated;
    });
  }

  Future<void> _assignCategories(
    RecipeCardModel recipe,
    List<String> categories,
  ) async {
    final updated = recipe.copyWith(categories: categories);
    await HiveRecipeService.save(updated);
    await recipeCollection
        .doc(updated.id)
        .set(updated.toJson(), SetOptions(merge: true));
    setState(() {
      final index = _allRecipes.indexWhere((r) => r.id == updated.id);
      if (index != -1) _allRecipes[index] = updated;
    });
  }

  Future<void> _addOrUpdateImage(RecipeCardModel recipe) async {
    final newImageUrl = await ImageProcessingService.pickAndUploadSingleImage(
      context: context,
      recipeId: recipe.id,
    );
    if (newImageUrl == null) return;

    final updated = recipe.copyWith(imageUrl: newImageUrl);
    await HiveRecipeService.save(updated);
    await recipeCollection
        .doc(updated.id)
        .set(updated.toJson(), SetOptions(merge: true));
    setState(() {
      final index = _allRecipes.indexWhere((r) => r.id == updated.id);
      if (index != -1) _allRecipes[index] = updated;
    });
  }

  void _removeCategory(String label) async {
    final t = AppLocalizations.of(context);
    final key = _keyFor(label, t);
    await CategoryService.hideDefaultCategory(key);
    await _loadCustomCategories();
  }

  // ---------- Create flow from empty state ----------
  Future<void> _startCreateFlow() async {
    final loc = AppLocalizations.of(context);
    final sub = Provider.of<SubscriptionService>(context, listen: false);

    // Gate: image uploads on paid tiers only?
    if (!sub.allowImageUpload) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 48),
                const SizedBox(height: 16),
                Text(
                  loc.upgradeToUnlockTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  loc.createFromImagesPaid,
                  style: const TextStyle(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  loc.upgradeToUnlockBody,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/paywall');
                    },
                    child: Text(
                      loc.seePlanOptions,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(loc.cancel),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Choose images and launch processing overlay
    final files = await ImageProcessingService.pickAndCompressImages();
    if (!mounted || files.isEmpty) return;

    ProcessingOverlay.show(context, files);
  }

  // ---------- Onboarding flow ----------
  Future<void> _initVault() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      debugPrint('⚠️ Skipped vault init – no signed-in user');
      return;
    }

    userId = user.uid;

    recipeCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recipes');

    final subService = Provider.of<SubscriptionService>(context, listen: false);
    final tier = subService.tier;

    // small delay to allow layout + session prep
    await Future.delayed(const Duration(milliseconds: 100));

    await Future.wait([
      _initializeDefaultCategories(),
      _loadCustomCategories(),
      Future(_startRecipeListener),
      UserPreferencesService.waitForBubbleFlags(),
    ]);

    final hasShownOnce = await UserPreferencesService.hasShownBubblesOnce;
    final tutorialComplete =
        await UserPreferencesService.hasCompletedVaultTutorial();

    // Show only if NOT shown before and NOT completed and free tier
    final shouldShowBubbles =
        !_hasLoadedBubbles &&
        tier == 'free' &&
        !tutorialComplete &&
        !hasShownOnce;

    if (shouldShowBubbles) {
      // mark the first actual show (not at trigger time)
      await UserPreferencesService.markBubblesShown();
      if (!mounted) return;
      setState(() => _step = _OnboardingStep.viewToggle);
      debugPrint('🫧 Onboarding bubbles: showing first step (viewToggle)');
    }

    _hasLoadedBubbles = true;
  }

  void _advanceOnboarding() async {
    if (!mounted) return;

    // Mark dismissal for the bubble we’re leaving
    switch (_step) {
      case _OnboardingStep.viewToggle:
        await UserPreferencesService.markBubbleDismissed('viewToggle');
        break;
      case _OnboardingStep.longPress:
        await UserPreferencesService.markBubbleDismissed('longPress');
        break;
      case _OnboardingStep.scan:
        await UserPreferencesService.markBubbleDismissed('scan');
        break;
      case _OnboardingStep.none:
      case _OnboardingStep.done:
        break;
    }

    setState(() {
      switch (_step) {
        case _OnboardingStep.viewToggle:
          _step = _OnboardingStep.longPress;
          break;
        case _OnboardingStep.longPress:
          _step = _OnboardingStep.scan;
          break;
        case _OnboardingStep.scan:
          _step = _OnboardingStep.done;
          break;
        case _OnboardingStep.none:
        case _OnboardingStep.done:
          break;
      }
    });

    if (_step == _OnboardingStep.done) {
      await UserPreferencesService.markVaultTutorialCompleted();
      debugPrint('🎉 Onboarding bubbles completed');
    }
  }

  // ---------- Data/bootstrap ----------
  void _startRecipeListener() {
    _recipeStreamSubscription = recipeCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
          try {
            // only the user's recipes
            final userRecipes = snapshot.docs
                .map((doc) => RecipeCardModel.fromJson(doc.data()))
                .toList();

            // keep local favourites/categories in sync
            final localRecipes = await HiveRecipeService.getAll();
            final Map<String, RecipeCardModel> mergedMap = {
              for (final r in userRecipes) r.id: r,
            };

            final List<RecipeCardModel> merged = mergedMap.values.map((recipe) {
              final local = localRecipes.firstWhere(
                (r) => r.id == recipe.id,
                orElse: () => recipe,
              );
              final mergedRecipe = recipe.copyWith(
                isFavourite: local.isFavourite,
                categories: local.categories,
              );
              HiveRecipeService.save(mergedRecipe);
              return mergedRecipe;
            }).toList();

            if (!mounted) return;
            setState(() => _allRecipes = merged);
          } catch (e) {
            debugPrint("⚠️ Live recipe sync failed: $e");
          }
        }, onError: (e) => debugPrint("⚠️ Recipe stream error: $e"));
  }

  Future<void> _initializeDefaultCategories() async {
    final savedCategories = await CategoryService.getAllCategories();
    final savedNames = savedCategories.map((c) => c.name).toList();
    for (final defaultCat in _defaultCategories) {
      if (!savedNames.contains(defaultCat)) {
        await CategoryService.saveCategory(defaultCat);
      }
    }
  }

  Future<void> _loadCustomCategories() async {
    final saved = await CategoryService.getAllCategories();
    final hidden = await CategoryService.getHiddenDefaultCategories();
    final savedNames = saved.map((c) => c.name).toList();
    final hiddenNames = hidden.toSet();

    setState(() {
      _allCategories = [
        kAll,
        ..._defaultCategories.where((c) => !hiddenNames.contains(c)),
        ...savedNames.where((c) => !_defaultCategories.contains(c)),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.viewMode;
    final scale = Provider.of<TextScaleNotifier>(context).scaleFactor;
    final t = AppLocalizations.of(context);

    final displayedCategories = _allCategories
        .map((c) => _labelFor(c, t))
        .toList();
    final displayedSelected = _labelFor(_selectedCategory, t);

    return Scaffold(
      body: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox.shrink(),
                  const SizedBox(height: 8),

                  // Search bar
                  RecipeSearchBar(
                    initialValue: _searchQuery,
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),

                  const SizedBox(height: 12),

                  // Filter chips row
                  KeyedSubtree(
                    key: _keyViewToggle,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: RecipeChipFilterBar(
                          categories: displayedCategories,
                          selectedCategory: displayedSelected,
                          onCategorySelected: (label) => setState(
                            () => _selectedCategory = _keyFor(label, t),
                          ),
                          onCategoryDeleted: (label) => _removeCategory(label),
                          allRecipes: _allRecipes,
                        ),
                      ),
                    ),
                  ),

                  // Upgrade banner
                  ValueListenableBuilder<String?>(
                    valueListenable:
                        ImageProcessingService.upgradeBannerMessage,
                    builder: (_, message, __) => message == null
                        ? const SizedBox.shrink()
                        : UpgradeBanner(message: message),
                  ),

                  // Results area
                  Expanded(
                    child: KeyedSubtree(
                      key: _keyFirstCardArea,
                      child: _filteredRecipes.isEmpty
                          ? (_allRecipes.isEmpty
                                ? EmptyVaultPlaceholder(
                                    onCreate: _startCreateFlow,
                                  )
                                : Center(
                                    child: Text(
                                      t.noRecipesFound,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                  ))
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: ResponsiveWrapper(
                                child: switch (view) {
                                  ViewMode.list => RecipeListView(
                                    recipes: _filteredRecipes,
                                    onDelete: _deleteRecipe,
                                    onTap: (r) => showRecipeDialog(context, r),
                                    onToggleFavourite: _toggleFavourite,
                                    categories: _allCategories,
                                    onAssignCategories: _assignCategories,
                                    onAddOrUpdateImage: _addOrUpdateImage,
                                  ),
                                  ViewMode.grid => RecipeGridView(
                                    recipes: _filteredRecipes,
                                    onTap: (r) => showRecipeDialog(context, r),
                                    onToggleFavourite: _toggleFavourite,
                                    onAssignCategories: _assignCategories,
                                    categories: _allCategories,
                                    onDelete: _deleteRecipe,
                                    onAddOrUpdateImage: _addOrUpdateImage,
                                  ),
                                  ViewMode.compact => RecipeCompactView(
                                    recipes: _filteredRecipes,
                                    onTap: (r) => showRecipeDialog(context, r),
                                    onToggleFavourite: _toggleFavourite,
                                    onDelete: _deleteRecipe,
                                    categories: _allCategories,
                                    onAssignCategories: _assignCategories,
                                    onAddOrUpdateImage: _addOrUpdateImage,
                                  ),
                                },
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Daily tip overlay (does not push layout)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: const DailyMessageBubble(),
            ),

            // Onboarding bubbles overlay
            RecipeVaultBubbles(
              showScan: _step == _OnboardingStep.scan,
              showViewToggle: _step == _OnboardingStep.viewToggle,
              showLongPress: _step == _OnboardingStep.longPress,
              onDismissScan: _advanceOnboarding,
              onDismissViewToggle: _advanceOnboarding,
              onDismissLongPress: _advanceOnboarding,
            ),
          ],
        ),
      ),

      // FAB (wrapped for future anchoring)
      floatingActionButton: Builder(
        builder: (context) {
          final subService = Provider.of<SubscriptionService>(context);
          final count = _allCategories
              .where((c) => !_defaultCategories.contains(c) && c != kAll)
              .length;
          final allow =
              subService.allowCategoryCreation ||
              (subService.isHomeChef && count < 3);

          return KeyedSubtree(
            key: _keyFab,
            child: CategorySpeedDial(
              onCategoryChanged: _loadCustomCategories,
              allowCreation: allow,
            ),
          );
        },
      ),
    );
  }
}
