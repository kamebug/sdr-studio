import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'sdr_core_bridge.dart';

void main() {
  Locale initialLocale = const Locale('en');

  try {
    final bridge = SdrCoreBridge.load();
    bridge.initDatabase();
    final savedLocale = bridge.getSetting('locale', fallback: 'en');
    initialLocale = Locale(savedLocale);
  } catch (_) {
    // Se falhar aqui (ex: DLL não encontrada), a HomeScreen tenta de novo
    // e mostra o erro detalhado na tela — não precisa duplicar tratamento.
  }

  runApp(SdrStudioApp(initialLocale: initialLocale));
}

class SdrStudioApp extends StatefulWidget {
  const SdrStudioApp({super.key, required this.initialLocale});

  final Locale initialLocale;

  @override
  State<SdrStudioApp> createState() => _SdrStudioAppState();
}

class _SdrStudioAppState extends State<SdrStudioApp> {
  late Locale _locale = widget.initialLocale;

  void _changeLocale(Locale locale) {
    setState(() => _locale = locale);
    try {
      SdrCoreBridge.load().setSetting('locale', locale.languageCode);
    } catch (_) {
      // Sem banco disponível: a troca de idioma ainda funciona na sessão
      // atual, só não persiste entre reinicializações. Não é crítico o
      // bastante para travar a UI por causa disso.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SDR Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(onLocaleChanged: _changeLocale),
    );
  }
}
