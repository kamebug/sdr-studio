import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Desenha o waterfall: cada frame novo entra no topo, empurrando os
/// anteriores pra baixo — é a visualização clássica de SDR, mostrando
/// como o espectro muda ao longo do tempo (eixo X = frequência,
/// eixo Y = tempo, cor = intensidade).
///
/// A exibição sempre fica centrada na frequência sintonizada (mesma
/// convenção do SDR++/SDRangel/SDR#) — por isso a linha do VFO é
/// desenhada fixa no centro horizontal, não numa posição calculada.
/// Tocar em outro ponto do waterfall (ver HomeScreen) muda a frequência
/// sintonizada, e a linha "volta" pro centro no próximo quadro.
class WaterfallPainter extends CustomPainter {
  WaterfallPainter(this.history, {this.secondaryVfoFraction});

  /// Frames mais recentes primeiro (history[0] = mais novo).
  final List<List<double>> history;

  /// Posição horizontal (0.0–1.0) do OUTRO VFO (não o ativo, que fica
  /// sempre no centro) — null esconde o segundo marcador (modo VFO
  /// único, ou segundo VFO mudo/desativado).
  final double? secondaryVfoFraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isNotEmpty) {
      final rowHeight = size.height / history.length;
      final bins = history.first.length;
      final colWidth = size.width / bins;

      for (var row = 0; row < history.length; row++) {
        final frame = history[row];
        for (var col = 0; col < frame.length; col++) {
          final magnitude = frame[col].clamp(0.0, 1.0);
          final paint = Paint()..color = _colorForMagnitude(magnitude);
          canvas.drawRect(
            Rect.fromLTWH(
              col * colWidth,
              row * rowHeight,
              colWidth + 1,
              rowHeight + 1,
            ),
            paint,
          );
        }
      }
    }

    _drawVfoLine(canvas, size);
    if (secondaryVfoFraction != null) {
      _drawSecondaryVfoLine(canvas, size, secondaryVfoFraction!);
    }
  }

  /// Marcador do segundo VFO — cor diferente (ciano) da linha principal
  /// (âmbar), pra distinguir visualmente qual é qual.
  void _drawSecondaryVfoLine(Canvas canvas, Size size, double fraction) {
    final x = size.width * fraction.clamp(0.0, 1.0);
    final paint = Paint()
      ..color = AppColors.accentSecondary
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);

    final marker = Path()
      ..moveTo(x - 5, 0)
      ..lineTo(x + 5, 0)
      ..lineTo(x, 8)
      ..close();
    canvas.drawPath(marker, Paint()..color = AppColors.accentSecondary);
  }

  /// Linha vertical + marcador triangular no topo indicando o VFO —
  /// mesma convenção visual do SDR++/SDRangel/SDR#.
  void _drawVfoLine(Canvas canvas, Size size) {
    final x = size.width / 2;

    final linePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);

    final markerPaint = Paint()..color = AppColors.accent;
    final marker = Path()
      ..moveTo(x - 6, 0)
      ..lineTo(x + 6, 0)
      ..lineTo(x, 10)
      ..close();
    canvas.drawPath(marker, markerPaint);
  }

  /// Mapa de cor do waterfall usando a paleta de aviônica do app —
  /// preto (silêncio) → ciano (acento, sinal moderado) → âmbar (caução)
  /// → vermelho (sinal forte/alerta) — em vez do azul/amarelo genérico
  /// anterior, agora usa as mesmas cores nomeadas do resto da interface.
  Color _colorForMagnitude(double m) {
    if (m < 0.33) {
      return Color.lerp(Colors.black, AppColors.accent, m / 0.33)!;
    } else if (m < 0.66) {
      return Color.lerp(AppColors.accent, AppColors.caution, (m - 0.33) / 0.33)!;
    } else {
      return Color.lerp(AppColors.caution, AppColors.danger, (m - 0.66) / 0.34)!;
    }
  }

  @override
  bool shouldRepaint(covariant WaterfallPainter oldDelegate) => true;
}
