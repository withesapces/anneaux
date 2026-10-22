import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/line_chart.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final names = store.allExerciseNames();
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Progression',
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        for (final n in names)
          Builder(builder: (context) {
            final h = store.historyFor(n);
            if (h.isEmpty) return const SizedBox.shrink();
            final first = h.first.$2.total;
            final last = h.last.$2.total;
            final diff = last - first;
            return ListTile(
              title: Text(n),
              subtitle: Text('${h.length} séances · dernier total $last'
                  '${h.last.$2.unit == Unit.seconds ? ' s' : ' reps'}'),
              trailing: Text(
                diff == 0 ? '=' : (diff > 0 ? '+$diff' : '$diff'),
                style: t.titleMedium?.copyWith(
                  color: diff > 0
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ExerciseProgressScreen(name: n),
              )),
            );
          }),
      ],
    );
  }
}

class ExerciseProgressScreen extends StatelessWidget {
  final String name;
  const ExerciseProgressScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final h = store.historyFor(name);
    final isSec = h.isNotEmpty && h.first.$2.unit == Unit.seconds;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(isSec ? 'Total de secondes par séance' : 'Total de répétitions par séance',
              style: t.titleSmall),
          const SizedBox(height: 12),
          SimpleLineChart(
            values: h.map((e) => e.$2.total.toDouble()).toList(),
            labels: h.map((e) => fmtShort(e.$1)).toList(),
          ),
          const SizedBox(height: 16),
          for (final e in h.reversed)
            ListTile(
              dense: true,
              title: Text(fmtDate(e.$1)),
              subtitle: Text(setsSummary(e.$2)),
              trailing: Text('${e.$2.total}', style: t.titleMedium),
            ),
        ],
      ),
    );
  }
}
