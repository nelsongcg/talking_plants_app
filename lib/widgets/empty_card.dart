import 'package:flutter/material.dart';

/// Simple placeholder used by panes that have no content yet.
class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, this.message = 'No data yet'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
