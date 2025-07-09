import 'package:flutter/material.dart';
import 'package:recipe_vault/core/theme_notifier.dart'; // ✅ Import the moved class

class AppearanceSettingsScreen extends StatefulWidget {
  final ThemeNotifier themeNotifier;
  const AppearanceSettingsScreen({super.key, required this.themeNotifier});

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  late AppThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeNotifier.currentAppThemeMode;
  }

  Future<void> _updateTheme(AppThemeMode mode) async {
    await widget.themeNotifier.updateTheme(mode);
    setState(() => _themeMode = mode);
  }

  Widget _buildThemeOption(AppThemeMode mode, String title, IconData icon) {
    final isSelected = _themeMode == mode;

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () => _updateTheme(mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('APP THEME'),
          _buildThemeOption(
            AppThemeMode.light,
            'Light Mode',
            Icons.light_mode_outlined,
          ),
          _buildThemeOption(
            AppThemeMode.dark,
            'Dark Mode',
            Icons.dark_mode_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
