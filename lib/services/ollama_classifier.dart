import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'program_grid_parser.dart';

class ProgramTypeClassifier {
  static const List<String> allowedTypes = [
    'Meeting',
    'Campout',
    'Court of Honor',
    'Elections',
    'Holiday',
    'Service Project',
    'Special Event',
    'Event',
    'Fundraiser',
    'Swim',
    'No Meeting',
    'Advancement',
    'Other',
  ];

  static String keywordType(String title, String fallback) {
    final t = title.toLowerCase();
    if (t.contains('court of honor') || t.contains('coh')) {
      return 'Court of Honor';
    }
    if (t.contains('election') || t.contains('vote') || t.contains('ballot')) {
      return 'Elections';
    }
    if (t.contains('no meeting')) return 'No Meeting';
    if (t.contains('fundraiser') ||
        t.contains('popcorn') ||
        t.contains('book sale')) {
      return 'Fundraiser';
    }
    if (t.contains('swim') || t.contains('pool party')) return 'Swim';
    if (t.contains('camping') ||
        t.contains('campout') ||
        t.contains('klondike') ||
        t.contains('backpacking') ||
        t.contains('canoe') ||
        t.contains('kayak') ||
        t.contains('overnight') ||
        t.contains('hike')) {
      return 'Campout';
    }
    if (t.contains('service') ||
        t.contains('cleanup') ||
        t.contains('food drive') ||
        t.contains('book drive') ||
        t.contains('wreaths') ||
        t.contains('eagle project work') ||
        t.contains('scouting for food')) {
      return 'Service Project';
    }
    if (t.contains('thanksgiving') ||
        t.contains('christmas') ||
        t.contains('new year') ||
        t.contains('easter') ||
        t.contains('fourth of july') ||
        t.contains('july 4') ||
        t.contains('memorial day') ||
        t.contains('labor day') ||
        t.contains('veterans') ||
        t.contains('mlk')) {
      return 'Holiday';
    }
    return fallback;
  }

  static List<ProgramEventDraft> applyKeywords(List<ProgramEventDraft> drafts) {
    return [
      for (final draft in drafts)
        if (draft.type.trim().toLowerCase() == 'meeting')
          draft
        else
          draft.copyWith(type: keywordType(draft.title, draft.type)),
    ];
  }
}

class OllamaTypeClassifier {
  static const String defaultHost = 'http://localhost:11434';
  static const Duration defaultTimeout = Duration(seconds: 90);

  final String host;
  final String model;
  final Duration timeout;
  final http.Client _client;

  OllamaTypeClassifier({
    this.host = defaultHost,
    this.model = 'qwen3:8b',
    this.timeout = defaultTimeout,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<Map<String, String>> classifyTitles(
    List<String> titles, {
    String? hostOverride,
  }) async {
    final unique = <String>[];
    for (final title in titles) {
      final key = title.trim();
      if (key.isNotEmpty && !unique.contains(key)) unique.add(key);
    }
    if (unique.isEmpty) return const {};

    final prompt = _buildPrompt(unique);
    try {
      final response = await _client
          .post(
            Uri.parse('${hostOverride ?? host}/api/generate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'prompt': prompt,
              'stream': false,
              'format': 'json',
            }),
          )
          .timeout(timeout);

      if (response.statusCode != 200) return const {};
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const {};
      final text = decoded['response'];
      if (text is! String) return const {};
      final parsed = jsonDecode(text);
      if (parsed is! Map<String, dynamic>) return const {};

      final result = <String, String>{};
      for (final entry in parsed.entries) {
        final title = entry.key.toString().trim();
        final type = _cleanType(entry.value.toString());
        if (title.isNotEmpty && type != null) {
          result[title] = type;
        }
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  String _buildPrompt(List<String> titles) {
    final items = titles
        .map((t) => '"${_escape(t)}"')
        .toList()
        .join(', ');
    return [
      'You are classifying Boy Scout troop calendar events.',
      'Return JSON where each key is the exact event title and the value is '
          'one type from this list: ${ProgramTypeClassifier.allowedTypes.join(', ')}.',
      'Use lowercase-ish short type values matching the list exactly. '
          'If unsure, use "Other".',
      'Events: [$items]',
    ].join(' ');
  }

  String? _cleanType(String raw) {
    final value = raw.trim();
    for (final allowed in ProgramTypeClassifier.allowedTypes) {
      if (value.toLowerCase() == allowed.toLowerCase()) return allowed;
    }
    for (final allowed in ProgramTypeClassifier.allowedTypes) {
      if (value.toLowerCase().contains(allowed.toLowerCase())) return allowed;
    }
    return null;
  }

  static String _escape(String value) =>
      value.replaceAll('"', r'\"').replaceAll('\\', r'\\');
}