import 'package:flutter/material.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/core/theme_notifier.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  final ThemeNotifier themeNotifier;
  final TextScaleNotifier textScaleNotifier;

  const AppearanceSettingsScreen({
    super.key,
    required this.themeNotifier,
    required this.textScaleNotifier,
  });

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  late AppThemeMode _themeMode;
  late double _textScale;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeNotifier.currentAppThemeMode;
    _textScale = widget.textScaleNotifier.scaleFactor;
  }

  Future<void> _updateTheme(AppThemeMode mode) async {
    await widget.themeNotifier.updateTheme(mode);
    setState(() => _themeMode = mode);
  }

  void _updateTextScale(double scale) {
    final newScale =
        {
          0.85: AppTextScale.small,
          1.0: AppTextScale.medium,
          1.25: AppTextScale.large,
        }[scale] ??
        AppTextScale.medium;

    widget.textScaleNotifier.updateScale(newScale);
    setState(() => _textScale = scale);
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

  Widget _buildTextScaleOption(String label, double scale) {
    final isSelected = (_textScale - scale).abs() < 0.01;

    return ListTile(
      leading: const Icon(Icons.text_fields),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () => _updateTextScale(scale),
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
          const SizedBox(height: 24),
          _buildSectionHeader('TEXT SIZE'),
          _buildTextScaleOption('Small', 0.85),
          _buildTextScaleOption('Medium', 1.0),
          _buildTextScaleOption('Large', 1.25),
        ],
      ),
    );
  }
}
