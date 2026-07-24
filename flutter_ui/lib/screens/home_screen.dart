import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../audio_engine.dart';
import '../l10n/app_localizations.dart';
import '../models/vfo_state.dart';
import '../sdr_core_bridge.dart';
import '../theme/app_theme.dart';
import '../utils/frequency_format.dart';
import '../utils/frequency_unit.dart';
import '../widgets/frequency_digit_display.dart';
import '../widgets/slider_tick_marks.dart';
import '../widgets/spectrum_line_painter.dart';
import '../widgets/vfo_panel.dart';
import '../widgets/waterfall_painter.dart';
import 'frequency_library_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Tons fixos usados como "mensagem" demodulada audível E como sinal de
/// teste do espectro/waterfall de cada VFO, independente da frequência
/// de RF sintonizada mostrada na tela — necessário porque a geração
/// sintética via FFT (sample rate 48kHz) só faz sentido para tons na
/// faixa de áudio, não para frequências de RF reais (MHz/GHz). Isso é
/// scaffolding temporário: quando o RTL-SDR fornecer IQ real na
/// frequência sintonizada, essas constantes deixam de ser necessárias.
/// Dois valores diferentes (Lá e Mi, uma quinta acima) para os picos e
/// o áudio dos dois VFOs ficarem distinguíveis um do outro.
const double _demoToneHzA = 440.0;
const double _demoToneHzB = 660.0;

/// Faixa de sintonia do RTL-SDR Blog V4 (hardware do MVP): 500 kHz–1.766 GHz.
const double _minTunableHz = 500000.0;
const double _maxTunableHz = 1766000000.0;

/// Largura (em Hz) que o waterfall/espectro representa horizontalmente
/// — agora ajustável (zoom), com esses três valores como limites e
/// ponto de partida.
const double _minVisibleSpanHz = 10000.0; // 10 kHz — mais "zoom in"
const double _maxVisibleSpanHz = 2000000.0; // 2 MHz — mais "zoom out"
const double _defaultVisibleSpanHz = 200000.0; // 200 kHz

