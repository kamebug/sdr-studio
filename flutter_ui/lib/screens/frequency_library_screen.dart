import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../sdr_core_bridge.dart';

class FrequencyLibraryScreen extends StatefulWidget {
  const FrequencyLibraryScreen({super.key, required this.bridge});

  final SdrCoreBridge bridge;

  @override
  State<FrequencyLibraryScreen> createState() =>
      _FrequencyLibraryScreenState();
}

class _FrequencyLibraryScreenState extends State<FrequencyLibraryScreen> {
  List<Map<String, dynamic>> _frequencies = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _frequencies = widget.bridge.listFrequencies();
    });
  }

  Future<void> _showAddDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final freqController = TextEditingController();
    String mode = 'FM';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.addFrequency),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.frequency),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: freqController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Hz'),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: mode,
                items: const [
                  DropdownMenuItem(value: 'AM', child: Text('AM')),
                  DropdownMenuItem(value: 'FM', child: Text('FM')),
                ],
                onChanged: (v) => setDialogState(() => mode = v ?? 'FM'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final freqHz = double.tryParse(freqController.text) ?? 0;
                widget.bridge.addFrequency(
                  freqHz: freqHz,
                  mode: mode,
                  name: nameController.text,
                );
                Navigator.of(dialogContext).pop();
                _reload();
              },
              child: Text(l10n.confirm),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.frequencyLibrary)),
      body: _frequencies.isEmpty
          ? Center(
              child: Text(
                l10n.frequencyLibrary,
                style: const TextStyle(color: Colors.white38),
              ),
            )
          : ListView.builder(
              itemCount: _frequencies.length,
              itemBuilder: (context, index) {
                final item = _frequencies[index];
                final isFavorite = item['is_favorite'] == true;
                final freqHz = item['frequency_hz'];
                final name = (item['name'] as String?) ?? '';

                return ListTile(
                  leading: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite ? Colors.amber : null,
                    ),
                    onPressed: () {
                      widget.bridge.toggleFavorite(item['id'] as int);
                      _reload();
                    },
                  ),
                  title: Text(name.isEmpty ? '$freqHz Hz' : name),
                  subtitle: Text('$freqHz Hz — ${item['mode']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      widget.bridge.deleteFrequency(item['id'] as int);
                      _reload();
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: l10n.addFrequency,
        child: const Icon(Icons.add),
      ),
    );
  }
}
