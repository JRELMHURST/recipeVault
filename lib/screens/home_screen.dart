// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/services/user_preference_service.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_vault_screen.dart';
import 'package:recipe_vault/settings/settings_screen.dart';

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
    _loadUserViewMode();
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: _selectedIndex == 1
              ? Padding(
                  padding: const EdgeInsets.only(left: 12, top: 8),
                  child: IconButton(
                    iconSize: 30,
                    icon: Icon(_viewModeIcon, color: Colors.white),
                    onPressed: _toggleViewMode,
                  ),
                )
              : null,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text(
                  _appBarTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontFamily: 'SF Pro Display',
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 4,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
