// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/widgets/placeholder_logo.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1; // Start at the "Vault" tab

  final List<Widget> _pages = const [
    SizedBox.shrink(), // <-- nothing for Upload tab
    _VaultTab(),
    _SettingsTab(),
  ];

  Future<void> _onNavTap(int idx) async {
    if (idx == 0) {
      // --- Trigger the upload flow ---
      final files = await ImageProcessingService.pickAndCompressImages();
      if (files.isNotEmpty && mounted) {
        ProcessingOverlay.show(context, files);
      }
      // Optionally, you can keep the user on Vault after upload
      setState(() => _selectedIndex = 1);
      return;
    }
    setState(() => _selectedIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'RecipeVault',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: theme.colorScheme.surface,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => _onNavTap(idx),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: theme.colorScheme.primary.withOpacity(0.14),
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.upload_rounded,
              color: _selectedIndex == 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            label: "Upload",
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

// ---- TABS ----

class _VaultTab extends StatelessWidget {
  const _VaultTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: PlaceholderLogo(imageAsset: 'assets/icon/RC_logo.png'),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: PlaceholderLogo(imageAsset: 'assets/icon/RC_logo.png'),
    );
  }
}
