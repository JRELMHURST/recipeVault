// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/core/theme_notifier.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/billing/subscription_service.dart';

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
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // 🔎 Plan label
    final tier = context.watch<SubscriptionService>().tier;
    final planLabel = switch (tier) {
      'home_chef' => t.planHomeChef,
      'master_chef' => t.planMasterChef,
      _ => '',
    };

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        elevation: 0,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(.96),
                theme.colorScheme.primary.withOpacity(.80),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.appearanceTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: .6,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    blurRadius: 2,
                    offset: Offset(0, 1),
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
            if (planLabel.isNotEmpty)
              Text(
                planLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
      body: ResponsiveWrapper(
        maxWidth: 520,
        padding: const EdgeInsets.only(bottom: 24),
        child: ListView(
          children: [
            const SizedBox(height: 24),

            // ===== Theme Section =====
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
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          top: 8,
                          bottom: 4,
                        ),
                        child: Text(
                          t.appThemeSectionTitle.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      _buildOptionTile(
                        title: t.lightMode,
                        icon: Icons.light_mode_outlined,
                        selected: _themeMode == AppThemeMode.light,
                        onTap: () => _updateTheme(AppThemeMode.light),
                      ),
                      _buildOptionTile(
                        title: t.darkMode,
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

            // ===== Text Size Section =====
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
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          top: 8,
                          bottom: 4,
                        ),
                        child: Text(
                          t.textSizeSectionTitle.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      _buildOptionTile(
                        title: t.textSizeSmall,
                        icon: Icons.text_decrease,
                        selected: (_textScale - 0.85).abs() < 0.01,
                        onTap: () => _updateTextScale(0.85),
                      ),
                      _buildOptionTile(
                        title: t.textSizeMedium,
                        icon: Icons.text_fields,
                        selected: (_textScale - 1.0).abs() < 0.01,
                        onTap: () => _updateTextScale(1.0),
                      ),
                      _buildOptionTile(
                        title: t.textSizeLarge,
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
