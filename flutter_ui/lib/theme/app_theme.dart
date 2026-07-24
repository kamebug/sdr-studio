import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta do SDR Studio — inspirada nos princípios de instrumentos de
/// laboratório digitais (painéis escuros, hierarquia clara, números
/// monoespaçados), sem copiar a identidade visual de nenhuma marca real.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0B0E11);
  static const panel = Color(0xFF151A20);
  static const border = Color(0xFF262C34);
  static const textPrimary = Color(0xFFE7EBF0);
  static const textMuted = Color(0xFF7C8794);

  /// Âmbar — único acento "quente" da interface, reservado para
  /// controles interativos. Contrasta de propósito com a rampa fria do
  /// waterfall (preto → azul → ciano → amarelo → vermelho), separando
  /// visualmente "dado" (frio) de "controle" (quente).
  static const accent = Color(0xFFFF9F40);

  static const success = Color(0xFF4CD37A);
  static const danger = Color(0xFFFF5C5C);
}

/// Estilo monoespaçado (IBM Plex Mono) — usar em TODO número que muda em
/// tempo real (frequência, dB, contadores). Dígitos de largura fixa não
/// "tremem" horizontalmente a cada atualização — o mesmo motivo pelo
/// qual instrumentos de RF reais usam displays de largura fixa. Decisão
/// funcional, não só estética.
TextStyle monoStyle({
  double fontSize = 14,
  Color color = AppColors.textPrimary,
  FontWeight fontWeight = FontWeight.w500,
  double? letterSpacing,
}) {
  return GoogleFonts.ibmPlexMono(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.ibmPlexSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.panel,
        primary: AppColors.accent,
        secondary: AppColors.accent,
        error: AppColors.danger,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.panel,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.border, thickness: 1),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withOpacity(0.15),
        valueIndicatorColor: AppColors.panel,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textMuted,
        textColor: AppColors.textPrimary,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.panel),
    );
  }
}
