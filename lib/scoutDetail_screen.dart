import 'package:flutter/material.dart';

class ScoutDetailScreen extends StatelessWidget {
  final Map<String, String> scout;

  const ScoutDetailScreen({Key? key, required this.scout}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final patrol = scout['patrol'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(scout['name'] ?? 'Scout Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person),
              title: Text(scout['name'] ?? ''),
              subtitle: Text(patrol.isEmpty
                  ? (scout['rank'] ?? '')
                  : '${scout['rank']} • $patrol'),
            ),
            Divider(),
            Text(
              'Advancement',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 4),
            Text('No advancement recorded yet.'),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Editing not implemented yet.')),
                );
              },
              icon: Icon(Icons.edit),
              label: Text('Edit Scout'),
            ),
          ],
        ),
      ),
    );
  }
}