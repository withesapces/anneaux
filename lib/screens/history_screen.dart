import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calories.dart';
import '../estimate.dart';
import '../format.dart';
import '../health_sync.dart';
import '../models.dart';
import '../store.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('Historique',
                    style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: exportAll(store.sessions)));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tout l\'historique est copié.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Tout copier'),
              ),
            ],
          ),
        ),
        Expanded(
          child: store.sessions.isEmpty
              ? const Center(child: Text('Aucune séance.'))
              : ListView.separated(
                  itemCount: store.sessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final s = store.sessions[i];
                    return ListTile(
                      title: Text(fmtDateLong(s.date)),
                      subtitle: Text(
                          '${s.exercises.length} exercices · ${s.totalSets} séries'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(session: s),
                      )),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class SessionDetailScreen extends StatefulWidget {
  final Session session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  Session get s => widget.session;

  Future<void> _editExercise(ExerciseLog e) async {
    final store = StoreScope.read(context);
    final ctrl = TextEditingController(
      text: e.sets
          .map((x) => x.height == null ? '${x.value}' : '${x.value}@${fmtHeight(x.height!)}')
          .join(' '),
    );
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(e.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Une série par valeur, hauteur après @.\nEx : 10@5 10@5 7@5'),
            const SizedBox(height: 8),
            TextField(controller: ctrl, autofocus: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('OK')),
        ],
      ),
    );
    if (r == null) return;
    final sets = <SetLog>[];
    for (final token in r.trim().split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final parts = token.split('@');
      final v = int.tryParse(parts[0]);
      if (v == null) continue;
      final h = parts.length > 1 ? double.tryParse(parts[1].replaceAll(',', '.')) : null;
      sets.add(SetLog(v, h));
    }
    e.sets = sets;
    if (sets.isEmpty) s.exercises.remove(e);
    await store.updateSession(s);
    setState(() {});
  }

  Future<void> _editDate() async {
    final store = StoreScope.read(context);
    final d = await showDatePicker(
      context: context,
      initialDate: s.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null) return;
    s.date = DateTime(d.year, d.month, d.day, s.date.hour, s.date.minute);
    await store.updateSession(s);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(onTap: _editDate, child: Text(fmtDate(s.date))),
        actions: [
          IconButton(
            tooltip: 'Copier',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: exportSession(s)));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Séance copiée.')));
              }
            },
          ),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  content: const Text('Supprimer cette séance ?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Non')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Supprimer')),
                  ],
                ),
              );
              if (ok == true) {
                await store.deleteSession(s);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final e in s.exercises)
            Card(
              child: ListTile(
                title: Text(e.name, style: t.titleMedium),
                subtitle: Text(setsSummary(e)),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => _editExercise(e),
              ),
            ),
          const SizedBox(height: 12),
          if (s.end != null)
            Text('Durée : ${fmtDuration(s.end!.difference(s.date).inSeconds)} '
                '(${fmtHour(s.date)} → ${fmtHour(s.end!)}) · '
                '≈ ${estimateKcal(s, store.weightKg)} kcal'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final err = await HealthSync.writeSession(s,
                  weightKg: store.sendCalories ? store.weightKg : null);
              if (err == null) await store.markHealthSynced(s);
              messenger.showSnackBar(
                  SnackBar(content: Text(err ?? 'Envoyée à Samsung Health.')));
            },
            icon: Icon(s.healthSynced ? Icons.check : Icons.favorite_border),
            label: Text(s.healthSynced
                ? 'Déjà envoyée à Samsung Health (renvoyer)'
                : 'Envoyer à Samsung Health'),
          ),
          const SizedBox(height: 12),
          Text('Touche la date pour la changer, un exercice pour corriger ses séries.',
              style: t.bodySmall),
        ],
      ),
    );
  }
}
