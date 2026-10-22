import 'package:flutter/material.dart';

import '../format.dart';
import '../store.dart';
import 'history_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import 'workout_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      _TodayTab(),
      HistoryScreen(),
      ProgressScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Séance'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historique'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Progression'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Programme'),
        ],
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab();

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WorkoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final last = store.sessions.isEmpty ? null : store.sessions.first;
    final draft = store.draft;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Anneaux', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          '${store.routine.length} exercices · repos ${fmtClock(store.restSeconds)} entre chaque série',
          style: t.bodyMedium,
        ),
        const SizedBox(height: 24),
        if (draft != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Séance en cours', style: t.titleLarge),
                  const SizedBox(height: 4),
                  Text('Commencée le ${fmtDateLong(draft.session.date)} · '
                      '${draft.session.totalSets} séries faites'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _open(context),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Reprendre'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          final ok = await _confirm(context,
                              'Abandonner la séance en cours ? Les séries saisies seront perdues.');
                          if (ok) store.discardDraft();
                        },
                        child: const Text('Abandonner'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ] else
          SizedBox(
            height: 72,
            child: FilledButton.icon(
              onPressed: () {
                store.startWorkout();
                _open(context);
              },
              icon: const Icon(Icons.play_arrow, size: 32),
              label: const Text('Démarrer la séance', style: TextStyle(fontSize: 20)),
            ),
          ),
        const SizedBox(height: 28),
        if (last != null) ...[
          Text('Dernière séance · ${fmtDateLong(last.date)}', style: t.titleMedium),
          const SizedBox(height: 8),
          for (final e in last.exercises)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(e.name, style: t.bodyLarge)),
                  Text(setsSummary(e), style: t.bodyMedium),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

Future<bool> _confirm(BuildContext context, String msg) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui')),
      ],
    ),
  );
  return r ?? false;
}
