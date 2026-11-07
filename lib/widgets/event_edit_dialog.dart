import 'package:flutter/material.dart';

import '../models/event.dart';
import '../services/event_service.dart';

/// Dialog for editing an existing [Event]: change its name, type, date,
/// location or description. Changes persist through [EventService.update], so
/// the event keeps its id and edits to imported events survive re-imports. The
/// description is what shows on the year-calendar PDF export in place of the
/// location column. Pops `true` when saved and `false` when cancelled.
class EventEditDialog extends StatefulWidget {
  const EventEditDialog({super.key, required this.event});

  final Event event;

  @override
  State<EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends State<EventEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late String _type;
  late DateTime _date;

  static const List<String> _types = [
    'Court of Honor',
    'Swim',
    'Elections',
    'Meeting',
    'Campout',
    'Service Project',
    'Advancement',
    'Roundtable',
    'No Meeting',
    'Event',
    'Special Event',
    'Holiday',
    'PLC',
    'Committee',
    'Council Activity',
    'OA',
    'Hunting',
    'Task',
    'Fundraiser',
    'Hike',
    'Other',
  ];

  /// An event can carry a type outside [_types] (for example from an older
  /// import), and the dropdown requires its value to be one of its items.
  List<String> get _typeOptions =>
      _types.contains(_type) ? _types : [..._types, _type];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.event.title);
    _location = TextEditingController(text: widget.event.location);
    _description = TextEditingController(text: widget.event.description);
    _type = widget.event.type.isEmpty ? 'Event' : widget.event.type;
    _date = widget.event.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final original = widget.event;
    final edited = Event(
      id: original.id,
      title: _title.text.trim().isEmpty ? original.title : _title.text.trim(),
      date: _date,
      location: _location.text.trim(),
      type: _type,
      description: _description.text.trim(),
      activities: original.activities,
    );
    await EventService.update(edited);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Event name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final type in _typeOptions)
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: (value) =>
                  setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_dateLabel(_date)),
              leading: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 1,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: 'Description (shown on PDF export)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await _save();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
