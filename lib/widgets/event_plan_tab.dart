import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../data/rank_requirements.dart';
import '../models/event.dart';
import '../models/event_group.dart';
import '../models/event_plan.dart';
import '../services/branding_service.dart';
import '../services/event_plan_service.dart';
import '../services/official_form_service.dart';
import '../services/ollama_classifier.dart';
import '../services/requirement_calculator.dart';
import '../theme/app_theme.dart';
import '../utils/app_dates.dart';

/// The Event Plans tab: an agenda, the official form's questions, requirements
/// to cover and notes for one event. Drafts are kept on this device as you type.
/// Save writes the plan into the description of every day of the event, and the
/// official form button fills out the right form for the event.
class EventPlanTab extends StatefulWidget {
  const EventPlanTab({
    super.key,
    required this.eventPicker,
    required this.days,
    required this.scouts,
    required this.onSavedToCalendar,
    this.sectionClassifier,
  });

  final Widget eventPicker;

  /// Every calendar day of the chosen event, or empty if none is chosen.
  final List<Event> days;

  /// The scouts used for the "need this" counts.
  final List<ScoutProgress> scouts;

  /// Called after saving, because the events' descriptions have changed.
  final Future<void> Function() onSavedToCalendar;

  /// Sorts rows into Meeting Plan sections. Defaults to local Ollama.
  final OllamaSectionClassifier? sectionClassifier;

  @override
  State<EventPlanTab> createState() => _EventPlanTabState();
}

/// The text fields for one agenda row.
class _ItemEditor {
  final Key key = UniqueKey();

  /// True if this row started as one of the Meeting Plan's own sections. Its
  /// name is fixed, because the name is how it finds its box on the form.
  final bool isFormSection;

  /// True while the local model is working out this row's section.
  bool sorting = false;

  final TextEditingController title;
  final TextEditingController minutes;
  final TextEditingController who;
  final TextEditingController notes;
  final TextEditingController target;

  _ItemEditor(PlanItem item)
      : isFormSection = OfficialFormService.meetingSection(item.title) != null,
        title = TextEditingController(text: item.title),
        minutes = TextEditingController(
            text: item.minutes == 0 ? '' : '${item.minutes}'),
        who = TextEditingController(text: item.who),
        notes = TextEditingController(text: item.notes),
        target = TextEditingController(text: item.target);

  int get minuteCount => int.tryParse(minutes.text) ?? 0;

  PlanItem toItem() => PlanItem(
        title: title.text.trim(),
        minutes: minuteCount,
        who: who.text.trim(),
        notes: notes.text.trim(),
        target: target.text.trim(),
      );

  void dispose() {
    title.dispose();
    minutes.dispose();
    who.dispose();
    notes.dispose();
    target.dispose();
  }
}

class _EventPlanTabState extends State<EventPlanTab> {
  static const int _shortListLength = 10;

  bool _loading = true;
  final List<_ItemEditor> _items = [];
  Set<String> _requirements = {};
  final TextEditingController _notes = TextEditingController();
  final Map<String, TextEditingController> _details = {};
  bool _showAllRequirements = false;
  bool _saving = false;
  bool _filling = false;

  /// The agenda's total, kept apart so typing minutes only redraws that text
  /// instead of the whole tab.
  final ValueNotifier<String> _total = ValueNotifier('');

  /// Row names already sorted or left alone, so they aren't asked about again.
  final Set<String> _settledTitles = {};
  late final OllamaSectionClassifier _classifier =
      widget.sectionClassifier ?? OllamaSectionClassifier();

  Event? get _event => widget.days.isEmpty ? null : widget.days.first;

  EventGroup? get _group =>
      widget.days.isEmpty ? null : EventGroup(widget.days);

