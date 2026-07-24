import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fileira de marcações finas sob um slider — puramente visual (não usa
/// `divisions` do Slider, que mudaria o comportamento pra "encaixar" em
/// posições fixas). Reforça a estética de instrumento físico, como os
/// controles deslizantes de equipamentos de RF reais.
class SliderTickMarks extends StatelessWidget {
  const SliderTickMarks({super.key, this.count = 11});

  /// Quantas marcações desenhar (incluindo as duas pontas).
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(count, (i) {
          final isMajor = i == 0 || i == count - 1 || i % 5 == 0;
          return Expanded(
            child: Center(
              child: Container(
                width: 1,
                height: isMajor ? 6 : 3,
                color: AppColors.border,
              ),
            ),
          );
        }),
      ),
    );
  }
}
