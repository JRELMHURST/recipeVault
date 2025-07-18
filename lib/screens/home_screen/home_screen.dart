// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/rev_cat/trial_prompt_helper.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_vault_screen.dart';
import 'package:recipe_vault/settings/settings_screen.dart';
import 'package:recipe_vault/screens/home_screen/home_app_bar.dart';
import 'package:lucide_icons/lucide_icons.dart';

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

      // 🧪 Show trial prompt for new/free users
      await TrialPromptHelper.showIfTryingRestrictedFeature(context);
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
      final canCreate = SubscriptionService().allowImageUpload;
      if (!canCreate) {
        await TrialPromptHelper.showIfTryingRestrictedFeature(context);
        return;
      }

      final files = await ImageProcessingService.pickAndCompressImages();
      if (files.isNotEmpty && mounted) {
        ProcessingOverlay.show(context, files);
      }

      setState(() => _selectedIndex = 1); // fallback to vault
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
      appBar: HomeAppBar(
        selectedIndex: _selectedIndex,
        viewModeIcon: _viewModeIcon,
        onToggleViewMode: _toggleViewMode,
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
              LucideIcons.scanLine,
              color: _selectedIndex == 0
                  ? theme.colorScheme.primary
                  : theme.iconTheme.color?.withOpacity(0.5) ?? Colors.grey,
            ),
            label: "Create",
          ),
          NavigationDestination(
            icon: Icon(
              LucideIcons.bookOpen,
              color: _selectedIndex == 1
                  ? theme.colorScheme.primary
                  : theme.iconTheme.color?.withOpacity(0.5) ?? Colors.grey,
            ),
            label: "Vault",
          ),
          NavigationDestination(
            icon: Icon(
              LucideIcons.userCog,
              color: _selectedIndex == 2
                  ? theme.colorScheme.primary
                  : theme.iconTheme.color?.withOpacity(0.5) ?? Colors.grey,
            ),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