  OfficialForm? get _form {
    final group = _group;
    return group == null ? null : OfficialFormService.formFor(group);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    for (final controller in _details.values) {
      controller.dispose();
    }
    _notes.dispose();
    _total.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final event = _event;
    if (event == null) return;
    final plan = await EventPlanService.load(event);
    if (!mounted) return;
    setState(() {
      _items.addAll(plan.items.map(_ItemEditor.new));
      _requirements = {...plan.requirements};
      _notes.text = plan.notes;
      // Answers for other forms stay in the plan if the event's type changes.
      plan.details.forEach((key, value) {
        _details[key] = TextEditingController(text: value);
      });
      for (final field in OfficialFormService.detailFields(_form!)) {
        _details.putIfAbsent(field.key, TextEditingController.new);
      }
      _total.value = _totalLabel;
      _loading = false;
    });
  }

  EventPlan _currentPlan(Event event) => EventPlan(
        eventId: event.id,
        items: _items.map((item) => item.toItem()).toList(),
        requirements: _requirements,
        notes: _notes.text.trim(),
        details: {
          for (final entry in _details.entries)
            if (entry.value.text.trim().isNotEmpty)
              entry.key: entry.value.text.trim(),
        },
      );

  void _save() {
    final event = _event;
    if (event == null) return;
    EventPlanService.save(_currentPlan(event));
  }

  void _change(VoidCallback change) {
    setState(change);
    _total.value = _totalLabel;
    _save();
  }

