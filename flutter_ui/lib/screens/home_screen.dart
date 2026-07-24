import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../audio_engine.dart';
import '../l10n/app_localizations.dart';
import '../sdr_core_bridge.dart';
import '../theme/app_theme.dart';
import '../utils/frequency_format.dart';
import '../widgets/spectrum_line_painter.dart';
import '../widgets/waterfall_painter.dart';
import 'frequency_library_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Tom fixo usado como "mensagem" demodulada audível E como sinal de
/// teste do espectro/waterfall, independente da frequência de RF
/// sintonizada mostrada na tela — necessário porque a geração sintética
/// via FFT (sample rate 48kHz) só faz sentido para tons na faixa de
/// áudio, não para frequências de RF reais (MHz/GHz). Isso é scaffolding
/// temporário: quando o RTL-SDR fornecer IQ real na frequência
/// sintonizada, essa constante deixa de ser necessária.
const double _demoAudioToneHz = 440.0;

/// Faixa de sintonia do RTL-SDR Blog V4 (hardware do MVP): 500 kHz–1.766 GHz.
const double _minTunableHz = 500000.0;
const double _maxTunableHz = 1766000000.0;

enum SpectrumViewMode { waterfall, vector }

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
  double _frequencyHz = 100000000.0; // 100 MHz — faixa de FM, valor reconhecível
  SpectrumViewMode _viewMode = SpectrumViewMode.waterfall;

  DateTime? _sessionStartedAt;
  final AudioEngine _audioEngine = AudioEngine();
  double _volume = 0.5;
  final TextEditingController _frequencyController = TextEditingController();
  final FocusNode _frequencyFocusNode = FocusNode();
  double _frequencyStep = 100000; // 100 kHz
  static const List<double> _stepOptions = [1000, 10000, 100000, 1000000];

  @override
  void initState() {
    super.initState();
    _frequencyController.text = _frequencyHz.toStringAsFixed(0);
    // Toque fora do campo (comum em telas touch, onde não existe uma
    // tecla "Enter" física) também deve confirmar o valor digitado —
    // não só a ação "concluído" do teclado virtual.
    _frequencyFocusNode.addListener(() {
      if (!_frequencyFocusNode.hasFocus) {
        _submitFrequencyText(_frequencyController.text);
      }
    });
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
    _audioEngine.stop();
    _frequencyController.dispose();
    _frequencyFocusNode.dispose();
    super.dispose();
  }

  /// Ponto único de mudança de frequência — usado pelo slider, pelos
  /// botões de passo fino e pelo campo de texto, para os três ficarem
  /// sempre sincronizados entre si.
  void _setFrequency(double value) {
    final clamped = value.clamp(_minTunableHz, _maxTunableHz);
    setState(() => _frequencyHz = clamped);
    _frequencyController.text = clamped.toStringAsFixed(0);
  }

  void _stepFrequency(double delta) {
    _setFrequency(_frequencyHz + delta);
  }

  void _submitFrequencyText(String text) {
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    if (parsed != null) {
      _setFrequency(parsed);
    } else {
      // Não deu para interpretar o que foi digitado — volta pro valor
      // atual em vez de deixar o campo com texto inválido parado ali.
      _frequencyController.text = _frequencyHz.toStringAsFixed(0);
    }
    FocusScope.of(context).unfocus();
  }

  Future<void> _toggleRunning() async {
    final startingNow = !_running;
    setState(() => _running = startingNow);

    if (startingNow) {
      _sessionStartedAt = DateTime.now();
      try {
        await _audioEngine.start(sampleRate: _bridge!.audioSampleRate);
        _audioEngine.setVolume(_volume);
      } catch (e) {
        // Áudio é uma camada extra sobre a base já funcional — se o
        // motor de áudio falhar em iniciar (ex: driver de som ausente
        // nessa máquina), o app continua rodando normalmente, só sem som.
        debugPrint('Falha ao iniciar o motor de áudio: $e');
      }
      _timer =
          Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    } else {
      _timer?.cancel();
      await _audioEngine.stop();
      _recordListeningSession();
    }
  }

  /// Registra a sessão de escuta que acabou de terminar no histórico —
  /// só se durou pelo menos 1 segundo, pra não poluir com cliques rápidos
  /// acidentais de play/stop.
  void _recordListeningSession() {
    final startedAt = _sessionStartedAt;
    if (startedAt == null || _bridge == null) return;

    final durationSeconds = DateTime.now().difference(startedAt).inSeconds;
    if (durationSeconds < 1) return;

    _bridge!.addHistory(
      freqHz: _frequencyHz,
      mode: 'FM',
      durationSeconds: durationSeconds,
    );
    _sessionStartedAt = null;
  }

  void _tick() {
    // O espectro/waterfall usa um tom de demonstração FIXO (não a
    // frequência de RF exibida na tela) — ver comentário de
    // _demoAudioToneHz no topo do arquivo para o motivo. O "jitter"
    // continua só pra dar movimento visual à demonstração.
    final jitter = sin(DateTime.now().millisecondsSinceEpoch / 500) * 50;
    final spectrum = _bridge!.generateSpectrum(_demoAudioToneHz + jitter);

    final audioChunk = _bridge!.generateAudioChunk(_demoAudioToneHz, 'FM');
    _audioEngine.feed(audioChunk);

    setState(() {
      _history.insert(0, spectrum);
      if (_history.length > _maxHistoryRows) {
        _history.removeLast();
      }
    });
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == SpectrumViewMode.waterfall
          ? SpectrumViewMode.vector
          : SpectrumViewMode.waterfall;
    });
  }

  void _openFrequencyLibrary() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FrequencyLibraryScreen(bridge: _bridge!),
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HistoryScreen(bridge: _bridge!)),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          bridge: _bridge!,
          onLocaleChanged: widget.onLocaleChanged,
        ),
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
              style: const TextStyle(color: AppColors.danger),
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
            icon: Icon(
              _viewMode == SpectrumViewMode.waterfall
                  ? Icons.show_chart
                  : Icons.grain,
            ),
            tooltip: _viewMode == SpectrumViewMode.waterfall
                ? l10n.spectrum
                : l10n.waterfall,
            onPressed: _toggleViewMode,
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: l10n.frequencyLibrary,
            onPressed: _openFrequencyLibrary,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l10n.history,
            onPressed: _openHistory,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: _openSettings,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child:
              ColoredBox(color: AppColors.border, child: SizedBox(height: 1)),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              formatFrequency(_frequencyHz),
              style: monoStyle(
                fontSize: 40,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: AppColors.accent,
              ).copyWith(
                shadows: [
                  Shadow(
                    color: AppColors.accent.withOpacity(0.5),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              l10n.frequency.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                letterSpacing: 3,
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panel,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(
                painter: _viewMode == SpectrumViewMode.waterfall
                    ? WaterfallPainter(_history)
                    : SpectrumLinePainter(
                        _history.isNotEmpty ? _history.first : const [],
                      ),
                size: Size.infinite,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  color: AppColors.textMuted,
                  tooltip: '-${formatFrequency(_frequencyStep)}',
                  onPressed: () => _stepFrequency(-_frequencyStep),
                ),
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _frequencyController,
                    focusNode: _frequencyFocusNode,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: monoStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      suffixText: 'Hz',
                      suffixStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    ),
                    onSubmitted: _submitFrequencyText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check, size: 18),
                  color: AppColors.accent,
                  tooltip: 'Confirmar',
                  // Botão explícito para telas touch, onde não existe
                  // uma tecla "Enter" física para confirmar o campo.
                  onPressed: () =>
                      _submitFrequencyText(_frequencyController.text),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  color: AppColors.textMuted,
                  tooltip: '+${formatFrequency(_frequencyStep)}',
                  onPressed: () => _stepFrequency(_frequencyStep),
                ),
                DropdownButton<double>(
                  value: _frequencyStep,
                  underline: const SizedBox(),
                  dropdownColor: AppColors.panel,
                  style: monoStyle(fontSize: 12, color: AppColors.textMuted),
                  items: _stepOptions
                      .map((step) => DropdownMenuItem(
                            value: step,
                            child: Text('±${formatFrequency(step)}'),
                          ))
                      .toList(),
                  onChanged: (step) {
                    if (step != null) setState(() => _frequencyStep = step);
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      min: _minTunableHz,
                      max: _maxTunableHz,
                      value: _frequencyHz,
                      onChanged: _setFrequency,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.volume_down,
                    size: 18, color: AppColors.textMuted),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      min: 0.0,
                      max: 1.0,
                      value: _volume,
                      onChanged: (v) {
                        setState(() => _volume = v);
                        _audioEngine.setVolume(v);
                      },
                    ),
                  ),
                ),
                const Icon(Icons.volume_up,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
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
