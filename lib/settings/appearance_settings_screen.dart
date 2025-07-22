// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';

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

  Widget _buildOptionTile({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Colors.blue)
          : null,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance'), centerTitle: true),
      body: ResponsiveWrapper(
        maxWidth: 520,
        padding: const EdgeInsets.only(bottom: 24),
        child: ListView(
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 8, bottom: 4),
                        child: Text(
                          'APP THEME',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      _buildOptionTile(
                        title: 'Light Mode',
                        icon: Icons.light_mode_outlined,
                        selected: _themeMode == AppThemeMode.light,
                        onTap: () => _updateTheme(AppThemeMode.light),
                      ),
                      _buildOptionTile(
                        title: 'Dark Mode',
                        icon: Icons.dark_mode_outlined,
                        selected: _themeMode == AppThemeMode.dark,
                        onTap: () => _updateTheme(AppThemeMode.dark),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 8, bottom: 4),
                        child: Text(
                          'TEXT SIZE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      _buildOptionTile(
                        title: 'Small',
                        icon: Icons.text_decrease,
                        selected: (_textScale - 0.85).abs() < 0.01,
                        onTap: () => _updateTextScale(0.85),
                      ),
                      _buildOptionTile(
                        title: 'Medium',
                        icon: Icons.text_fields,
                        selected: (_textScale - 1.0).abs() < 0.01,
                        onTap: () => _updateTextScale(1.0),
                      ),
                      _buildOptionTile(
                        title: 'Large',
                        icon: Icons.text_increase,
                        selected: (_textScale - 1.25).abs() < 0.01,
                        onTap: () => _updateTextScale(1.25),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
