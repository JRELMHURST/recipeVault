// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/rev_cat/trial_prompt_helper.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_vault_screen.dart';
import 'package:recipe_vault/screens/home_screen/home_app_bar.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
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

  late final SubscriptionService _subscriptionService;
  late final VoidCallback _tierListener;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _subscriptionService = SubscriptionService();
    _tierListener = _onTierChanged;
    _initialisePreferencesAndPrompt();
  }

  Future<void> _initialisePreferencesAndPrompt() async {
    _viewMode = await UserPreferencesService.getSavedViewMode();
    if (mounted) setState(() {});

    await _subscriptionService.refresh();
    if (!mounted) return;

    if (_subscriptionService.canStartTrial) {
      await TrialPromptHelper.checkAndPromptTrial(context);
    } else {
      _subscriptionService.tierNotifier.addListener(_tierListener);
    }
  }

  void _onTierChanged() async {
    if (_subscriptionService.canStartTrial) {
      await TrialPromptHelper.checkAndPromptTrial(context);
      _subscriptionService.tierNotifier.removeListener(_tierListener);
    }
  }

  @override
  void dispose() {
    _subscriptionService.tierNotifier.removeListener(_tierListener);
    super.dispose();
  }

  void _toggleViewMode() {
    setState(() {
      final currentIndex = ViewMode.values.indexOf(_viewMode);
      final nextIndex = (currentIndex + 1) % ViewMode.values.length;
      _viewMode = ViewMode.values[nextIndex];
    });

    // Save the updated view mode
    UserPreferencesService.saveViewMode(_viewMode);
  }

  Future<void> _onNavTap(int index) async {
    if (index == 0 && !_isProcessing) {
      _isProcessing = true;

      final canCreate = _subscriptionService.allowImageUpload;
      if (!canCreate) {
        HapticFeedback.mediumImpact();

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
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 48,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Upgrade to Unlock',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Creating recipes from images is available on paid plans.',
                    style: TextStyle(fontSize: 15, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start a free trial or upgrade to unlock this feature.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'View Plans',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        );

        _isProcessing = false;
        return;
      }

      final files = await ImageProcessingService.pickAndCompressImages();
      if (files.isNotEmpty && mounted) {
        ProcessingOverlay.show(context, files);
      }

      setState(() => _selectedIndex = 1); // fallback to vault
      _isProcessing = false;
    } else {
      setState(() => _selectedIndex = index);
    }
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
        child: PageStorage(
          bucket: _bucket,
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              const SizedBox.shrink(), // placeholder for "Create"
              RecipeVaultScreen(viewMode: _viewMode),
              const SettingsScreen(),
            ],
          ),
        ),
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
