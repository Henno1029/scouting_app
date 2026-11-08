import 'package:flutter/material.dart';

import '../services/badge_planner_service.dart';
import '../theme/app_theme.dart';

/// Type the merit badges a camp or event offers and see who still needs each,
/// Eagle-required badges first.
class BadgePlannerScreen extends StatefulWidget {
  const BadgePlannerScreen({super.key});

  @override
  State<BadgePlannerScreen> createState() => _BadgePlannerScreenState();
}

class _BadgePlannerScreenState extends State<BadgePlannerScreen> {
  final TextEditingController _badges = TextEditingController();
  List<BadgeNeed> _plan = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _badges.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _badges.text = await BadgePlannerService.loadList();
    await _refresh();
  }

  Future<void> _refresh() async {
    try {
      final plan = await BadgePlannerService.plan(
        BadgePlannerService.parseList(_badges.text),
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _changed() {
    BadgePlannerService.saveList(_badges.text);
    _refresh();
  }

  void _add(String badge) {
    final current = BadgePlannerService.parseList(_badges.text);
    if (current.any((b) => b.toLowerCase() == badge.toLowerCase())) return;
    _badges.text = [...current, badge].join('\n');
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merit Badge Planner')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Badges on offer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.scoutingDarkBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Type the merit badges summer camp or a merit badge day '
                    'offers, one per line or separated by commas.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.scoutingWarmGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _badges,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: 'Swimming\nFirst Aid\nArchery',
                    ),
                    onChanged: (_) => _changed(),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add an Eagle-required badge:',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final badge
                          in BadgePlannerService.eagleRequiredNames)
                        ActionChip(
                          label: Text(badge),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _add(badge),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load the troop: $_error',
                style: const TextStyle(color: AppTheme.scoutingRed),
              ),
            )
          else if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_plan.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Add some badges above to see who needs them.',
                  style: TextStyle(color: AppTheme.scoutingWarmGray),
                ),
              ),
            )
          else
            for (final need in _plan) _buildNeed(need),
        ],
      ),
    );
  }

  Widget _buildNeed(BadgeNeed need) {
    return Card(
      child: ExpansionTile(
        leading: Icon(
          need.eagleRequired ? Icons.star : Icons.workspace_premium,
          color: need.eagleRequired
              ? AppTheme.scoutingRed
              : AppTheme.scoutingBlue,
        ),
        title: Text(need.badge),
        subtitle: Text(
          [
            '${need.needIt.length} still need it',
            if (need.started.isNotEmpty) '${need.started.length} started',
            if (need.eagleRequired) 'Eagle-required',
          ].join(' • '),
        ),
        children: [
          for (final name in need.needIt)
            ListTile(
              dense: true,
              title: Text(name),
              trailing: need.started.contains(name)
                  ? const Text(
                      'Started',
                      style: TextStyle(color: AppTheme.scoutingWarmGray),
                    )
                  : null,
            ),
          if (need.earned.isNotEmpty)
            ListTile(
              dense: true,
              title: Text(
                'Already earned: ${need.earned.join(', ')}',
                style: const TextStyle(color: AppTheme.scoutingWarmGray),
              ),
            ),
        ],
      ),
    );
  }
}
