import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../sdr_core_bridge.dart';
import '../widgets/waterfall_painter.dart';
import 'frequency_library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onLocaleChanged});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _maxHistoryRows = 80;

  SdrCoreBridge? _bridge;
  String? _loadError;

  final List<List<double>> _history = [];
  Timer? _timer;
  bool _running = false;
  double _frequencyHz = 1000.0;

  @override
  void initState() {
    super.initState();
    try {
      _bridge = SdrCoreBridge.load();
      _bridge!.initDatabase();
    } catch (e) {
      _loadError = e.toString();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleRunning() {
    setState(() => _running = !_running);
    if (_running) {
      _timer =
          Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    } else {
      _timer?.cancel();
    }
  }

  void _tick() {
    final jitter = sin(DateTime.now().millisecondsSinceEpoch / 500) * 50;
    final spectrum = _bridge!.generateSpectrum(_frequencyHz + jitter);
    setState(() {
      _history.insert(0, spectrum);
      if (_history.length > _maxHistoryRows) {
        _history.removeLast();
      }
    });
  }

  void _openFrequencyLibrary() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FrequencyLibraryScreen(bridge: _bridge!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _loadError!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: l10n.frequencyLibrary,
            onPressed: _openFrequencyLibrary,
          ),
          DropdownButton<Locale>(
            value: Localizations.localeOf(context),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: Locale('en'), child: Text('EN')),
              DropdownMenuItem(value: Locale('ja'), child: Text('日本語')),
              DropdownMenuItem(value: Locale('pt'), child: Text('PT')),
            ],
            onChanged: (locale) {
              if (locale != null) widget.onLocaleChanged(locale);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: CustomPaint(
                painter: WaterfallPainter(_history),
                size: Size.infinite,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${l10n.frequency}: ${_frequencyHz.toStringAsFixed(0)} Hz',
                  style: const TextStyle(color: Colors.white70),
                ),
                Expanded(
                  child: Slider(
                    min: 100,
                    max: 10000,
                    value: _frequencyHz,
                    onChanged: (v) => setState(() => _frequencyHz = v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleRunning,
                  icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                  label: Text(_running ? l10n.stop : l10n.start),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    _bridge!.addFrequency(
                      freqHz: _frequencyHz,
                      mode: 'FM',
                      name: '',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.saveFrequency)),
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.saveFrequency),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
