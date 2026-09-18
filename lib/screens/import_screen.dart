import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/csv_import_service.dart';
import '../services/ollama_classifier.dart';
import '../services/program_grid_parser.dart';
import '../theme/app_theme.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  _ImportScreenState createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  ImportTarget _target = CsvImportService.targets.first;
  String? _fileName;
  CsvTable _parsed = CsvTable.empty;
  CsvTable _table = CsvTable.empty;
  Map<String, String> _mapping = {};

  // Program Grid state.
  List<List<String>> _gridRows = const [];
  ProgramGridLayout _gridLayout = const ProgramGridLayout();
  List<ProgramEventDraft> _gridDrafts = const [];
  bool _useAi = false;
  bool _aiBusy = false;
  String _aiModel = 'qwen3:8b';
  String _classifyStatus = '';

  bool get _isGrid => _target.isGridLayout;

  static const List<String> _models = [
    'qwen3:8b',
    'qwen3:14b',
    'llama3.1',
    'gemma3:12b',
    'deepseek-r1:14b',
  ];

  void _setTarget(ImportTarget target) {
    setState(() {
      _target = target;
      if (!_isGrid) {
        _gridRows = const [];
        _gridDrafts = const [];
        _classifyStatus = '';
      }
      _applyTargetRows();
    });
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'tsv'],
      dialogTitle: 'Select report CSV',
    );
    if (file == null) return;
    final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    _parse(file.name, content);
  }

  void _parse(String name, String content) {
    setState(() {
      _fileName = name;
      _parsed = CsvImportService.parse(content);
      if (_isGrid) {
        _gridRows = CsvImportService.decodeRows(content);
        _gridLayout = ProgramGridParser.detect(_gridRows);
        _classifyStatus = '';
      }
      _applyTargetRows();
    });
  }

  void _applyTargetRows() {
    if (_isGrid) {
      if (_gridRows.isNotEmpty) {
        _applyGrid();
      } else {
        _table = CsvTable.empty;
      }
    } else {
      _table = _parsed;
    }
    _mapping = CsvImportService.autoMap(_target, _table.headers);
  }

  void _applyGrid() {
    final drafts = ProgramTypeClassifier.applyKeywords(
      ProgramGridParser.parse(_gridRows, layout: _gridLayout),
    );
    _gridDrafts = drafts;
    _table = _draftsTable(drafts);
  }

  CsvTable _draftsTable(List<ProgramEventDraft> drafts) {
    return CsvTable(
      headers: const ['Date', 'Title', 'Type', 'Location', 'Notes'],
      rows: drafts
          .map((d) => [
                d.date == null
                    ? ''
                    : '${d.date!.month}/${d.date!.day}/${d.date!.year}',
                d.title,
                d.type,
                d.location,
                d.notes,
              ])
          .toList(),
    );
  }

  List<String> _gridHeaders() {
    if (_gridRows.isNotEmpty &&
        _gridLayout.headerRow >= 0 &&
        _gridLayout.headerRow < _gridRows.length) {
      return _gridRows[_gridLayout.headerRow];
    }
    return _parsed.headers;
  }

  List<String> _mappedHeaders() {
    final headers = <String>[];
    for (final field in _target.fields) {
      final header = _mapping[field.key];
      if (header != null && header.isNotEmpty && !headers.contains(header)) {
        headers.add(header);
      }
    }
    return headers;
  }

  Future<void> _runAiClassification() async {
    if (_gridDrafts.isEmpty) return;
    setState(() {
      _aiBusy = true;
      _classifyStatus = 'Asking local Ollama (${_aiModel})…';
    });
    final classifier = OllamaTypeClassifier(model: _aiModel);
    final seen = <String>{};
    final uniqueTitles = <String>[
      for (final d in _gridDrafts)
        if (d.title.trim().isNotEmpty && seen.add(d.title.trim()))
          d.title.trim(),
    ];
    final types = await classifier.classifyTitles(uniqueTitles);
    if (!mounted) return;
    setState(() {
      _aiBusy = false;
      if (types.isEmpty) {
        _classifyStatus = 'Ollama unreachable — kept keyword-based types.';
      } else {
        _gridDrafts = [
          for (final d in _gridDrafts)
            d.copyWith(type: types[d.title] ?? d.type),
        ];
        _table = _draftsTable(_gridDrafts);
        _mapping = CsvImportService.autoMap(_target, _table.headers);
        _classifyStatus = 'Refined ${types.length} types with local AI.';
      }
    });
  }

  Future<void> _import() async {
    if (_table.isEmpty) {
      _showSnack('Choose a CSV file first.');
      return;
    }
    final missing = CsvImportService.missingRequired(_target, _mapping);
    if (missing.isNotEmpty) {
      _showSnack('Missing required columns: ${missing.join(', ')}');
      return;
    }
    final records = CsvImportService.apply(_table, _mapping);
    if (records.isEmpty) {
      _showSnack('No data rows found in the file.');
      return;
    }
    final result =
        await CsvImportService.save(_target, _fileName ?? 'untitled.csv', records);
    var message = result.added == result.total
        ? 'Imported ${result.added} ${_target.label} records'
        : 'Imported ${result.added} new ${_target.label} records (${result.total} total)';
    if (result.scoutsAdded > 0) {
      message += ' • Created ${result.scoutsAdded} '
          '${result.scoutsAdded == 1 ? 'scout' : 'scouts'} from the roster';
    }
    if (_isGrid) {
      message += ' • Types: ${_gridDrafts.isNotEmpty ? _gridDrafts.first.type : 'n/a'}';
    }
    _showSnack(message);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isKnownHeader(String? value) =>
      value == null || value.isEmpty || _table.headers.contains(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.scoutingDarkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _target.id,
                    decoration: const InputDecoration(labelText: 'Report type'),
                    items: CsvImportService.targets
                        .map((target) => DropdownMenuItem(
                              value: target.id,
                              child: Text(
                                  '${target.label} - ${target.description}'),
                            ))
                        .toList(),
                    onChanged: (id) {
                      if (id != null) {
                        _setTarget(CsvImportService.targetById(id));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select CSV file',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.scoutingDarkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Choose CSV file'),
                  ),
                  if (_fileName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'File: $_fileName',
                      style:
                          const TextStyle(color: AppTheme.scoutingWarmGray),
                    ),
                    if (!_isGrid) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Imports are merged by year — the calendar and PDF '
                        'filter by year.',
                        style: TextStyle(color: AppTheme.scoutingWarmGray),
                      ),
                    ],
                  ],
                  if (_isGrid && _gridRows.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Planning-calendar grid detected: '
                      '${_gridDrafts.length} events found.',
                      style:
                          const TextStyle(color: AppTheme.scoutingWarmGray),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_table.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Choose a file above to start. '
                  'Columns can be remapped after the file loads.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.scoutingWarmGray),
                ),
              ),
            ),
          if (_isGrid && _gridRows.isNotEmpty && _table.rows.isNotEmpty) ...[
            _buildGridLayoutCard(),
            _buildAiCard(),
          ],
          if (!_isGrid && _table.rows.isNotEmpty) ...[
            _buildMappingCard(),
            _buildPreviewCard(),
          ],
          if (_isGrid && _table.rows.isNotEmpty) ...[
            _buildGridPreviewCard(),
          ],
          if (_table.rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.download_done),
                  label: Text('Import ${_target.label}'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _roleRow(String label, int index, void Function(int) onChanged) {
    final headers = _gridHeaders();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.scoutingDarkBlue,
            ),
          ),
        ),
        DropdownButtonFormField<int>(
          initialValue: index,
          decoration: const InputDecoration(isDense: true),
          items: [
            const DropdownMenuItem<int>(
              value: -1,
              child: Text('— Auto —'),
            ),
            for (var i = 0; i < headers.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text(headers[i].isNotEmpty ? headers[i] : 'Column $i'),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    );
  }

  void _setLayout(ProgramGridLayout layout) {
    setState(() {
      _gridLayout = layout;
      _applyGrid();
      _mapping = CsvImportService.autoMap(_target, _table.headers);
    });
  }

  void _setColumn(String role, int value) {
    switch (role) {
      case 'month':
        _setLayout(_gridLayout.copyWith(monthCol: value));
      case 'feature':
        _setLayout(_gridLayout.copyWith(featureCol: value));
      case 'camping':
        _setLayout(_gridLayout.copyWith(campingCol: value));
      case 'event':
        _setLayout(_gridLayout.copyWith(eventCol: value));
      case 'holiday':
        _setLayout(_gridLayout.copyWith(holidayCol: value));
      case 'service':
        _setLayout(_gridLayout.copyWith(serviceProjectCol: value));
      case 'special':
        _setLayout(_gridLayout.copyWith(specialEventCol: value));
      case 'tasks':
        _setLayout(_gridLayout.copyWith(tasksCol: value));
      case 'council':
        _setLayout(_gridLayout.copyWith(councilCol: value));
      case 'plc':
        _setLayout(_gridLayout.copyWith(plcCol: value));
      case 'committee':
        _setLayout(_gridLayout.copyWith(committeeCol: value));
      case 'roundtable':
        _setLayout(_gridLayout.copyWith(roundtableCol: value));
      case 'other':
        _setLayout(_gridLayout.copyWith(otherCol: value));
      case 'hunting':
        _setLayout(_gridLayout.copyWith(huntingCol: value));
      case 'oa':
        _setLayout(_gridLayout.copyWith(oaCol: value));
    }
  }

  void _setOffset(String role, int value) {
    if (role == 'dates') {
      _setLayout(_gridLayout.copyWith(dateRowOffset: value));
    } else {
      _setLayout(_gridLayout.copyWith(detailRowOffset: value));
    }
  }

  Widget _buildGridLayoutCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Program Grid layout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.scoutingDarkBlue,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    _setLayout(ProgramGridParser.detect(_gridRows));
                  },
                  icon: const Icon(Icons.autorenew, size: 18),
                  label: const Text('Auto-detect'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose what each column means in the sheet, then pick which '
              'row below each month name holds the week dates and which row '
              'holds the activity names.',
              style: TextStyle(fontSize: 12, color: AppTheme.scoutingWarmGray),
            ),
            const SizedBox(height: 12),
            _roleRow('Month column', _gridLayout.monthCol,
                (value) => _setColumn('month', value)),
            _roleRow('Program Feature column', _gridLayout.featureCol,
                (value) => _setColumn('feature', value)),
            for (var w = 0; w < _gridLayout.weekCols.length; w++)
              _roleRow(
                  'Week ${w + 1} date column', _gridLayout.weekCols[w], (value) {
                final cols = List<int>.from(_gridLayout.weekCols);
                cols[w] = value;
                _setLayout(_gridLayout.copyWith(weekCols: cols));
              }),
            _roleRow('Camping column', _gridLayout.campingCol,
                (value) => _setColumn('camping', value)),
            _roleRow('Event column', _gridLayout.eventCol,
                (value) => _setColumn('event', value)),
            _roleRow('Holiday column', _gridLayout.holidayCol,
                (value) => _setColumn('holiday', value)),
            _roleRow('Service Project column', _gridLayout.serviceProjectCol,
                (value) => _setColumn('service', value)),
            _roleRow('Special Event column', _gridLayout.specialEventCol,
                (value) => _setColumn('special', value)),
            _roleRow('Tasks column', _gridLayout.tasksCol,
                (value) => _setColumn('tasks', value)),
            _roleRow('Council Activity column', _gridLayout.councilCol,
                (value) => _setColumn('council', value)),
            _roleRow('PLC column', _gridLayout.plcCol,
                (value) => _setColumn('plc', value)),
            _roleRow('Committee column', _gridLayout.committeeCol,
                (value) => _setColumn('committee', value)),
            _roleRow('Roundtable column', _gridLayout.roundtableCol,
                (value) => _setColumn('roundtable', value)),
            _roleRow('Other column', _gridLayout.otherCol,
                (value) => _setColumn('other', value)),
            _roleRow('Hunting column', _gridLayout.huntingCol,
                (value) => _setColumn('hunting', value)),
            _roleRow('OA column', _gridLayout.oaCol,
                (value) => _setColumn('oa', value)),
            const SizedBox(height: 8),
            _offsetRow(
              'Week dates row (below the month row)',
              _gridLayout.dateRowOffset,
              (value) => _setOffset('dates', value),
              options: const [0, 1, 2],
              labels: const ['Same row', '1 row below', '2 rows below'],
            ),
            _offsetRow(
              'Activity names row (below the month row)',
              _gridLayout.detailRowOffset,
              (value) => _setOffset('activity', value),
              options: const [1, 2],
              labels: const ['1 row below', '2 rows below'],
            ),
          ],
        ),
      ),
    );
  }

  Widget _offsetRow(
    String label,
    int value,
    void Function(int) onChanged, {
    required List<int> options,
    required List<String> labels,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          for (var i = 0; i < options.length; i++)
            DropdownMenuItem<int>(
              value: options[i],
              child: Text(labels[i]),
            ),
        ],
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }

  Widget _buildAiCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Event type detection',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.scoutingDarkBlue,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Types are detected from the sheet columns with smart keywords '
              '(Court of Honor, Campout, Service, Fundraiser, Swim, …). '
              'You can also refine them with your local Ollama model — scout '
              'data never leaves this machine.',
              style: TextStyle(fontSize: 12, color: AppTheme.scoutingWarmGray),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Refine types with local Ollama'),
              value: _useAi,
              onChanged: (value) => setState(() => _useAi = value),
            ),
            if (_useAi) ...[
              DropdownButtonFormField<String>(
                initialValue: _aiModel,
                decoration:
                    const InputDecoration(labelText: 'Model', isDense: true),
                items: [
                  for (final model in _models)
                    DropdownMenuItem<String>(
                      value: model,
                      child: Text(model),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _aiModel = value);
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _aiBusy ? null : _runAiClassification,
                  icon: _aiBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_aiBusy ? 'Classifying…' : 'Classify types now'),
                ),
              ),
              if (_classifyStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _classifyStatus,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.scoutingWarmGray),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMappingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Column mapping',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.scoutingDarkBlue,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Map each field to the matching column in the file.',
              style: TextStyle(fontSize: 12, color: AppTheme.scoutingWarmGray),
            ),
            const SizedBox(height: 12),
            for (final field in _target.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(
                        field.required ? '${field.label} *' : field.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.scoutingDarkBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _mapping[field.key] ?? '',
                            icon: const Icon(Icons.arrow_drop_down),
                            isExpanded: true,
                            isDense: true,
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text(
                                  '— Ignore —',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ..._table.headers.map((header) {
                                return DropdownMenuItem<String>(
                                  value: header,
                                  child: Text(
                                    header,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              if (value == '' || _isKnownHeader(value)) {
                                setState(() {
                                  _mapping[field.key] = value ?? '';
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridPreviewCard() {
    final headers = _mappedHeaders();
    if (headers.isEmpty) return const SizedBox.shrink();
    final previewRows = _table.rows.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.scoutingDarkBlue,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: headers
                    .map((header) => DataColumn(label: Text(header)))
                    .toList(),
                rows: previewRows.map((row) {
                  return DataRow(
                    cells: headers.map((header) {
                      final index = _table.headers.indexOf(header);
                      final value = index >= 0 && index < row.length
                          ? row[index]
                          : '';
                      final shown = value.length > 30
                          ? '${value.substring(0, 30)}…'
                          : value;
                      return DataCell(Text(shown));
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Showing first ${previewRows.length} of ${_table.rows.length} rows',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.scoutingWarmGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final headers = _mappedHeaders();
    final previewRows = _table.rows.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.scoutingDarkBlue,
              ),
            ),
            const SizedBox(height: 8),
            if (headers.isEmpty)
              const Text(
                'No columns mapped yet',
                style: TextStyle(color: AppTheme.scoutingWarmGray),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns:
                      headers.map((header) => DataColumn(label: Text(header))).toList(),
                  rows: previewRows.map((row) {
                    return DataRow(
                      cells: headers.map((header) {
                        final index = _table.headers.indexOf(header);
                        final value = index >= 0 && index < row.length
                            ? row[index]
                            : '';
                        final shown = value.length > 30
                            ? '${value.substring(0, 30)}…'
                            : value;
                        return DataCell(Text(shown));
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Showing first ${previewRows.length} of ${_table.rows.length} rows',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.scoutingWarmGray),
            ),
          ],
        ),
      ),
    );
  }
}