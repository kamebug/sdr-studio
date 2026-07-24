import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Um único token do display: ou um dígito interativo, ou um separador
/// visual fixo (ponto de agrupamento de milhar).
class _DigitToken {
  const _DigitToken.digit(this.char, this.placeValue) : isSeparator = false;
  const _DigitToken.separator()
      : char = '.',
        isSeparator = true,
        placeValue = 0;

  final bool isSeparator;
  final String char;

  /// Valor em Hz que rolar este dígito uma posição representa
  /// (ex: 1000000 para o dígito das centenas de milhar).
  final double placeValue;
}

/// Display de frequência com dígitos individuais — cada um responde a
/// scroll do mouse (desktop) ou toque na metade superior/inferior
/// (touch), incrementando/decrementando só aquela casa decimal. É a
/// mesma convenção de sintonia rápida do SDR#, HDSDR e SDRuno.
///
/// Sempre mostra em Hz agrupado por milhar (ex: "112.123.000") — a
/// unidade de exibição não muda aqui; quem quiser digitar em MHz/kHz
/// usa o campo de texto separado, que tem seletor de unidade próprio.
class FrequencyDigitDisplay extends StatelessWidget {
  const FrequencyDigitDisplay({
    super.key,
    required this.valueHz,
    required this.minHz,
    required this.maxHz,
    required this.onChanged,
  });

  final double valueHz;
  final double minHz;
  final double maxHz;
  final ValueChanged<double> onChanged;

  List<_DigitToken> _buildTokens() {
    final raw = valueHz.round().toString();
    final n = raw.length;
    final tokens = <_DigitToken>[];

    for (var i = 0; i < n; i++) {
      final placeValue = math.pow(10, n - 1 - i).toDouble();
      tokens.add(_DigitToken.digit(raw[i], placeValue));

      final digitsFromRight = n - 1 - i;
      if (digitsFromRight > 0 && digitsFromRight % 3 == 0) {
        tokens.add(const _DigitToken.separator());
      }
    }
    return tokens;
  }

  void _changeByPlace(double placeValue, int direction) {
    final next = (valueHz + placeValue * direction).clamp(minHz, maxHz);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _buildTokens();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final token in tokens)
          token.isSeparator
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Text(
                    token.char,
                    style: _digitStyle(muted: true),
                  ),
                )
              : _InteractiveDigit(
                  char: token.char,
                  onScrollUp: () => _changeByPlace(token.placeValue, 1),
                  onScrollDown: () => _changeByPlace(token.placeValue, -1),
                ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('Hz', style: _digitStyle(muted: true, fontSize: 16)),
        ),
      ],
    );
  }

  TextStyle _digitStyle({bool muted = false, double fontSize = 40}) {
    return monoStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
      color: muted ? AppColors.textMuted : AppColors.accent,
    );
  }
}

/// Um único dígito interativo: scroll do mouse rola o valor; toque na
/// metade de cima incrementa, toque na metade de baixo decrementa —
/// cobre desktop (scroll) e touch (tap) com o mesmo widget.
class _InteractiveDigit extends StatelessWidget {
  const _InteractiveDigit({
    required this.char,
    required this.onScrollUp,
    required this.onScrollDown,
  });

  final String char;
  final VoidCallback onScrollUp;
  final VoidCallback onScrollDown;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            if (event.scrollDelta.dy < 0) {
              onScrollUp();
            } else if (event.scrollDelta.dy > 0) {
              onScrollDown();
            }
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            // Metade de cima do dígito = incrementa, metade de baixo =
            // decrementa — dá pra tocar sem precisar de gesto de arrastar.
            final box = context.findRenderObject() as RenderBox;
            final localY = details.localPosition.dy;
            if (localY < box.size.height / 2) {
              onScrollUp();
            } else {
              onScrollDown();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              char,
              style: monoStyle(
                fontSize: 40,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: AppColors.accent,
              ).copyWith(
                shadows: [
                  Shadow(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
