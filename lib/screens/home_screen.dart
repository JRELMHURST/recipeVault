// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/widgets/placeholder_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1; // Start at the "Vault" tab

  final List<Widget> _pages = const [_UploadTab(), _VaultTab(), _SettingsTab()];

  void _onNavTap(int idx) {
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
        onDestinationSelected: _onNavTap,
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

class _UploadTab extends StatelessWidget {
  const _UploadTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: PlaceholderLogo(imageAsset: 'assets/icon/RC_logo.png'),
    );
  }
}

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
