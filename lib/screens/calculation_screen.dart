import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../data/rank_requirements.dart';
import '../models/event.dart';
import '../models/event_group.dart';
import '../services/advancement_service.dart';
import '../services/branding_service.dart';
import '../services/calculation_pdf_service.dart';
import '../services/event_service.dart';
import '../services/ollama_classifier.dart';
import '../services/requirement_calculator.dart';
import '../services/scout_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_dates.dart';
import '../widgets/load_error.dart';
import '../widgets/event_plan_tab.dart';

/// Two tabs sharing one event picker. Event Calculations shows which rank
/// requirements each attending scout could complete at the event, and Event
/// Plans is for planning the meeting or event itself.
class CalculationScreen extends StatefulWidget {
  const CalculationScreen({super.key, this.sectionClassifier});

  /// Replaces the local Ollama classifier, for tests.
  final OllamaSectionClassifier? sectionClassifier;

  @override
  State<CalculationScreen> createState() => _CalculationScreenState();
}

class _CalculationScreenState extends State<CalculationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  bool _loading = true;
  Object? _error;
  List<EventGroup> _events = [];
  List<ScoutProgress> _scouts = [];
  bool _includePast = false;
  String? _eventId;
  final Set<String> _attending = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<List<EventGroup>> _readEvents() async {
    final loaded = await EventService.load();
    final seen = <String>{};
    return EventGroup.combine(
      loaded.where((event) => seen.add(event.id)).toList(),
    );
  }

  /// Saving a plan only changes events, so this skips re-reading the scouts.
  Future<void> _reloadEvents() async {
    final events = await _readEvents();
    if (!mounted) return;
    setState(() => _events = events);
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
    final events = await _readEvents();
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
    if (!mounted) return;
    setState(() {
      _events = events;
      _scouts = scouts;
      _error = null;
      _loading = false;
    });
  }

  /// Hides events that have finished, but not one still under way.
  List<EventGroup> get _visibleEvents {
    if (_includePast) return _events;
    final today = DateTime.parse(AppDates.dayKey(DateTime.now()));
    return _events.where((group) => !group.end.isBefore(today)).toList();
  }

  EventGroup? get _selectedGroup {
    for (final group in _visibleEvents) {
      if (group.id == _eventId) return group;
    }
    return null;
  }

  Event? get _selectedEvent => _selectedGroup?.first;

  String _eventLabel(EventGroup group) {
    final type = group.first.type.isEmpty ? '' : ' (${group.first.type})';
    return '${group.dateLabel} - ${group.first.title}$type';
  }

  List<ScoutProgress> get _attendingScouts =>
      _scouts.where((scout) => _attending.contains(scout.name)).toList();

  /// True once there are results on screen to print.
  bool get _canPrint {
    final event = _selectedEvent;
    return event != null &&
        _attendingScouts.isNotEmpty &&
        RequirementCalculator.settingsFor(event.type).isNotEmpty;
  }

  Future<void> _print() async {
    final event = _selectedEvent;
    if (event == null) return;
    try {
      final troopName =
          await BrandingService.loadTroopName() ?? 'Troop Manager';
      final logo = await BrandingService.loadTroopLogo();
      final bytes = await CalculationPdfService.build(
        event: event,
        dateLabel: _selectedGroup?.dateLabel,
        troopName: troopName,
        logoBytes: logo?.bytes,
        results: [
          for (final scout in _attendingScouts)
            ScoutRequirements(
              scout,
              RequirementCalculator.available(event, scout),
            ),
        ],
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'requirements_${AppDates.dayKey(event.date!)}.pdf',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Printing failed: $error')));
    }
  }

  void _toggleScout(String name, bool attending) {
    setState(() {
      if (attending) {
        _attending.add(name);
      } else {
        _attending.remove(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculation Page'),
        actions: [
          if (_tabs.index == 0)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: _canPrint
                  ? 'Print requirements'
                  : 'Choose an event and scouts to print',
              onPressed: _canPrint ? _print : null,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Event Calculations'),
            Tab(text: 'Event Plans'),
          ],
        ),
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
          : TabBarView(
              controller: _tabs,
              children: [
                ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    _buildEventCard(),
                    _buildScoutsCard(),
                    ..._buildResults(),
                  ],
                ),
                EventPlanTab(
                  key: ValueKey('plan|${_selectedEvent?.id}'),
                  eventPicker: _buildEventCard(),
                  days: _selectedGroup?.days ?? const [],
                  scouts: _attendingScouts.isEmpty ? _scouts : _attendingScouts,
                  onSavedToCalendar: _reloadEvents,
                  sectionClassifier: widget.sectionClassifier,
                ),
              ],
            ),
    );
  }

  Widget _heading(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.scoutingDarkBlue,
      ),
    );
  }

  Widget _note(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppTheme.scoutingWarmGray),
    );
  }

  Widget _buildEventCard() {
    final events = _visibleEvents;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Event'),
            const SizedBox(height: 8),
            if (events.isEmpty)
              _note(
                _events.isEmpty
                    ? 'No events yet. Add one on the Event Page or import a calendar.'
                    : 'No upcoming events. Turn on past events below.',
              )
            else
              DropdownButton<String>(
                value: _selectedEvent?.id,
                isExpanded: true,
                hint: const Text('Choose an event'),
                items: [
                  for (final event in events)
                    DropdownMenuItem<String>(
                      value: event.id,
                      child: Text(
                        _eventLabel(event),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => setState(() => _eventId = id),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Include past events'),
              value: _includePast,
              onChanged: (value) => setState(() => _includePast = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoutsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _heading('Scouts attending')),
                if (_scouts.isNotEmpty) ...[
                  TextButton(
                    onPressed: () => setState(
                      () => _attending
                        ..clear()
                        ..addAll(_scouts.map((scout) => scout.name)),
                    ),
                    child: const Text('All'),
                  ),
                  TextButton(
                    onPressed: () => setState(_attending.clear),
                    child: const Text('None'),
                  ),
                ],
              ],
            ),
            if (_scouts.isEmpty)
              _note(
                'No scouts yet. Add them on the Scout Page or import a roster.',
              )
            else
              for (final scout in _scouts)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(scout.name),
                  subtitle: scout.rank.isEmpty ? null : Text(scout.rank),
                  value: _attending.contains(scout.name),
                  onChanged: (value) =>
                      _toggleScout(scout.name, value ?? false),
                ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResults() {
    final event = _selectedEvent;
    final attending = _attendingScouts;
    if (event == null || attending.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: _note(
              'Choose an event and at least one scout to see results.',
            ),
          ),
        ),
      ];
    }
    if (RequirementCalculator.settingsFor(event.type).isEmpty) {
      final type = event.type.isEmpty ? 'unlabeled' : event.type;
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No rank requirements are tied to $type events. Edit the '
              'event\'s type on the Event Page if this looks wrong.',
            ),
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
        child: _heading('Requirements at this event'),
      ),
      for (final scout in attending)
        _buildScoutResult(event, scout, attending.length <= 3),
      Padding(
        padding: const EdgeInsets.all(8),
        child: _note(RequirementCalculator.disclaimer),
      ),
    ];
  }

  Widget _buildScoutResult(Event event, ScoutProgress scout, bool expanded) {
    final requirements = RequirementCalculator.available(event, scout);
    final count = requirements.length;
    return Card(
      child: ExpansionTile(
        key: ValueKey('${event.id}|${scout.name}'),
        initiallyExpanded: expanded,
        title: Text(scout.name),
        subtitle: Text(count == 1 ? '1 requirement' : '$count requirements'),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (requirements.isEmpty)
            const ListTile(
              dense: true,
              title: Text(RequirementCalculator.nothingLeft),
            ),
          for (final requirement in requirements) _requirementTile(requirement),
          if (scout.unreadableRows > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _note(
                RequirementCalculator.unreadableNote(scout.unreadableRows),
              ),
            ),
        ],
      ),
    );
  }

  Widget _requirementTile(RankRequirement requirement) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.checklist, size: 20),
      title: Text('${requirement.rank} ${requirement.id}'),
      subtitle: Text(requirement.displaySummary),
    );
  }
}
