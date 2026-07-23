import 'package:flutter/material.dart';

/// Desenha o waterfall: cada frame novo entra no topo, empurrando os
/// anteriores pra baixo — é a visualização clássica de SDR, mostrando
/// como o espectro muda ao longo do tempo (eixo X = frequência,
/// eixo Y = tempo, cor = intensidade).
class WaterfallPainter extends CustomPainter {
  WaterfallPainter(this.history);

  /// Frames mais recentes primeiro (history[0] = mais novo).
  final List<List<double>> history;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

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

  /// Mapa de cor estilo waterfall clássico: preto/azul (fraco) até
  /// amarelo/vermelho (forte) — mesma linguagem visual do SDR++/SDRangel.
  Color _colorForMagnitude(double m) {
    if (m < 0.25) {
      return Color.lerp(Colors.black, Colors.blue.shade900, m / 0.25)!;
    } else if (m < 0.5) {
      return Color.lerp(
          Colors.blue.shade900, Colors.cyan, (m - 0.25) / 0.25)!;
    } else if (m < 0.75) {
      return Color.lerp(Colors.cyan, Colors.yellow, (m - 0.5) / 0.25)!;
    } else {
      return Color.lerp(Colors.yellow, Colors.red, (m - 0.75) / 0.25)!;
    }
  }

  @override
  bool shouldRepaint(covariant WaterfallPainter oldDelegate) => true;
}
