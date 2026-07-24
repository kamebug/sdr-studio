import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Visualização alternativa do espectro em traço fino — linguagem visual
/// de osciloscópio vetorial (a mesma família do easter egg de nave
/// espacial do Android: linhas finas brancas sobre fundo escuro, alta
/// densidade de dado sem peso visual). Pensada especialmente para telas
/// pequenas (mobile), onde os blocos de cor cheios do waterfall pesam
/// mais do que traços finos — dá pra encaixar grade, marcador de pico e
/// leitura numérica sem poluir a tela.
class SpectrumLinePainter extends CustomPainter {
  SpectrumLinePainter(
    this.spectrum, {
    this.maxFrequencyHz = 24000,
    this.secondaryVfoFraction,
    this.maxHoldTrace,
  });

  /// Frame de espectro mais recente (magnitudes normalizadas 0.0–1.0).
  final List<double> spectrum;

  /// Frequência representada no bin mais à direita do eixo X.
  final double maxFrequencyHz;

  /// Posição horizontal (0.0–1.0) do OUTRO VFO — null esconde o
  /// segundo marcador.
  final double? secondaryVfoFraction;

  /// Traço de "pico retido" (max-hold) — guarda o maior valor visto em
  /// cada bin ao longo do tempo, desenhado como linha mais fraca por
  /// trás do traço atual. Recurso padrão de analisadores de espectro
  /// profissionais para não perder picos breves entre atualizações.
  final List<double>? maxHoldTrace;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    if (maxHoldTrace != null && maxHoldTrace!.length >= 2) {
      _drawTrace(canvas, size, maxHoldTrace!,
          color: AppColors.textMuted, strokeWidth: 1.0);
    }
    if (spectrum.length >= 2) {
      _drawSpectrumLine(canvas, size);
      _drawPeakMarker(canvas, size);
      _drawAxisLabels(canvas, size);
    }
    _drawVfoLine(canvas, size);
    if (secondaryVfoFraction != null) {
      final x = size.width * secondaryVfoFraction!.clamp(0.0, 1.0);
      final paint = Paint()
        ..color = AppColors.accentSecondary
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  /// Linha vertical no centro indicando o VFO — mesma convenção do
  /// waterfall e dos SDRs de referência (SDR++/SDRangel/SDR#).
  void _drawVfoLine(Canvas canvas, Size size) {
    final x = size.width / 2;
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.5;

    const horizontalDivisions = 4;
    for (var i = 1; i < horizontalDivisions; i++) {
      final y = size.height * i / horizontalDivisions;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    const verticalDivisions = 8;
    for (var i = 1; i < verticalDivisions; i++) {
      final x = size.width * i / verticalDivisions;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  /// Desenha um traço genérico (usado pelo max-hold) — mesma lógica de
  /// `_drawSpectrumLine`, mas parametrizada por cor/espessura/dado, já
  /// que o traço atual e o de pico retido usam o mesmo tipo de desenho.
  void _drawTrace(
    Canvas canvas,
    Size size,
    List<double> values, {
    required Color color,
    required double strokeWidth,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final n = values.length;
    for (var i = 0; i < n; i++) {
      final x = size.width * i / (n - 1);
      final y = size.height * (1 - values[i].clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawSpectrumLine(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final n = spectrum.length;
    for (var i = 0; i < n; i++) {
      final x = size.width * i / (n - 1);
      final y = size.height * (1 - spectrum[i].clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  void _drawPeakMarker(Canvas canvas, Size size) {
    var peakIndex = 0;
    var peakValue = 0.0;
    for (var i = 0; i < spectrum.length; i++) {
      if (spectrum[i] > peakValue) {
        peakValue = spectrum[i];
        peakIndex = i;
      }
    }

    final x = size.width * peakIndex / (spectrum.length - 1);
    final y = size.height * (1 - peakValue.clamp(0.0, 1.0));

    final markerPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Crosshair fino, não um ponto sólido — mantém o traço leve.
    const armLength = 6.0;
    canvas.drawLine(
        Offset(x - armLength, y), Offset(x + armLength, y), markerPaint);
    canvas.drawLine(
        Offset(x, y - armLength), Offset(x, y + armLength), markerPaint);

    final freqHz = maxFrequencyHz * peakIndex / (spectrum.length - 1);
    final label = '${freqHz.toStringAsFixed(0)} Hz';
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: monoStyle(fontSize: 10, color: AppColors.accent),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelX = (x + 8).clamp(0.0, size.width - textPainter.width);
    final labelY = (y - textPainter.height - 4).clamp(0.0, size.height);
    textPainter.paint(canvas, Offset(labelX, labelY));
  }

  void _drawAxisLabels(Canvas canvas, Size size) {
    _paintLabel(canvas, '0 Hz', Offset(4, size.height - 16));
    _paintLabel(
      canvas,
      '${maxFrequencyHz.toStringAsFixed(0)} Hz',
      Offset(size.width - 64, size.height - 16),
    );
  }

  void _paintLabel(Canvas canvas, String text, Offset offset) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: monoStyle(fontSize: 10, color: AppColors.textMuted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant SpectrumLinePainter oldDelegate) => true;
}
