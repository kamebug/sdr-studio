import 'package:flutter/material.dart';

import '../models/vfo_state.dart';
import '../theme/app_theme.dart';
import '../utils/frequency_format.dart';

/// Card compacto mostrando um VFO — usado nos painéis laterais. Tocar
/// nele torna aquele VFO o "ativo" (o que os controles centrais editam).
/// Os dois VFOs tocam e aparecem no waterfall o tempo todo,
/// independente de qual está ativo — "ativo" só significa "é este que
/// os controles do meio estão editando agora".
class VfoPanel extends StatelessWidget {
  const VfoPanel({
    super.key,
    required this.label,
    required this.vfo,
    required this.isActive,
    required this.accentColor,
    required this.onTap,
    required this.onToggleMute,
  });

  final String label;
  final VfoState vfo;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? accentColor : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                InkWell(
                  onTap: onToggleMute,
                  child: Icon(
                    vfo.muted ? Icons.volume_off : Icons.volume_up,
                    size: 16,
                    color: vfo.muted ? AppColors.danger : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatFrequency(vfo.frequencyHz),
              style: monoStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              vfo.mode,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
