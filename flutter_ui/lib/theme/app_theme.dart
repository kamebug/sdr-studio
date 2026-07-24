import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta do SDR Studio — inspirada nas convenções de cor de cockpits
/// de vidro (glass cockpit) da aviação: ciano para valores selecionados/
/// inseridos manualmente, magenta para o canal ativo secundário, âmbar
/// para alertas, verde para estado normal, vermelho para alertas
/// críticos. Essas são convenções padrão da indústria aeronáutica
/// (usadas por vários fabricantes de aviônica), não uma reprodução da
/// identidade visual registrada de nenhuma marca específica.
class AppColors {
  AppColors._();

  static const background = Color(0xFF060B12);
  static const panel = Color(0xFF0D1520);
  static const border = Color(0xFF1C2733);
  static const textPrimary = Color(0xFFE8EDF2);
  static const textMuted = Color(0xFF7A8794);

  /// Ciano — convenção de "valor selecionado/inserido manualmente" em
  /// aviônica. Acento primário: VFO ativo, controles interativos.
  static const accent = Color(0xFF00D9FF);

  /// Magenta — convenção de "canal ativo secundário/comando" em
  /// aviônica. Usado no VFO B e no marcador do VFO não-ativo.
  static const accentSecondary = Color(0xFFE619B5);

  /// Verde — convenção de "operação normal".
  static const success = Color(0xFF00E676);

  /// Vermelho — convenção de "alerta crítico".
  static const danger = Color(0xFFFF3B30);

  /// Âmbar — convenção de "caução/atenção".
  static const caution = Color(0xFFFFC400);
}

/// Estilo monoespaçado (IBM Plex Mono) — usar em TODO número que muda em
/// tempo real (frequência, dB, contadores). Dígitos de largura fixa não
/// "tremem" horizontalmente a cada atualização — o mesmo motivo pelo
/// qual instrumentos de RF reais usam displays de largura fixa.
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
        secondary: AppColors.accentSecondary,
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
        overlayColor: AppColors.accent.withValues(alpha: 0.15),
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
