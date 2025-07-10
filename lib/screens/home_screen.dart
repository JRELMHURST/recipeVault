// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/revcat_paywall/services/subscription_service.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_vault_screen.dart';
import 'package:recipe_vault/settings/settings_screen.dart';
import 'package:recipe_vault/revcat_paywall/utils/trial_prompt_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1; // Start at the "Vault" tab
  int _viewMode = 0; // 0 = list, 1 = grid, 2 = compact

  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    _checkAccessAndInit();
  }

  Future<void> _checkAccessAndInit() async {
    final subscription = SubscriptionService();
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;

    if (!subscription.hasAccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/pricing');
      });
      return;
    }

    if (!hasSeenWelcome) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/welcome');
      });
      return;
    }

    await _loadUserViewMode();

    // Prompt for trial if eligible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TrialPromptHelper.checkAndPromptTrial(context);
    });
  }

  Future<void> _loadUserViewMode() async {
    final storedMode = UserPreferencesService.getViewMode();
    if (mounted) {
      setState(() {
        _viewMode = storedMode;
      });
    }
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = (_viewMode + 1) % 3;
    });
    UserPreferencesService.setViewMode(_viewMode);
  }

  Widget get _currentPage {
    switch (_selectedIndex) {
      case 0:
        return const SizedBox.shrink();
      case 1:
        return RecipeVaultScreen(viewMode: _viewMode);
      case 2:
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  String get _appBarTitle {
    switch (_selectedIndex) {
      case 0:
        return 'Create';
      case 1:
        return 'Recipe Vault';
      case 2:
        return 'Settings';
      default:
        return 'RecipeVault';
    }
  }

  IconData get _viewModeIcon {
    switch (_viewMode) {
      case 0:
        return Icons.grid_view_rounded;
      case 1:
        return Icons.view_module_rounded;
      case 2:
        return Icons.view_agenda_rounded;
      default:
        return Icons.grid_view_rounded;
    }
  }

  Future<void> _onNavTap(int idx) async {
    if (idx == 0) {
      final files = await ImageProcessingService.pickAndCompressImages();
      if (files.isNotEmpty && mounted) {
        ProcessingOverlay.show(context, files);
      }
      setState(() => _selectedIndex = 1); // Back to vault after upload
      return;
    }
    setState(() => _selectedIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text(_appBarTitle, style: theme.appBarTheme.titleTextStyle),
        centerTitle: true,
        leading: _selectedIndex == 1
            ? IconButton(
                icon: Icon(
                  _viewModeIcon,
                  color: theme.appBarTheme.iconTheme?.color,
                ),
                onPressed: _toggleViewMode,
              )
            : null,
      ),
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: PageStorage(bucket: _bucket, child: _currentPage),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: theme.colorScheme.surface,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: theme.colorScheme.primary.withOpacity(0.14),
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.add,
              color: _selectedIndex == 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            label: "Create",
          ),
          NavigationDestination(
            icon: Icon(
              Icons.menu_book_rounded,
              color: _selectedIndex == 1
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            label: "Recipe Vault",
          ),
          NavigationDestination(
            icon: Icon(
              Icons.settings_rounded,
              color: _selectedIndex == 2
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}
