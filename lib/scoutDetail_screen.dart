import 'package:flutter/material.dart';

import 'services/merit_badge_service.dart';
import 'theme/app_theme.dart';

class ScoutDetailScreen extends StatefulWidget {
  final Map<String, String> scout;

  const ScoutDetailScreen({super.key, required this.scout});

  @override
  ScoutDetailScreenState createState() => ScoutDetailScreenState();
}

class ScoutDetailScreenState extends State<ScoutDetailScreen> {
  List<MeritBadge> _manualBadges = [];
  List<MeritBadge> _importedBadges = [];
  String? _importedRank;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final name = widget.scout['name'] ?? '';
    final imported = await MeritBadgeService.importedMeritBadges(name);
    final rank = await MeritBadgeService.importedRank(name);
    if (!mounted) return;
    setState(() {
      _manualBadges = MeritBadgeService.manualBadges(widget.scout);
      _importedBadges = imported;
      _importedRank = rank;
      _loading = false;
    });
  }

  Future<void> _removeBadge(String name) async {
    setState(() {
      _manualBadges = _manualBadges
          .where((badge) => badge.name != name)
          .toList(growable: true);
    });
    await MeritBadgeService.saveBadges(_manualSaveName, _manualBadges);
  }

  String get _manualSaveName => widget.scout['name'] ?? '';

  Future<void> _showAddBadgeDialog() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime? pickedDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Merit Badge'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Badge name'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter a badge name'
                      : null,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: dialogContext,
                      initialDate: pickedDate ?? now,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if (date != null) pickedDate = date;
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date earned (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(pickedDate == null
                        ? 'Tap to pick a date'
                        : '${pickedDate!.month}/${pickedDate!.day}/${pickedDate!.year}'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    final title = nameController.text.trim();
    final date = pickedDate == null
        ? ''
        : '${pickedDate!.month}/${pickedDate!.day}/${pickedDate!.year}';
    setState(() {
      _manualBadges = [..._manualBadges, MeritBadge(title, date)]
        ..sort((a, b) => a.name.compareTo(b.name));
    });
    await MeritBadgeService.saveBadges(_manualSaveName, _manualBadges);
  }

  @override
  Widget build(BuildContext context) {
    final scout = widget.scout;
    final patrol = scout['patrol'] ?? '';
    final allBadges = <String, MeritBadge>{
      for (final badge in _importedBadges) badge.name: badge,
      for (final badge in _manualBadges) badge.name: badge,
    };

    return Scaffold(
      appBar: AppBar(title: Text(scout['name'] ?? 'Scout Detail')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person),
                  title: Text(scout['name'] ?? ''),
                  subtitle: Text(patrol.isEmpty
                      ? (scout['rank'] ?? '')
                      : '${scout['rank']} • $patrol'),
                ),
                const Divider(),
                Text(
                  'Advancement',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_importedRank != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.military_tech),
                    title: const Text('Rank'),
                    subtitle: Text(_importedRank!),
                  ),
                Row(
                  children: [
                    Text(
                      'Merit Badges',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${allBadges.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'From Scoutbook import and manual entries.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (allBadges.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No merit badges yet.'),
                  )
                else
                  ...allBadges.values.map((badge) {
                    final imported = _importedBadges.any(
                        (b) => b.name == badge.name);
                    final manual = _manualBadges
                        .any((b) => b.name == badge.name);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        imported ? Icons.assignment_turned_in : Icons.workspace_premium,
                        color: imported ? AppTheme.scoutingBlue : null,
                      ),
                      title: Text(badge.name),
                      subtitle: badge.date.isEmpty
                          ? null
                          : Text('Earned ${badge.date}'),
                      trailing: manual
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: 'Remove badge',
                              color: Colors.red,
                              onPressed: () => _removeBadge(badge.name),
                            )
                          : const Icon(Icons.link, size: 18),
                    );
                  }),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showAddBadgeDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Merit Badge'),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Editing not implemented yet.')),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Scout'),
                ),
              ],
            ),
    );
  }
}