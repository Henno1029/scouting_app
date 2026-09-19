import 'package:flutter/material.dart';

import 'services/advancement_service.dart';
import 'services/scout_service.dart';
import 'theme/app_theme.dart';

class ScoutDetailScreen extends StatefulWidget {
  final Map<String, String> scout;

  const ScoutDetailScreen({super.key, required this.scout});

  @override
  ScoutDetailScreenState createState() => ScoutDetailScreenState();
}

class ScoutDetailScreenState extends State<ScoutDetailScreen> {
  List<AdvancementEntry> _advancements = [];
  List<AdvancementEntry> _requirements = [];
  String? _importedRank;
  bool _loading = true;

  Map<String, String> get _scout => widget.scout;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final name = _scout['name'] ?? '';
    final advancements = await AdvancementService.importedAdvancements(name);
    final requirements = await AdvancementService.importedRequirements(name);
    final rank = await AdvancementService.importedRank(name);
    if (!mounted) return;
    setState(() {
      _advancements = advancements;
      _requirements = requirements;
      _importedRank = rank;
      _loading = false;
    });
  }

  int _typeWeight(String type) {
    final lower = type.toLowerCase();
    if (lower == 'rank') return 0;
    if (lower.startsWith('merit badge')) return 1;
    if (lower.startsWith('award')) return 2;
    return 3;
  }

  int _compareTypes(String a, String b) {
    final byWeight = _typeWeight(a).compareTo(_typeWeight(b));
    if (byWeight != 0) return byWeight;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  int _compareEntries(String type, AdvancementEntry a, AdvancementEntry b) {
    if (type.toLowerCase() == 'rank') {
      final ai = AdvancementService.rankOrder.indexOf(a.title);
      final bi = AdvancementService.rankOrder.indexOf(b.title);
      if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
      if (ai >= 0) return 1;
      if (bi >= 0) return -1;
    }
    return a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase());
  }

  Future<void> _showEditDialog() async {
    final nameController = TextEditingController(text: _scout['name'] ?? '');
    final patrolController =
        TextEditingController(text: _scout['patrol'] ?? '');
    final formKey = GlobalKey<FormState>();
    var selectedRank = _scout['rank'] ?? '';
    final rankOptions = <String>[
      ...ScoutService.ranks,
      if (selectedRank.isNotEmpty &&
          !ScoutService.ranks.contains(selectedRank))
        selectedRank,
    ];
    if (selectedRank.isEmpty) selectedRank = rankOptions.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Scout'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Scout\'s Name'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter a name'
                      : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedRank,
                  decoration: const InputDecoration(labelText: 'Rank'),
                  items: rankOptions
                      .map((rank) => DropdownMenuItem<String>(
                            value: rank,
                            child: Text(rank),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) selectedRank = value;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: patrolController,
                  decoration: const InputDecoration(
                    labelText: 'Patrol',
                    hintText: 'Leave blank for no patrol',
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;
    final originalName = _scout['name'] ?? '';
    final updated = {
      'name': nameController.text.trim(),
      'rank': selectedRank,
      'patrol': patrolController.text.trim(),
    };
    await ScoutService.updateScout(originalName, updated);
    if (!mounted) return;
    setState(() {
      _scout['name'] = updated['name']!;
      _scout['rank'] = updated['rank']!;
      _scout['patrol'] = updated['patrol']!;
    });
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scout updated')),
    );
  }

  IconData _typeIcon(String type) {
    final lower = type.toLowerCase();
    if (lower == 'rank') return Icons.military_tech;
    if (lower.startsWith('merit badge')) return Icons.workspace_premium;
    if (lower.startsWith('award')) return Icons.emoji_events;
    return Icons.assignment_turned_in;
  }

  Widget _section(String type, List<AdvancementEntry> entries) {
    entries.sort((a, b) => _compareEntries(type, a, b));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(type, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text('${entries.length}',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 4),
        ...entries.map((entry) {
          final details = <String>[
            if (entry.date.isNotEmpty) 'Completed ${entry.date}',
            if (entry.version.isNotEmpty) 'v${entry.version}',
          ];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(_typeIcon(type), color: AppTheme.scoutingBlue),
            title: Text(entry.displayTitle),
            subtitle: details.isEmpty ? null : Text(details.join(' • ')),
            trailing: entry.awarded
                ? const Icon(Icons.verified, color: Colors.green, size: 20)
                : entry.approved
                    ? const Icon(Icons.check_circle_outline, size: 20)
                    : null,
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _requirementsTile() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Requirement progress (${_requirements.length})'),
      subtitle: const Text('Individual requirements recorded in Scoutbook'),
      children: _requirements.map((entry) {
        return ListTile(
          contentPadding: const EdgeInsets.only(left: 16),
          dense: true,
          leading: const Icon(Icons.checklist, size: 20),
          title: Text(entry.title),
          subtitle: Text(entry.type),
          trailing: entry.date.isEmpty
              ? null
              : Text(entry.date, style: Theme.of(context).textTheme.bodySmall),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rank = _importedRank ?? _scout['rank'] ?? '';
    final patrol = _scout['patrol'] ?? '';
    final groups = <String, List<AdvancementEntry>>{};
    for (final entry in _advancements) {
      groups.putIfAbsent(entry.type, () => []).add(entry);
    }
    final types = groups.keys.toList()..sort(_compareTypes);

    return Scaffold(
      appBar: AppBar(
        title: Text(_scout['name'] ?? 'Scout Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit scout',
            onPressed: _showEditDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person, size: 36),
                  title: Text(
                    _scout['name'] ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  subtitle: Text(patrol.isEmpty
                      ? rank
                      : '${rank.isEmpty ? '' : '$rank • '}$patrol'),
                ),
                const Divider(),
                Text(
                  'Advancement',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (types.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No advancement data yet. Use Upload Data to import a '
                      'Scoutbook advancement export.',
                    ),
                  )
                else
                  ...types.map((type) => _section(type, groups[type]!)),
                if (_requirements.isNotEmpty) _requirementsTile(),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _showEditDialog,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Scout'),
                ),
              ],
            ),
    );
  }
}