/// Janela de contraste (dB) usada para normalizar o espectro em dB para
/// 0.0–1.0 antes de desenhar — mesmo conceito de "range/contrast" de
/// analisadores de espectro profissionais.
const double _spectrumMinDb = -80.0;
const double _spectrumMaxDb = 0.0;

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

  // Dois VFOs independentes — o core Rust não guarda estado nenhum por
  // chamada, então "dois VFOs" aqui é só duas instâncias de VfoState
  // do lado Dart, cada uma gerando seu próprio espectro/áudio a cada
  // tick, combinados antes de exibir/tocar.
  final VfoState _vfoA =
      VfoState(frequencyHz: 100000000.0, mode: 'FM'); // 100 MHz
  final VfoState _vfoB =
      VfoState(frequencyHz: 101000000.0, mode: 'AM'); // 101 MHz
  bool _activeIsA = true;

  VfoState get _activeVfo => _activeIsA ? _vfoA : _vfoB;
  VfoState get _otherVfo => _activeIsA ? _vfoB : _vfoA;

  DateTime? _sessionStartedAt;
  final AudioEngine _audioEngine = AudioEngine();
  double _volume = 0.5;
  final TextEditingController _frequencyController = TextEditingController();
  final FocusNode _frequencyFocusNode = FocusNode();
  double _frequencyStep = 100000; // 100 kHz
  static const List<double> _stepOptions = [1000, 10000, 100000, 1000000];
  FrequencyUnit _entryUnit = FrequencyUnit.mhz;

  double _visibleSpanHz = _defaultVisibleSpanHz;
  List<double>? _maxHoldNormalized;
  double _spectrumPanelHeight = 160.0;

  @override
  void initState() {
    super.initState();
    _frequencyController.text = _entryUnit.fromHz(_activeVfo.frequencyHz);
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

  /// Troca qual VFO os controles centrais estão editando — não afeta
  /// se os VFOs estão tocando/aparecendo no waterfall, só qual deles
  /// os dígitos/campo/slider/modo controlam agora.
  void _setActiveVfo(bool isA) {
    setState(() => _activeIsA = isA);
    _frequencyController.text = _entryUnit.fromHz(_activeVfo.frequencyHz);
  }

  /// Ponto único de mudança de frequência do VFO ATIVO — usado pelo
  /// slider, pelos botões de passo fino, pelos dígitos do display
  /// grande, pelo toque no waterfall, e pelo campo de texto.
  void _setFrequency(double value) {
    final clamped = value.clamp(_minTunableHz, _maxTunableHz);
    setState(() => _activeVfo.frequencyHz = clamped);
    _frequencyController.text = _entryUnit.fromHz(clamped);
  }

  /// Troca a unidade usada no campo de texto e reformata o valor atual
  /// nela — não muda a frequência em si, só como ela é digitada/exibida
  /// no campo (o display grande de dígitos continua sempre em Hz).
  void _setEntryUnit(FrequencyUnit unit) {
    setState(() => _entryUnit = unit);
    _frequencyController.text = _entryUnit.fromHz(_activeVfo.frequencyHz);
  }

  void _stepFrequency(double delta) {
    _setFrequency(_activeVfo.frequencyHz + delta);
  }

  /// Zoom in/out — reduz/aumenta o span visível do waterfall/espectro.
  /// Dobra ou divide por 2 a cada clique, dentro dos limites definidos.
  void _zoomIn() {
    setState(() {
      _visibleSpanHz = (_visibleSpanHz / 2).clamp(
        _minVisibleSpanHz,
        _maxVisibleSpanHz,
      );
    });
  }

  void _zoomOut() {
    setState(() {
      _visibleSpanHz = (_visibleSpanHz * 2).clamp(
        _minVisibleSpanHz,
        _maxVisibleSpanHz,
      );
    });
  }

  void _resetMaxHold() {
    setState(() => _maxHoldNormalized = null);
  }

  /// Converte valores em dB para 0.0–1.0, usando a janela de contraste
  /// fixa (_spectrumMinDb.._spectrumMaxDb) — mesmo conceito de
  /// "range/contrast" de analisadores de espectro profissionais.
  List<double> _normalizeDb(List<double> dbValues) {
    return dbValues.map((db) {
      final clamped = db.clamp(_spectrumMinDb, _spectrumMaxDb);
      return (clamped - _spectrumMinDb) / (_spectrumMaxDb - _spectrumMinDb);
    }).toList();
  }

  /// Toca/arrasta no waterfall para sintonizar o VFO ATIVO — mesma
  /// convenção do SDR++/SDRangel/SDR#. Como a exibição sempre fica
  /// "centrada" no VFO ativo (ver comentário em WaterfallPainter),
  /// tocar no centro não muda nada; tocar nas bordas move
  /// proporcionalmente dentro da faixa visível (_visibleSpanHz).
  void _handleWaterfallTap(Offset localPosition, double width) {
    if (width <= 0) return;
    final fraction = (localPosition.dx / width).clamp(0.0, 1.0);
    final deltaHz = (fraction - 0.5) * _visibleSpanHz;
    _setFrequency(_activeVfo.frequencyHz + deltaHz);
  }

  void _submitFrequencyText(String text) {
    final parsedHz = _entryUnit.toHz(text);
    if (parsedHz != null) {
      _setFrequency(parsedHz);
    } else {
      // Não deu para interpretar o que foi digitado — volta pro valor
      // atual em vez de deixar o campo com texto inválido parado ali.
      _frequencyController.text = _entryUnit.fromHz(_activeVfo.frequencyHz);
    }
    FocusScope.of(context).unfocus();
  }

  /// Posição horizontal (0.0–1.0) do VFO que NÃO está ativo — null se
  /// estiver mudo OU fora da faixa visível atual (nesse caso, ver
  /// `_otherVfoDirection` para mostrar uma seta em vez de uma posição
  /// enganosa "grudada" na borda).
  double? get _otherVfoFraction {
    if (_otherVfo.muted) return null;
    final deltaHz = _otherVfo.frequencyHz - _activeVfo.frequencyHz;
    if (deltaHz.abs() > _visibleSpanHz / 2) return null;
    return (0.5 + deltaHz / _visibleSpanHz).clamp(0.0, 1.0);
  }

  /// -1 = outro VFO está abaixo da faixa visível (seta pra esquerda),
  /// 1 = acima (seta pra direita), 0 = dentro da faixa (sem seta) ou mudo.
  int get _otherVfoDirection {
    if (_otherVfo.muted) return 0;
    final deltaHz = _otherVfo.frequencyHz - _activeVfo.frequencyHz;
    if (deltaHz.abs() <= _visibleSpanHz / 2) return 0;
    return deltaHz < 0 ? -1 : 1;
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

  /// Registra no histórico cada VFO que estava tocando (não mudo) —
  /// só se a sessão durou pelo menos 1 segundo, pra não poluir com
  /// cliques rápidos acidentais de play/stop.
  void _recordListeningSession() {
    final startedAt = _sessionStartedAt;
    if (startedAt == null || _bridge == null) return;

    final durationSeconds = DateTime.now().difference(startedAt).inSeconds;
    if (durationSeconds < 1) return;

    for (final vfo in [_vfoA, _vfoB]) {
      if (vfo.muted) continue;
      _bridge!.addHistory(
        freqHz: vfo.frequencyHz,
        mode: vfo.mode,
        durationSeconds: durationSeconds,
      );
    }
    _sessionStartedAt = null;
  }

  void _tick() {
    final jitter = sin(DateTime.now().millisecondsSinceEpoch / 500) * 50;

    // Espectro em dB de cada VFO (nulo se mudo), combinados pegando o
    // maior valor de cada bin — assim os dois picos aparecem juntos.
    final spectrumDbA = _vfoA.muted
        ? null
        : _bridge!.generateSpectrumDb(_demoToneHzA + jitter);
    final spectrumDbB = _vfoB.muted
        ? null
        : _bridge!.generateSpectrumDb(_demoToneHzB + jitter);
    final combinedDb = _combineSpectra(spectrumDbA, spectrumDbB);
    final normalized = _normalizeDb(combinedDb);

    setState(() {
      if (_maxHoldNormalized == null ||
          _maxHoldNormalized!.length != normalized.length) {
        _maxHoldNormalized = List<double>.from(normalized);
      } else {
        for (var i = 0; i < normalized.length; i++) {
          if (normalized[i] > _maxHoldNormalized![i]) {
            _maxHoldNormalized![i] = normalized[i];
          }
        }
      }

      _history.insert(0, normalized);
      if (_history.length > _maxHistoryRows) {
        _history.removeLast();
      }
    });

    // Áudio de cada VFO (nulo se mudo), misturado por média simples —
    // evita estourar o volume quando os dois tocam ao mesmo tempo.
    final audioA = _vfoA.muted
        ? null
        : _bridge!.generateAudioChunk(_demoToneHzA, _vfoA.mode);
    final audioB = _vfoB.muted
        ? null
        : _bridge!.generateAudioChunk(_demoToneHzB, _vfoB.mode);
    final mixedAudio = _mixAudio(audioA, audioB);
    if (mixedAudio != null) {
      _audioEngine.feed(mixedAudio);
    }
  }

  List<double> _combineSpectra(List<double>? a, List<double>? b) {
    if (a == null) return b ?? const [];
    if (b == null) return a;
    return List<double>.generate(
      a.length,
      (i) => a[i] > b[i] ? a[i] : b[i],
    );
  }

  List<double>? _mixAudio(List<double>? a, List<double>? b) {
    if (a == null) return b;
    if (b == null) return a;
    return List<double>.generate(a.length, (i) => (a[i] + b[i]) / 2);
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
      // Layout em três colunas — painéis de VFO nas laterais, controles
      // do VFO ativo no centro — inspirado nos painéis modulares de
      // instrumentos de laboratório (Keysight) e SDRs de referência
      // (SDRuno), em vez de empilhar tudo verticalmente.
      body: Row(
        children: [
          SizedBox(
            width: 160,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: VfoPanel(
                label: 'VFO A',
                vfo: _vfoA,
                isActive: _activeIsA,
                accentColor: AppColors.accent,
                onTap: () => _setActiveVfo(true),
                onToggleMute: () => setState(() => _vfoA.muted = !_vfoA.muted),
              ),
            ),
          ),
          Expanded(child: _buildCenterColumn(context, l10n)),
          SizedBox(
            width: 160,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: VfoPanel(
                label: 'VFO B',
                vfo: _vfoB,
                isActive: !_activeIsA,
                accentColor: AppColors.accentSecondary,
                onTap: () => _setActiveVfo(false),
                onToggleMute: () => setState(() => _vfoB.muted = !_vfoB.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterColumn(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Center(
            child: FrequencyDigitDisplay(
              valueHz: _activeVfo.frequencyHz,
              minHz: _minTunableHz,
              maxHz: _maxTunableHz,
              onChanged: _setFrequency,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Text(
            formatFrequency(_activeVfo.frequencyHz),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Text(
            '${l10n.frequency.toUpperCase()} — ${_activeIsA ? "VFO A" : "VFO B"}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 3,
            ),
          ),
        ),
        // Seletor de modo do VFO ativo — sempre visível na tela
        // principal, seguindo a mesma convenção do SDR++/SDRangel/SDR#.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('AM'),
              selected: _activeVfo.mode == 'AM',
              selectedColor: AppColors.accent,
              labelStyle: TextStyle(
                color:
                    _activeVfo.mode == 'AM' ? Colors.black : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => setState(() => _activeVfo.mode = 'AM'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('FM'),
              selected: _activeVfo.mode == 'FM',
              selectedColor: AppColors.accent,
              labelStyle: TextStyle(
                color:
                    _activeVfo.mode == 'FM' ? Colors.black : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => setState(() => _activeVfo.mode = 'FM'),
            ),
          ],
        ),
        // Controles de zoom + reset do max-hold — aplicam aos dois
        // gráficos (espectro e waterfall usam o mesmo dado/span).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_in, size: 18),
                    color: AppColors.textMuted,
                    tooltip: 'Zoom in',
                    onPressed: _zoomIn,
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out, size: 18),
                    color: AppColors.textMuted,
                    tooltip: 'Zoom out',
                    onPressed: _zoomOut,
                  ),
                  Text(
                    formatFrequency(_visibleSpanHz),
                    style: monoStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _resetMaxHold,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Max Hold', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
              ),
            ],
          ),
        ),
        // Espectro (linha) em cima + waterfall embaixo, empilhados e
        // compartilhando o mesmo eixo de frequência — convenção padrão
        // de qualquer SDR de referência (SDR#, SDR++, SDRangel), em vez
        // de alternar entre os dois.
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.panel,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _handleWaterfallTap(
                          details.localPosition, constraints.maxWidth),
                      onPanUpdate: (details) => _handleWaterfallTap(
                          details.localPosition, constraints.maxWidth),
                      child: SizedBox(
                        height: _spectrumPanelHeight,
                        child: Stack(
                          children: [
                            CustomPaint(
                              painter: SpectrumLinePainter(
                                _history.isNotEmpty
                                    ? _history.first
                                    : const [],
                                secondaryVfoFraction: _otherVfoFraction,
                                maxHoldTrace: _maxHoldNormalized,
                              ),
                              size: Size.infinite,
                            ),
                            // Seta indicando que o outro VFO está fora
                            // da faixa visível atual — mais honesto do
                            // que "grudar" um marcador numa posição
                            // que não é real.
                            if (_otherVfoDirection != 0)
                              Positioned(
                                left: _otherVfoDirection == -1 ? 6 : null,
                                right: _otherVfoDirection == 1 ? 6 : null,
                                top: 8,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_otherVfoDirection == -1)
                                      const Icon(Icons.chevron_left,
                                          color: AppColors.accentSecondary,
                                          size: 18),
                                    Text(
                                      formatFrequency(_otherVfo.frequencyHz),
                                      style: monoStyle(
                                        fontSize: 10,
                                        color: AppColors.accentSecondary,
                                      ),
                                    ),
                                    if (_otherVfoDirection == 1)
                                      const Icon(Icons.chevron_right,
                                          color: AppColors.accentSecondary,
                                          size: 18),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Divisória arrastável (SplitPane) — arraste pra
                    // redimensionar o espaço entre o espectro e o
                    // waterfall. Gesto próprio, separado do gesto de
                    // sintonizar dos gráficos acima/abaixo.
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeRow,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (details) {
                          setState(() {
                            final next =
                                _spectrumPanelHeight + details.delta.dy;
                            _spectrumPanelHeight = next.clamp(
                              80.0,
                              constraints.maxHeight - 120.0,
                            );
                          });
                        },
                        child: Container(
                          height: 8,
                          alignment: Alignment.center,
                          color: Colors.transparent,
                          child: Container(
                            height: 3,
                            width: 40,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _handleWaterfallTap(
                            details.localPosition, constraints.maxWidth),
                        onPanUpdate: (details) => _handleWaterfallTap(
                            details.localPosition, constraints.maxWidth),
                        child: CustomPaint(
                          painter: WaterfallPainter(
                            _history,
                            secondaryVfoFraction: _otherVfoFraction,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ],
                );
              },
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
                width: 130,
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
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  ),
                  onSubmitted: _submitFrequencyText,
                ),
              ),
              DropdownButton<FrequencyUnit>(
                value: _entryUnit,
                underline: const SizedBox(),
                dropdownColor: AppColors.panel,
                style: monoStyle(fontSize: 12, color: AppColors.textMuted),
                items: FrequencyUnit.values
                    .map((unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit.label),
                        ))
                    .toList(),
                onChanged: (unit) {
                  if (unit != null) _setEntryUnit(unit);
                },
              ),
              IconButton(
                icon: const Icon(Icons.check, size: 18),
                color: AppColors.accent,
                tooltip: 'Confirmar',
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
                    value: _activeVfo.frequencyHz,
                    onChanged: _setFrequency,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SliderTickMarks(),
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
        const SliderTickMarks(count: 11),
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
                    freqHz: _activeVfo.frequencyHz,
                    mode: _activeVfo.mode,
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
    );
  }
}
