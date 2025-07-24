// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'package:recipe_vault/services/view_mode.dart';

class RecipeVaultScreen extends StatefulWidget {
  final ViewMode viewMode;
  const RecipeVaultScreen({super.key, required this.viewMode});

  @override
  State<RecipeVaultScreen> createState() => _RecipeVaultScreenState();
}

class _RecipeVaultScreenState extends State<RecipeVaultScreen> {
  String? userId;
  late final CollectionReference<Map<String, dynamic>> recipeCollection;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  static const List<String> _defaultCategories = [
    'Favourites',
    'Translated',
    'Breakfast',
    'Main',
    'Dessert',
  ];

  List<String> _allCategories = ['All', 'Favourites', 'Translated'];
  List<RecipeCardModel> _allRecipes = [];

  bool _showViewModeBubble = false;
  bool _showLongPressBubble = false;
  bool _showScanBubble = false;
  bool _hasLoadedBubbles = false;

  List<RecipeCardModel> get _filteredRecipes {
    return _allRecipes.where((recipe) {
      final matchesCategory =
          _selectedCategory == 'All' ||
          (_selectedCategory == 'Favourites' && recipe.isFavourite) ||
          recipe.categories.contains(_selectedCategory);

      final matchesSearch =
          _searchQuery.isEmpty ||
          recipe.title.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _deleteRecipe(RecipeCardModel recipe) async {
    setState(() {
      _allRecipes.removeWhere((r) => r.id == recipe.id);
    });
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

  void _removeCategory(String category) async {
    await CategoryService.hideDefaultCategory(category);
    await _loadCustomCategories();
  }

  void _onboardingBubbleProgression() async {
    Future.delayed(const Duration(milliseconds: 100), () async {
      if (!mounted) return;

      if (_showViewModeBubble) {
        setState(() {
          _showViewModeBubble = false;
          _showLongPressBubble = true;
        });
        debugPrint('📌 Showing Long Press bubble');
      } else if (_showLongPressBubble) {
        setState(() {
          _showLongPressBubble = false;
          _showScanBubble = true;
        });
        debugPrint('🧪 Showing Scan bubble');
      } else if (_showScanBubble) {
        setState(() {
          _showScanBubble = false;
        });
        await UserPreferencesService.markVaultTutorialCompleted();
        debugPrint('✅ All bubbles completed');
      }
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      userId = user?.uid;

      recipeCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recipes');

      final subService = Provider.of<SubscriptionService>(
        context,
        listen: false,
      );
      final tier = subService.tier;
      debugPrint('🧾 Tier at vault init: $tier');

      await UserPreferencesService.ensureBubbleFlagTriggeredIfEligible(tier);
      final hasShown = await UserPreferencesService.hasShownBubblesOnce;
      final tutorialComplete =
          await UserPreferencesService.hasCompletedVaultTutorial();

      debugPrint('🎈 Bubbles shown once: $hasShown');
      debugPrint('✅ Vault tutorial completed: $tutorialComplete');

      if (!_hasLoadedBubbles) {
        if (tier == 'free' && !tutorialComplete && hasShown) {
          setState(() {
            _showViewModeBubble = true;
          });
          debugPrint("👁️ View toggle bubble activated (tier: $tier)");
        } else {
          debugPrint("🚫 No bubble activation → Conditions not met.");
        }

        _hasLoadedBubbles = true;
      }

      await _initializeDefaultCategories();
      await _loadCustomCategories();
      await _loadRecipes();
    });
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
        'All',
        ..._defaultCategories.where((c) => !hiddenNames.contains(c)),
        ...savedNames.where((c) => !_defaultCategories.contains(c)),
      ];
    });
  }

  Future<void> _loadRecipes() async {
    try {
      final snapshot = await recipeCollection
          .orderBy('createdAt', descending: true)
          .get();
      final userRecipes = snapshot.docs
          .map((doc) => RecipeCardModel.fromJson(doc.data()))
          .toList();

      final hiddenSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('hiddenGlobalRecipes')
          .get();
      final hiddenGlobalIds = hiddenSnapshot.docs.map((doc) => doc.id).toSet();

      final globalSnapshot = await FirebaseFirestore.instance
          .collection('global_recipes')
          .orderBy('createdAt', descending: true)
          .get();
      final globalRecipes = globalSnapshot.docs
          .where((doc) => !hiddenGlobalIds.contains(doc.id))
          .map((doc) => RecipeCardModel.fromJson(doc.data()))
          .toList();

      final Map<String, RecipeCardModel> mergedMap = {};

      for (final recipe in globalRecipes) {
        mergedMap[recipe.id] = recipe;
      }
      for (final recipe in userRecipes) {
        mergedMap[recipe.id] = recipe;
      }

      final List<RecipeCardModel> merged = [];
      for (final recipe in mergedMap.values) {
        final local = HiveRecipeService.getById(recipe.id);
        final mergedRecipe = recipe.copyWith(
          isFavourite: local?.isFavourite ?? recipe.isFavourite,
          categories: local?.categories ?? recipe.categories,
        );
        await HiveRecipeService.save(mergedRecipe);
        merged.add(mergedRecipe);
      }

      setState(() {
        _allRecipes = merged;
      });
    } catch (e) {
      debugPrint("⚠️ Firestore fetch failed, loading from Hive: $e");
      final fallback = HiveRecipeService.getAll();
      setState(() {
        _allRecipes = fallback;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.viewMode;
    final scale = Provider.of<TextScaleNotifier>(context).scaleFactor;

    return Scaffold(
      body: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Stack(
          children: [
            Column(
              children: [
                RecipeChipFilterBar(
                  categories: _allCategories,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (cat) =>
                      setState(() => _selectedCategory = cat),
                  onCategoryDeleted: _removeCategory,
                  allRecipes: _allRecipes,
                ),
                RecipeSearchBar(
                  initialValue: _searchQuery,
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: ImageProcessingService.upgradeBannerMessage,
                  builder: (_, message, __) => message == null
                      ? const SizedBox.shrink()
                      : UpgradeBanner(message: message),
                ),
                Expanded(
                  child: _filteredRecipes.isEmpty
                      ? const Center(child: Text("No recipes found"))
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
              ],
            ),

            // 🫧 Bubbles overlay
            RecipeVaultBubbles(
              showScan: _showScanBubble,
              showViewToggle: _showViewModeBubble,
              showLongPress: _showLongPressBubble,
              onDismissScan: _onboardingBubbleProgression,
              onDismissViewToggle: _onboardingBubbleProgression,
              onDismissLongPress: _onboardingBubbleProgression,
            ),
          ],
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final subService = Provider.of<SubscriptionService>(context);
          final count = _allCategories
              .where((c) => !_defaultCategories.contains(c) && c != 'All')
              .length;
          final allow =
              subService.allowCategoryCreation ||
              (subService.isHomeChef && count < 3);

          return CategorySpeedDial(
            onCategoryChanged: _loadCustomCategories,
            allowCreation: allow,
          );
        },
      ),
    );
  }
}
