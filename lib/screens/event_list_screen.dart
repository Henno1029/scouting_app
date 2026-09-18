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
  bool _showMeetings = true;

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
    });
  }

  List<Event> get _displayEvents => _showMeetings
      ? _events
      : _events.where((event) => !event.isMeeting).toList();

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
                      _showMeetings
                          ? Icons.filter_alt
                          : Icons.filter_alt_off,
                    ),
                    tooltip: _showMeetings
                        ? 'Hide meetings'
                        : 'Show meetings',
                    onPressed: () => setState(() => _showMeetings = !_showMeetings),
                  ),
                ],
              ),
            ),
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
                      color: AppTheme.scoutingLightTan,
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
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: Text(
            'No events this month',
            style: TextStyle(color: AppTheme.scoutingWarmGray),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 4),
          child: Text(
            'Events this month',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.scoutingDarkBlue,
            ),
          ),
        ),
        Card(
          child: Column(
            children: monthEvents.map((event) {
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
                      final hasEvents = _eventsOn(date).isNotEmpty;
                      final isToday = AppDates.dayKey(date) == AppDates.dayKey(today);
                      return Expanded(
                        child: Container(
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday ? AppTheme.scoutingPaleBlue : Colors.white,
                          ),
                          child: Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: hasEvents ? FontWeight.bold : FontWeight.normal,
                              color: hasEvents ? AppTheme.scoutingRed : AppTheme.scoutingDarkGrey,
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