import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/csv_import_service.dart';
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
  List<List<String>> _rawRows = const [];
  CsvTable _table = CsvTable.empty;
  Map<String, String> _mapping = {};

  void _setTarget(ImportTarget target) {
    setState(() {
      _target = target;
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
    final parsed = CsvImportService.parse(content);
    setState(() {
      _fileName = name;
      _rawRows = parsed.rows;
      _applyTargetRows();
    });
  }

  void _applyTargetRows() {
    final rows = _target.id == 'program_grid'
        ? ProgramGridParser.toRows(_rawRows)
        : _rawRows;
    _table = rows.isEmpty
        ? CsvTable.empty
        : CsvTable(headers: rows.first, rows: rows.skip(1).toList());
    _mapping = CsvImportService.autoMap(_target, _table.headers);
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
    final count =
        await CsvImportService.save(_target, _fileName ?? 'untitled.csv', records);
    _showSnack('Imported $count ${_target.label} records from ${_fileName ?? ''}');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

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
                              child: Text('${target.label} - ${target.description}'),
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
                      style: const TextStyle(color: AppTheme.scoutingWarmGray),
                    ),
                  ],
                  if (_table.headers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_table.headers.length} columns, ${_table.rows.length} data rows',
                      style: const TextStyle(color: AppTheme.scoutingWarmGray),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _table.headers
                          .map((header) => Chip(
                                label: Text(
                                  header,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
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
          if (_table.rows.isNotEmpty) ...[
            _buildMappingCard(),
            _buildPreviewCard(),
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
        ],
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
                child: DropdownButtonFormField<String>(
                  initialValue: _mapping[field.key] ?? '',
                  decoration: InputDecoration(
                    labelText: field.required
                        ? '${field.label} (required)'
                        : field.label,
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('— Ignore —'),
                    ),
                    ..._table.headers.map((header) => DropdownMenuItem<String>(
                          value: header,
                          child: Text(
                            header,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _mapping[field.key] = value ?? '';
                    });
                  },
                ),
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
                  columns: headers
                      .map((header) => DataColumn(label: Text(header)))
                      .toList(),
                  rows: previewRows
                      .map((row) => DataRow(
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
                          ))
                      .toList(),
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