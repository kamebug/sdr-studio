import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../sdr_core_bridge.dart';
import '../theme/app_theme.dart';
import '../utils/frequency_format.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.bridge});

  final SdrCoreBridge bridge;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _entries = widget.bridge.listHistory();
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.history)),
      body: _entries.isEmpty
          ? Center(
              child: Text(
                l10n.history,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _entries.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final item = _entries[index];
                final freqHz = (item['frequency_hz'] as num).toDouble();
                final mode = item['mode'];
                final listenedAt = (item['listened_at'] as String?) ?? '';
                final duration = (item['duration_seconds'] as int?) ?? 0;

                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(
                    '${formatFrequency(freqHz)} — $mode',
                    style: monoStyle(fontSize: 14),
                  ),
                  subtitle: Text(listenedAt),
                  trailing: duration > 0
                      ? Text(
                          _formatDuration(duration),
                          style: monoStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        )
                      : null,
                );
              },
            ),
    );
  }
}