  Future<void> _saveToCalendar() async {
    final event = _event;
    if (event == null) return;
    setState(() => _saving = true);
    final dayCount = widget.days.length;
    try {
      await EventPlanService.saveToCalendar(_currentPlan(event), widget.days);
      await widget.onSavedToCalendar();
      if (!mounted) return;
      _showMessage(dayCount == 1
          ? 'Plan saved to the calendar'
          : 'Plan saved to all $dayCount days on the calendar');
    } catch (error) {
      if (mounted) _showMessage('Could not save the plan: $error');
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _fillOfficialForm() async {
    final group = _group;
    if (group == null) return;
    setState(() => _filling = true);
    try {
      // Sort rows still waiting, so they reach the form's boxes.
      for (final item in [..._items]) {
        await _sortRow(item);
      }
      if (!mounted) return;
      final plan = _currentPlan(group.first);
      await EventPlanService.save(plan);
      final troopName = await BrandingService.loadTroopName() ?? '';
      final bytes = await OfficialFormService.build(
        group: group,
        plan: plan,
        troopName: troopName,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'plan_${AppDates.dayKey(group.start)}.pdf',
      );
    } catch (error) {
      if (mounted) _showMessage('Could not fill out the form: $error');
    }
    if (mounted) setState(() => _filling = false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Puts a Meeting Plan row written in someone's own words into the section it
  /// means, asking the local model unless the name already matches one.
  Future<void> _sortRow(_ItemEditor item) async {
    if (!mounted ||
        _form != OfficialForm.meetingPlan ||
        item.isFormSection ||
        item.sorting ||
        !_items.contains(item)) {
      return;
    }
    final title = item.title.text.trim();
    if (title.isEmpty || _settledTitles.contains(title)) return;

    final known = OfficialFormService.meetingSection(title);
    if (known != null) {
      _mergeIntoSection(item, known);
      return;
    }

    setState(() => item.sorting = true);
    final result = await _classifier.classify(title);
    if (!mounted || !_items.contains(item)) return;
    setState(() => item.sorting = false);
    if (item.title.text.trim() != title) return;

    final section = result.section;
    if (section != null) {
      _mergeIntoSection(item, section);
    } else if (result.reachable) {
      _settledTitles.add(title);
      _showMessage('"$title" didn\'t match a section, so it will go on the '
          'form\'s attached page.');
    } else {
      _showMessage('Couldn\'t reach Ollama to sort "$title". It will go on '
          'the form\'s attached page unless Ollama is running next time.');
    }
  }

  /// Moves [item]'s contents into [section]'s row. The row's own name is kept
  /// as description unless it only repeats the section's name.
  void _mergeIntoSection(_ItemEditor item, String section) {
    final before = _items.map((row) => row.toItem()).toList();
    final typed = item.title.text.trim();
    final sectionTitle = OfficialFormService.meetingSectionTitles[section]!;
    String simplify(String text) =>
        text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final keepName = !simplify(sectionTitle).contains(simplify(typed));

    _ItemEditor? target;
    for (final row in _items) {
      if (row != item &&
          OfficialFormService.meetingSection(row.title.text) == section) {
        target = row;
        break;
      }
    }
    final existing = target?.toItem() ?? PlanItem(title: sectionTitle);
    final moved = item.toItem();
    final merged = PlanItem(
      title: existing.title,
      minutes: existing.minutes + moved.minutes,
      who: [existing.who, moved.who].where((w) => w.isNotEmpty).join(', '),
      notes: [
        existing.notes,
        if (keepName) typed,
        moved.notes,
      ].where((n) => n.isNotEmpty).join('; '),
    );

    _change(() {
      final index = _items.indexOf(target ?? item);
      _items.removeAt(index).dispose();
      _items.insert(index, _ItemEditor(merged));
      if (target != null) {
        _items.remove(item);
        item.dispose();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Put "$typed" in $sectionTitle'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          if (!mounted) return;
          _settledTitles.add(typed);
          _change(() {
            for (final row in _items) {
              row.dispose();
            }
            _items
              ..clear()
              ..addAll(before.map(_ItemEditor.new));
          });
        },
      ),
    ));
  }

  void _move(int index, int by) {
    _change(() => _items.insert(index + by, _items.removeAt(index)));
  }

  void _remove(int index) {
    _change(() => _items.removeAt(index).dispose());
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        widget.eventPicker,
        if (event == null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: _note('Choose an event to plan it.')),
          )
        else if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _buildAgendaCard(),
          _buildFormDetailsCard(),
          _buildRequirementsCard(event),
          _buildNotesCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _filling ? null : _fillOfficialForm,
                icon: const Icon(Icons.description_outlined),
                label: Text(
                  'Fill out ${OfficialFormService.formName(_form!)}',
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveToCalendar,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _note(
              'Your draft is kept on this device as you type. Save adds the '
              'plan to the event\'s description on the calendar and PDF.',
            ),
          ),
        ],
      ],
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

  bool get _usesPhases => _form == OfficialForm.scoutWorksheet;

  String get _totalLabel {
    if (_form == OfficialForm.meetingPlan) {
      final total = OfficialFormService.meetingMinutes(
        _items.map((item) => item.toItem()).toList(),
      );
      return total == 90
          ? 'Meeting: 90 min'
          : 'Meeting: $total min (the form prints 90)';
    }
    final total = _items.fold<int>(0, (sum, item) => sum + item.minuteCount);
    return 'Total: $total min';
  }

  Widget _buildAgendaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _heading(_usesPhases ? 'Planning phases' : 'Agenda'),
                ),
                if (!_usesPhases)
                  ValueListenableBuilder<String>(
                    valueListenable: _total,
                    builder: (context, label, _) => _note(label),
                  ),
              ],
            ),
            if (_form == OfficialForm.meetingPlan) ...[
              const SizedBox(height: 4),
              _note('Add a row in your own words, like "instruction", and '
                  'your local Ollama model puts it in the matching section.'),
            ],
            const SizedBox(height: 12),
            for (var i = 0; i < _items.length; i++) _buildItem(i),
            OutlinedButton.icon(
              onPressed: () => _change(
                () => _items.add(_ItemEditor(const PlanItem(title: ''))),
              ),
              icon: const Icon(Icons.add),
              label: Text(_usesPhases ? 'Add phase' : 'Add item'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(int index) {
    final item = _items[index];
    return Padding(
      key: item.key,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (focused) {
                    if (!focused) _sortRow(item);
                  },
                  child: TextField(
                  onSubmitted: (_) => _sortRow(item),
                  controller: item.title,
                  readOnly:
                      _form == OfficialForm.meetingPlan && item.isFormSection,
                  onChanged: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: _usesPhases ? 'Phase' : 'Item',
                    isDense: true,
                    suffixIcon: item.sorting
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_usesPhases)
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: item.target,
                    decoration: const InputDecoration(
                      labelText: 'Target date',
                      isDense: true,
                    ),
                    onChanged: (_) => _save(),
                  ),
                )
              else
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: item.minutes,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration:
                        const InputDecoration(labelText: 'Min', isDense: true),
                    onChanged: (_) {
                      _total.value = _totalLabel;
                      _save();
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.who,
                  decoration: InputDecoration(
                    labelText: _usesPhases ? 'Person responsible' : 'Run by',
                    isDense: true,
                  ),
                  onChanged: (_) => _save(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Move up',
                onPressed: index == 0 ? null : () => _move(index, -1),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                tooltip: 'Move down',
                onPressed:
                    index == _items.length - 1 ? null : () => _move(index, 1),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: AppTheme.scoutingRed,
                tooltip: 'Remove item',
                onPressed: () => _remove(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.notes,
            decoration: InputDecoration(
              labelText: _usesPhases
                  ? 'Steps to completion (separate with ;)'
                  : 'Description',
              isDense: true,
            ),
            onChanged: (_) => _save(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormDetailsCard() {
    final form = _form!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('${OfficialFormService.formName(form)} details'),
            const SizedBox(height: 4),
            _note('The other questions this official form asks.'),
            const SizedBox(height: 12),
            for (final field in OfficialFormService.detailFields(form))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _details[field.key],
                  minLines: field.lines,
                  maxLines: field.lines == 1 ? 1 : null,
                  decoration: InputDecoration(
                    labelText: field.label,
                    helperText: field.hint.isEmpty ? null : field.hint,
                    isDense: true,
                  ),
                  onChanged: (_) => _save(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _keyOf(RankRequirement requirement) =>
      '${requirement.rank} ${requirement.id}';

  /// How many of the scouts could still complete each requirement here.
  Map<String, int> _needCounts(Event event) {
    final counts = <String, int>{};
    for (final scout in widget.scouts) {
      for (final requirement in RequirementCalculator.available(event, scout)) {
        final key = _keyOf(requirement);
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  Widget _buildRequirementsCard(Event event) {
    final counts = _needCounts(event);
    final options = [
      for (final requirement in rankRequirements)
        if (counts.containsKey(_keyOf(requirement)) ||
            _requirements.contains(_keyOf(requirement)))
          requirement,
    ];
    // Catalog order breaks ties, because List.sort isn't stable.
    final order = {
      for (var i = 0; i < options.length; i++) _keyOf(options[i]): i,
    };
    options.sort((a, b) {
      final byNeed =
          (counts[_keyOf(b)] ?? 0).compareTo(counts[_keyOf(a)] ?? 0);
      return byNeed != 0
          ? byNeed
          : order[_keyOf(a)]!.compareTo(order[_keyOf(b)]!);
    });

    var shown = options;
    if (!_showAllRequirements) {
      shown = [
        for (var i = 0; i < options.length; i++)
          if (i < _shortListLength || _requirements.contains(_keyOf(options[i])))
            options[i],
      ];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Requirements to cover'),
            const SizedBox(height: 4),
            _note(options.isEmpty
                ? 'No rank requirements to suggest for this event. It may be '
                    'a type with none tied to it, or no listed scout needs any.'
                : 'Most needed first, for the scouts ticked on the Event '
                    'Calculations tab, or everyone if none are ticked.'),
            for (final requirement in shown)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(_keyOf(requirement)),
                subtitle: Text(
                  '${requirement.summary}\n'
                  '${counts[_keyOf(requirement)] ?? 0} of '
                  '${widget.scouts.length} scouts need this',
                ),
                value: _requirements.contains(_keyOf(requirement)),
                onChanged: (selected) => _change(() {
                  if (selected == true) {
                    _requirements.add(_keyOf(requirement));
                  } else {
                    _requirements.remove(_keyOf(requirement));
                  }
                }),
              ),
            if (options.length > _shortListLength)
              TextButton(
                onPressed: () => setState(
                  () => _showAllRequirements = !_showAllRequirements,
                ),
                child: Text(_showAllRequirements
                    ? 'Show fewer'
                    : 'Show all ${options.length}'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Materials and notes'),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Gear to bring, who to contact, reminders...',
              ),
              onChanged: (_) => _save(),
            ),
          ],
        ),
      ),
    );
  }
}
