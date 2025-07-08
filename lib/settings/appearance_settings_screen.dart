import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode') ?? 'system';
    _themeMode = _fromAppThemeMode(
      AppThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeMode.system,
      ),
    );
    notifyListeners();
  }

  Future<void> updateTheme(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    _themeMode = _fromAppThemeMode(mode);
    notifyListeners();
  }

  ThemeMode _fromAppThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  AppThemeMode get currentAppThemeMode {
    switch (_themeMode) {
      case ThemeMode.light:
        return AppThemeMode.light;
      case ThemeMode.dark:
        return AppThemeMode.dark;
      case ThemeMode.system:
        return AppThemeMode.system;
    }
  }
}

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
            AppThemeMode.system,
            'System Default',
            Icons.phone_android,
          ),
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
