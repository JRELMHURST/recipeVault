// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_vault_screen.dart';
import 'package:recipe_vault/settings/settings_screen.dart';
import 'package:recipe_vault/widgets/tier_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;
  int _viewMode = 0;
  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    _initialisePreferences();
  }

  Future<void> _initialisePreferences() async {
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

  Future<void> _onNavTap(int index) async {
    if (index == 0) {
      final files = await ImageProcessingService.pickAndCompressImages();
      if (files.isNotEmpty && mounted) {
        ProcessingOverlay.show(context, files);
      }
      setState(() => _selectedIndex = 1);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Widget get _currentPage {
    return switch (_selectedIndex) {
      0 => const SizedBox.shrink(),
      1 => RecipeVaultScreen(viewMode: _viewMode),
      2 => const SettingsScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  String get _appBarTitle {
    return switch (_selectedIndex) {
      0 => 'Create',
      1 => 'RecipeVault',
      2 => 'Settings',
      _ => 'RecipeVault',
    };
  }

  IconData get _viewModeIcon {
    return switch (_viewMode) {
      0 => Icons.grid_view_rounded,
      1 => Icons.view_module_rounded,
      2 => Icons.view_agenda_rounded,
      _ => Icons.grid_view_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: _selectedIndex == 1
            ? Consumer<SubscriptionService>(
                builder: (_, sub, __) {
                  return TierBadge(tier: sub.tier, showAsTitle: true);
                },
              )
            : Text(_appBarTitle, style: theme.appBarTheme.titleTextStyle),
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
