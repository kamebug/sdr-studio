import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SdrStudioApp());
}

class SdrStudioApp extends StatefulWidget {
  const SdrStudioApp({super.key});

  @override
  State<SdrStudioApp> createState() => _SdrStudioAppState();
}

class _SdrStudioAppState extends State<SdrStudioApp> {
  Locale _locale = const Locale('en');

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
      home: HomeScreen(
        onLocaleChanged: (locale) => setState(() => _locale = locale),
      ),
    );
  }
}
