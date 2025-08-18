// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_vault_screen.dart';
import 'package:recipe_vault/screens/home_screen/home_app_bar.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/settings/settings_screen.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

// ✅ Prefs service (has PrefsViewMode)
import 'package:recipe_vault/services/user_preference_service.dart' as prefs;

// ✅ UI enum (ViewMode) used by screens/widgets
import 'package:recipe_vault/screens/recipe_vault/vault_view_mode_notifier.dart'
    show ViewMode;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;

  // UI-layer enum (from notifier file)
  ViewMode _viewMode = ViewMode.grid;

  final PageStorageBucket _bucket = PageStorageBucket();

  late SubscriptionService _subscriptionService;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Use app-wide instance provided by Provider
    _subscriptionService = context.read<SubscriptionService>();
    _initialisePreferences();
  }

  Future<void> _initialisePreferences() async {
    // Load saved prefs (prefs.PrefsViewMode) then map to UI enum (ViewMode)
    final saved = await prefs.UserPreferencesService.getSavedViewMode();
    if (!mounted) return;
    setState(() => _viewMode = _fromPrefs(saved));
    // Keep subscription state fresh
    await _subscriptionService.refresh();
  }

  void _toggleViewMode() {
    if (!mounted) return;
    setState(() {
      final i = ViewMode.values.indexOf(_viewMode);
      _viewMode = ViewMode.values[(i + 1) % ViewMode.values.length];
    });
    // persist using prefs enum
    prefs.UserPreferencesService.saveViewMode(_toPrefs(_viewMode));
  }

  Future<void> _onNavTap(int index) async {
    final loc = AppLocalizations.of(context);

    if (index == 0 && !_isProcessing) {
      _isProcessing = true;

      final canCreate = _subscriptionService.allowImageUpload;
      if (!canCreate) {
        HapticFeedback.mediumImpact();

        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => Dialog(
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
                  Text(loc.createFromImagesPaid, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(loc.upgradeToUnlockBody, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(); // close dialog only
                        context.push('/paywall'); // then navigate
                      },
                      child: Text(loc.seePlanOptions),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(loc.cancel),
                  ),
                ],
              ),
            ),
          ),
        );

        _isProcessing = false;
        return;
      }

      // Paid: proceed to pick & process images.
      final files = await ImageProcessingService.pickAndCompressImages();
      if (files.isNotEmpty && mounted) {
        ProcessingOverlay.show(context, files);
      }

      if (mounted) setState(() => _selectedIndex = 1);
      _isProcessing = false;
      return;
    }

    if (mounted) setState(() => _selectedIndex = index);
  }

  IconData get _viewModeIcon => switch (_viewMode) {
    ViewMode.list => Icons.view_agenda_rounded,
    ViewMode.grid => Icons.grid_view_rounded,
    ViewMode.compact => Icons.view_module_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

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
              const SizedBox.shrink(), // Scan tab placeholder (launch flow)
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
            label: loc.tabCreate,
          ),
          NavigationDestination(
            icon: Icon(
              LucideIcons.bookOpen,
              color: _selectedIndex == 1
                  ? theme.colorScheme.primary
                  : theme.iconTheme.color?.withOpacity(0.5) ?? Colors.grey,
            ),
            label: loc.tabVault,
          ),
          NavigationDestination(
            icon: Icon(
              LucideIcons.userCog,
              color: _selectedIndex == 2
                  ? theme.colorScheme.primary
                  : theme.iconTheme.color?.withOpacity(0.5) ?? Colors.grey,
            ),
            label: loc.tabProfile,
          ),
        ],
      ),
    );
  }
}

/* ---------- Enum bridges: UI ViewMode <-> prefs.PrefsViewMode ---------- */

prefs.PrefsViewMode _toPrefs(ViewMode m) => switch (m) {
  ViewMode.list => prefs.PrefsViewMode.list,
  ViewMode.grid => prefs.PrefsViewMode.grid,
  ViewMode.compact => prefs.PrefsViewMode.compact,
};

ViewMode _fromPrefs(prefs.PrefsViewMode m) => switch (m) {
  prefs.PrefsViewMode.list => ViewMode.list,
  prefs.PrefsViewMode.grid => ViewMode.grid,
  prefs.PrefsViewMode.compact => ViewMode.compact,
};
