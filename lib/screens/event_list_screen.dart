import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/event.dart';
import '../services/branding_service.dart';
import '../services/event_service.dart';
import '../services/year_calendar_pdf_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_dates.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  _EventListScreenState createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _weekdayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  List<Event> _events = [];
  DateTime _view = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _yearView = false;
  bool _jumpedToEvents = false;
  final Set<String> _hiddenTypes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events = await EventService.load();
    if (!mounted) return;
    setState(() {
      _events = events;
      if (!_jumpedToEvents) {
        _jumpedToEvents = true;
        _jumpToNearestEventMonth();
      }
    });
  }

  /// Moves the view to the nearest month that actually has events when the
  /// current month is empty (e.g. right after importing next year's calendar).
  void _jumpToNearestEventMonth() {
    final dated = _events.where((event) => event.date != null).toList();
    if (dated.isEmpty) return;
    final now = DateTime.now();
    final hasCurrent = dated.any((event) =>
        event.date!.year == now.year && event.date!.month == now.month);
    if (hasCurrent) return;
    dated.sort((a, b) => a.date!.compareTo(b.date!));
    final monthStart = DateTime(now.year, now.month, 1);
    final upcoming =
        dated.where((event) => !event.date!.isBefore(monthStart)).toList();
    final target = upcoming.isNotEmpty ? upcoming.first.date! : dated.last.date!;
    _view = DateTime(target.year, target.month, 1);
  }

  List<Event> get _displayEvents => _events
      .where((event) =>
          !_hiddenTypes.contains(_typeLabel(event.type)))
      .toList();

  String _typeLabel(String type) => type.isEmpty ? 'Unlabeled' : type;

  List<String> _allTypes() {
    final types = <String>{for (final event in _events) _typeLabel(event.type)};
    final list = types.toList()..sort();
    return list;
  }

  Future<void> _showTypeFilterDialog() async {
    final types = _allTypes();
    if (types.isEmpty) return;
    final draft = Set<String>.from(_hiddenTypes);
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Show / Hide Event Types'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final type in types)
                  SwitchListTile(
                    dense: true,
                    title: Text(type),
                    subtitle: Text(_hiddenTypes.contains(type)
                        ? 'Hidden'
                        : 'Visible'),
                    value: !draft.contains(type),
                    onChanged: (visible) => setDialogState(() {
                      if (visible) {
                        draft.remove(type);
                      } else {
                        draft.add(type);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _hiddenTypes
                  ..clear()
                  ..addAll(draft));
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  List<Event> _eventsOn(DateTime day) {
    final key = AppDates.dayKey(day);
    return _displayEvents
        .where((e) => e.date != null && AppDates.dayKey(e.date!) == key)
        .toList();
  }

  void _previous() {
    setState(() {
      _view = _yearView
          ? DateTime(_view.year - 1, 1, 1)
          : DateTime(_view.year, _view.month - 1, 1);
    });
  }

  void _next() {
    setState(() {
      _view = _yearView
          ? DateTime(_view.year + 1, 1, 1)
          : DateTime(_view.year, _view.month + 1, 1);
    });
  }

  void _goToToday() {
    setState(() {
      final now = DateTime.now();
      _view = DateTime(now.year, now.month, 1);
    });
  }

  String get _title => _yearView
      ? '${_view.year}'
      : '${_monthNames[_view.month - 1]} ${_view.year}';

  ({int startCol, int daysInMonth, int weeks}) _gridInfo(DateTime first) {
    final startCol = first.weekday % 7;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    return (startCol: startCol, daysInMonth: daysInMonth, weeks: ((startCol + daysInMonth) / 7).ceil());
  }

  Future<void> _exportPdf() async {
    try {
      final year = _view.year;
      final troopName = await BrandingService.loadTroopName() ?? 'Troop Manager';
      final logo = await BrandingService.loadTroopLogo();
      final bytes = await YearCalendarPdfService.buildYearCalendar(
        year: year,
        troopName: troopName,
        logoBytes: logo?.bytes,
        events: _displayEvents,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${year}_program_calendar.pdf',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export year PDF',
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add event',
            onPressed: _addEventDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous',
                  onPressed: _previous,
                ),
                Expanded(
                  child: Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.scoutingDarkBlue,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next',
                  onPressed: _next,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.today, size: 18),
                  label: const Text('Today'),
                  onPressed: _goToToday,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.calendar_view_month),
                        label: Text('Month'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.date_range),
                        label: Text('Year'),
                      ),
                    ],
                    selected: {_yearView},
                    onSelectionChanged: (selection) =>
                        setState(() => _yearView = selection.first),
                    showSelectedIcon: false,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      _hiddenTypes.isEmpty
                          ? Icons.filter_alt_outlined
                          : Icons.filter_alt,
                    ),
                    tooltip: _hiddenTypes.isEmpty
                        ? 'Choose event types to show/hide'
                        : '${_hiddenTypes.length} type(s) hidden',
                    onPressed: _showTypeFilterDialog,
                  ),
                  if (_yearView) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined),
                      color: AppTheme.scoutingRed,
                      tooltip: 'Delete all events for ${_view.year}',
                      onPressed: _confirmDeleteAllForYear,
                    ),
                  ],
                ],
              ),
            ),
            _buildLegend(),
            Expanded(
              child: SingleChildScrollView(
                child: _yearView ? _buildYearView() : _buildMonthView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final counts = <String, int>{};
    for (final event in _displayEvents) {
      final label = event.type.isNotEmpty ? event.type : 'Unlabeled';
      counts[label] = (counts[label] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.shrink();
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final entry in entries)
            InkWell(
              key: ValueKey('legend-${entry.key}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() {
                if (!_hiddenTypes.remove(entry.key)) {
                  _hiddenTypes.add(entry.key);
                }
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _hiddenTypes.contains(entry.key)
                      ? AppTheme.scoutingWarmGray
                      : AppTheme.eventTypeColor(entry.key),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _hiddenTypes.contains(entry.key)
                            ? Colors.white
                            : AppTheme.scoutingDarkBlue,
                        decoration: _hiddenTypes.contains(entry.key)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _hiddenTypes.contains(entry.key)
                            ? Colors.white70
                            : AppTheme.scoutingWarmGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthView() {
    final grid = _gridInfo(_view);
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: _weekdayLetters.map((letter) {
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppTheme.scoutingTan),
                child: Text(
                  letter,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.scoutingDarkBlue,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        for (var week = 0; week < grid.weeks; week++)
          Row(
            children: List.generate(7, (col) {
              final dayNum = week * 7 + col - grid.startCol + 1;
              if (dayNum < 1 || dayNum > grid.daysInMonth) {
                return const Expanded(child: SizedBox.shrink());
              }
              return Expanded(
                child: _dayCell(DateTime(_view.year, _view.month, dayNum), today),
              );
            }),
          ),
        const SizedBox(height: 12),
        _buildMonthEventsList(),
      ],
    );
  }

  Widget _dayCell(DateTime day, DateTime today) {
    final events = _eventsOn(day);
    final isToday = AppDates.dayKey(day) == AppDates.dayKey(today);

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Material(
        color: isToday ? AppTheme.scoutingPaleBlue : Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _showDaySheet(day),
          child: Container(
            height: 72,
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: events.isNotEmpty
                            ? AppTheme.scoutingRed
                            : AppTheme.scoutingDarkGrey,
                      ),
                    ),
                    if (events.length > 2)
                      Text(
                        '+${events.length - 2}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.scoutingWarmGray,
                        ),
                      ),
                  ],
                ),
                for (final event in events.take(2))
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    height: 15,
                    decoration: BoxDecoration(
                      color: AppTheme.eventTypeColor(event.type),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: AppTheme.scoutingDarkBlue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthEventsList() {
    final monthEvents = _displayEvents
        .where((e) =>
            e.date != null &&
            e.date!.year == _view.year &&
            e.date!.month == _view.month)
        .toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));

    if (monthEvents.isEmpty) {
      final dated = _events.where((event) => event.date != null).toList();
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No events this month',
                style: TextStyle(color: AppTheme.scoutingWarmGray),
              ),
              if (dated.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_events.length} event(s) loaded from your calendars.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.scoutingWarmGray, fontSize: 12),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _jumpToNearestEventMonth()),
                  icon: const Icon(Icons.event_available, size: 18),
                  label: const Text('Jump to nearest events'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Events this month',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.scoutingDarkBlue,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                color: AppTheme.scoutingRed,
                tooltip: 'Delete all events for ${_monthNames[_view.month - 1]}',
                onPressed: () => _confirmDeleteAllForMonth(monthEvents),
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: monthEvents.map((event) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.eventTypeColor(event.type),
                  child: Icon(
                    _eventIcon(event.type),
                    size: 20,
                    color: AppTheme.scoutingDarkBlue,
                  ),
                ),
                title: Text(event.title),
                subtitle: Text(_eventSubtitle(event)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppTheme.scoutingRed,
                  tooltip: 'Delete event',
                  onPressed: () async {
                    await EventService.delete(event.id);
                    _load();
                  },
                ),
                onTap: () => _showDaySheet(event.date ?? _view),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildYearView() {
    return Column(
      children: [
        for (var row = 0; row < 3; row++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var col = 0; col < 4; col++)
                Expanded(child: _miniMonth(_view.year, row * 4 + col + 1)),
            ],
          ),
      ],
    );
  }

  Widget _miniMonth(int year, int month) {
    final first = DateTime(year, month, 1);
    final grid = _gridInfo(first);
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _monthNames[month - 1],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppTheme.scoutingDarkBlue,
            ),
          ),
          Row(
            children: _weekdayLetters.map((letter) {
              return Expanded(
                child: Center(
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.scoutingWarmGray,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          InkWell(
            onTap: () => setState(() {
              _view = first;
              _yearView = false;
            }),
            child: Column(
              children: [
                for (var week = 0; week < grid.weeks; week++)
                  Row(
                    children: List.generate(7, (col) {
                      final dayNum = week * 7 + col - grid.startCol + 1;
                      if (dayNum < 1 || dayNum > grid.daysInMonth) {
                        return const Expanded(child: SizedBox(height: 18));
                      }
                      final date = DateTime(year, month, dayNum);
                      final events = _eventsOn(date);
                      final hasEvents = events.isNotEmpty;
                      final isToday = AppDates.dayKey(date) == AppDates.dayKey(today);
                      return Expanded(
                        child: Container(
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday ? AppTheme.scoutingPaleBlue : Colors.white,
                          ),
                          child: hasEvents
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$dayNum',
                                      style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.scoutingDarkBlue,
                                      ),
                                    ),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: AppTheme.eventTypeColor(
                                            events.first.type),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  '$dayNum',
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    color: AppTheme.scoutingDarkGrey,
                                  ),
                                ),
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAllForMonth(List<Event> events) async {
    final monthName = _monthNames[_view.month - 1];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all events for this month?'),
        content: Text(
          'This will permanently remove all ${events.length} event(s) in $monthName ${_view.year}, including imported ones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete all',
              style: TextStyle(color: AppTheme.scoutingRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final event in events) {
      await EventService.delete(event.id);
    }
    await _load();
  }

  Future<void> _confirmDeleteAllForYear() async {
    final yearEvents = _displayEvents
        .where((e) => e.date != null && e.date!.year == _view.year)
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all events for this year?'),
        content: Text(
          'This will permanently remove all ${yearEvents.length} event(s) in '
          '${_view.year}, including imported ones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete all',
              style: TextStyle(color: AppTheme.scoutingRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final event in yearEvents) {
      await EventService.delete(event.id);
    }
    await _load();
  }

  Future<void> _showDaySheet(DateTime day) async {
    final events = _eventsOn(day);
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _formatDate(day),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.scoutingDarkBlue,
                  ),
                ),
              ),
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No events this day',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.scoutingWarmGray),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.scoutingPaleBlue,
                          child: Icon(
                            _eventIcon(event.type),
                            size: 20,
                            color: AppTheme.scoutingDarkBlue,
                          ),
                        ),
                        title: Text(event.title),
                        subtitle: Text(_eventSubtitle(event)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: AppTheme.scoutingRed,
                          onPressed: () async {
                            await EventService.delete(event.id);
                            Navigator.pop(context);
                            _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addEventDialog() async {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final notesController = TextEditingController();
    String type = 'Other';
    DateTime date = _view;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: 'Meeting', child: Text('Meeting')),
                        DropdownMenuItem(value: 'Campout', child: Text('Campout')),
                        DropdownMenuItem(value: 'Hike', child: Text('Hike')),
                        DropdownMenuItem(value: 'Service', child: Text('Service')),
                        DropdownMenuItem(value: 'Fundraiser', child: Text('Fundraiser')),
                        DropdownMenuItem(value: 'Court of Honor', child: Text('Court of Honor')),
                        DropdownMenuItem(value: 'Elections', child: Text('Elections')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => type = value ?? type),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(date.year - 5),
                          lastDate: DateTime(date.year + 5, 12, 31),
                        );
                        if (picked != null) {
                          setDialogState(() => date = picked);
                        }
                      },
                      child: Text('Date: ${_formatDate(date)}'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (one per line)',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    EventService.add(
                      Event(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        title: title,
                        date: date,
                        type: type,
                        location: locationController.text.trim(),
                        activities: notesController.text
                            .split('\n')
                            .map((line) => line.trim())
                            .where((line) => line.isNotEmpty)
                            .toList(),
                      ),
                    ).then((_) {
                      if (mounted) Navigator.pop(context);
                      _load();
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _eventSubtitle(Event event) {
    final parts = <String>[
      if (event.date != null) _formatDate(event.date!),
      if (event.type.isNotEmpty) event.type,
      if (event.location.isNotEmpty) event.location,
    ];
    return parts.join(' • ');
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  IconData _eventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Icons.event_available;
      case 'campout':
        return Icons.holiday_village;
      case 'hike':
        return Icons.hiking;
      case 'service':
        return Icons.volunteer_activism;
      case 'fundraiser':
        return Icons.attach_money;
      case 'court of honor':
        return Icons.military_tech;
      case 'holiday':
        return Icons.celebration_outlined;
      case 'roundtable':
        return Icons.handshake_outlined;
      case 'oa':
        return Icons.arrow_outward;
      default:
        return Icons.event;
    }
  }
}