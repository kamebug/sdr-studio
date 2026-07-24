import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../sdr_core_bridge.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.bridge,
    required this.onLocaleChanged,
  });

  final SdrCoreBridge bridge;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              l10n.language.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),
          RadioListTile<Locale>(
            title: const Text('English'),
            value: const Locale('en'),
            groupValue: currentLocale,
            activeColor: AppColors.accent,
            onChanged: (locale) {
              if (locale != null) onLocaleChanged(locale);
            },
          ),
          RadioListTile<Locale>(
            title: const Text('日本語'),
            value: const Locale('ja'),
            groupValue: currentLocale,
            activeColor: AppColors.accent,
            onChanged: (locale) {
              if (locale != null) onLocaleChanged(locale);
            },
          ),
          RadioListTile<Locale>(
            title: const Text('Português'),
            value: const Locale('pt'),
            groupValue: currentLocale,
            activeColor: AppColors.accent,
            onChanged: (locale) {
              if (locale != null) onLocaleChanged(locale);
            },
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'SOBRE'.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('SDR Studio'),
            subtitle: Text(
              bridge.version(),
              style: monoStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
