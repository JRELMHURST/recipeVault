// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/rev_cat/trial_prompt_helper.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_vault_screen.dart';
import 'package:recipe_vault/screens/home_screen/home_app_bar.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/services/view_mode.dart';
import 'package:recipe_vault/settings/settings_screen.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;
  ViewMode _viewMode = ViewMode.grid;
  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    _initialisePreferencesAndPrompt();
  }

  Future<void> _initialisePreferencesAndPrompt() async {
    _viewMode = await ViewModeService.getViewMode();
    if (mounted) setState(() {});

    final subService = SubscriptionService();
    await subService.refresh();
    if (!mounted) return;

    if (subService.tier != 'none') {
      if (subService.canStartTrial) {
        await TrialPromptHelper.checkAndPromptTrial(context);
      }
    } else {
      void tierListener() async {
        if (subService.tier != 'none' && subService.canStartTrial) {
          await TrialPromptHelper.checkAndPromptTrial(context);
          subService.tierNotifier.removeListener(tierListener);
        }
      }

      subService.tierNotifier.addListener(tierListener);
    }
  }

  void _toggleViewMode() {
    setState(() {
      final currentIndex = ViewMode.values.indexOf(_viewMode);
      final nextIndex = (currentIndex + 1) % ViewMode.values.length;
      _viewMode = ViewMode.values[nextIndex];
    });
    ViewModeService.setViewMode(_viewMode);
  }

  Future<void> _onNavTap(int index) async {
    if (index == 0) {
      final canCreate = SubscriptionService().allowImageUpload;
      if (!canCreate) {
        HapticFeedback.mediumImpact();

        final showTrial = SubscriptionService().canStartTrial;

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Upgrade to Unlock'),
            content: const Text(
              'Creating recipes by uploading images is only available on paid plans.\n\n'
              'Start a free trial or upgrade to unlock this feature.',
            ),
            actions: [
              if (showTrial)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/paywall');
                  },
                  child: const Text('View Plans'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

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
      ViewMode.list => Icons.view_agenda_rounded,
      ViewMode.grid => Icons.grid_view_rounded,
      ViewMode.compact => Icons.view_module_rounded,
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
