import 'package:flutter/material.dart';

import '../services/troop_question_service.dart';
import '../theme/app_theme.dart';

/// Ask a question about the troop in plain words and get an answer from the
/// local Ollama model.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key, this.service});

  /// Replaces the local Ollama service, for tests.
  final TroopQuestionService? service;

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  static const List<String> _examples = [
    'Who still needs the Swimming merit badge?',
    'Who is closest to their next rank?',
    'Which Eagle-required badges are most needed?',
    'What campouts are coming up?',
  ];

  final TextEditingController _question = TextEditingController();
  late final TroopQuestionService _service =
      widget.service ?? TroopQuestionService();
  final List<({String question, String answer})> _history = [];
  bool _asking = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask([String? text]) async {
    final question = (text ?? _question.text).trim();
    if (question.isEmpty || _asking) return;
    setState(() => _asking = true);
    final answer = await _service.ask(question);
    if (!mounted) return;
    setState(() {
      _asking = false;
      _history.insert(0, (
        question: question,
        answer:
            answer ??
            'Couldn\'t reach Ollama. Make sure it is running on this computer '
                'and try again.',
      ));
      _question.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask Your Troop')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _question,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _ask(),
                    decoration: InputDecoration(
                      labelText: 'Ask about your troop',
                      suffixIcon: _asking
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.send),
                              tooltip: 'Ask',
                              onPressed: _ask,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final example in _examples)
                        ActionChip(
                          label: Text(example),
                          visualDensity: VisualDensity.compact,
                          onPressed: _asking ? null : () => _ask(example),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Answered by your local Ollama model from the troop\'s data. '
                    'Nothing leaves this computer. The model can make mistakes, '
                    'so check anything important on the Scout Page.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.scoutingWarmGray,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_asking)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Thinking... the first question can take a minute while the '
                'model loads.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.scoutingWarmGray),
              ),
            ),
          for (final entry in _history)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.scoutingDarkBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(entry.answer),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
