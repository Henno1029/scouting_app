import 'package:flutter/material.dart';

import '../models/event_group.dart';
import '../services/advancement_service.dart';
import '../services/attendance_service.dart';
import '../services/permission_service.dart';
import '../services/requirement_calculator.dart';
import '../services/scout_service.dart';
import '../theme/app_theme.dart';
import '../widgets/event_edit_dialog.dart';
import '../widgets/load_error.dart';

/// One event: its details, who came, and what they can complete there.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.group});

  final EventGroup group;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _loading = true;
  Object? _error;
  List<ScoutProgress> _scouts = [];
  final Set<String> _present = {};
  final TextEditingController _hours = TextEditingController();
  bool _saving = false;

  EventGroup get _group => widget.group;

  bool get _isService {
    final type = _group.first.type.toLowerCase().replaceAll(' ', '');
    return type == 'service' || type == 'serviceproject';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hours.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadData() async {
    final index = await AdvancementIndex.load();
    final scouts = <ScoutProgress>[];
    for (final scout in await ScoutService.load()) {
      final name = scout['name'] ?? '';
      if (name.isEmpty) continue;
      scouts.add(
        RequirementCalculator.fromIndex(
          index,
          name,
          scout['rank'] ?? '',
          memberId: scout['memberId'] ?? '',
        ),
      );
    }
    scouts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final attendance = await AttendanceService.load(_group.id);
    if (!mounted) return;
    setState(() {
      _scouts = scouts;
      _present
        ..clear()
        ..addAll(attendance.scouts);
      _hours.text = attendance.hours;
      _error = null;
      _loading = false;
    });
  }

  Future<void> _saveAttendance() async {
    setState(() => _saving = true);
    await AttendanceService.save(_group, _present, hours: _hours.text);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _present.isEmpty
              ? 'Attendance cleared'
              : 'Saved attendance for ${_present.length} '
                    '${_present.length == 1 ? 'scout' : 'scouts'}',
        ),
      ),
    );
  }

  Future<void> _edit() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EventEditDialog(event: _group.first),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final event = _group.first;
    final canEdit = PermissionService.state.value.canEdit;
    return Scaffold(
      appBar: AppBar(
        title: Text(event.title),
        actions: [
          if (canEdit && !_group.isMultiDay)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit event',
              onPressed: _edit,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? LoadError(
              error: _error!,
              onRetry: () {
                setState(() => _loading = true);
                _load();
              },
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                _buildInfoCard(),
                _buildAttendanceCard(canEdit),
                _buildRequirementsCard(),
              ],
            ),
    );
  }

  Widget _heading(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppTheme.scoutingDarkBlue,
    ),
  );

  Widget _note(String text) => Text(
    text,
    style: const TextStyle(fontSize: 12, color: AppTheme.scoutingWarmGray),
  );

  Widget _buildInfoCard() {
    final event = _group.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(_group.dateLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (event.type.isNotEmpty)
                  Chip(
                    label: Text(event.type),
                    backgroundColor: AppTheme.eventTypeColor(event.type),
                    visualDensity: VisualDensity.compact,
                  ),
                if (_group.isMultiDay)
                  Chip(
                    label: Text('${_group.days.length} days'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(event.location)),
                ],
              ),
            ],
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(event.description),
            ],
            for (final note in event.activities)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _note(note),
              ),
            if (_group.isMultiDay)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _note(
                  'To edit one day, open it from the calendar\'s '
                  'day view.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(bool canEdit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _heading('Attendance (${_present.length})')),
                if (canEdit && _scouts.isNotEmpty) ...[
                  TextButton(
                    onPressed: () => setState(
                      () => _present
                        ..clear()
                        ..addAll(_scouts.map((s) => s.name)),
                    ),
                    child: const Text('All'),
                  ),
                  TextButton(
                    onPressed: () => setState(_present.clear),
                    child: const Text('None'),
                  ),
                ],
              ],
            ),
            if (_scouts.isEmpty)
              _note('No scouts yet. Add them on the Scout Page.')
            else
              for (final scout in _scouts)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(scout.name),
                  subtitle: scout.rank.isEmpty ? null : Text(scout.rank),
                  value: _present.contains(scout.name),
                  onChanged: canEdit
                      ? (value) => setState(() {
                          if (value == true) {
                            _present.add(scout.name);
                          } else {
                            _present.remove(scout.name);
                          }
                        })
                      : null,
                ),
            if (_isService) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _hours,
                enabled: canEdit,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Service hours for each scout',
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (canEdit)
              FilledButton.icon(
                onPressed: _saving ? null : _saveAttendance,
                icon: const Icon(Icons.how_to_reg),
                label: const Text('Save attendance'),
              ),
            const SizedBox(height: 6),
            _note(
              'Saved attendance goes into the activity report, so the '
              'Statistics printout counts these campouts, nights and service '
              'hours.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementsCard() {
    final event = _group.first;
    final ticked = _scouts.where((s) => _present.contains(s.name)).toList();
    final shown = ticked.isEmpty ? _scouts : ticked;
    final noneTied = RequirementCalculator.settingsFor(event.type).isEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Requirements they can complete'),
            const SizedBox(height: 4),
            _note(
              noneTied
                  ? 'No rank requirements are tied to this type of event.'
                  : ticked.isEmpty
                  ? 'Showing everyone. Tick who came to narrow this down.'
                  : 'For the scouts ticked above.',
            ),
            if (!noneTied)
              for (final scout in shown)
                () {
                  final requirements = RequirementCalculator.available(
                    event,
                    scout,
                  );
                  return ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(scout.name),
                    subtitle: Text(
                      requirements.length == 1
                          ? '1 requirement'
                          : '${requirements.length} requirements',
                    ),
                    children: [
                      for (final requirement in requirements)
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 8),
                          title: Text('${requirement.rank} ${requirement.id}'),
                          subtitle: Text(requirement.displaySummary),
                        ),
                    ],
                  );
                }(),
          ],
        ),
      ),
    );
  }
}
