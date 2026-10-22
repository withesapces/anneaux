import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../health_sync.dart';
import '../models.dart';
import '../store.dart';

/// Programme (ordre des exercices, hauteurs) + réglages du repos + sauvegarde.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<ExerciseDef?> _editDef(BuildContext context, ExerciseDef? initial) async {
    final name = TextEditingController(text: initial?.name ?? '');
    final height = TextEditingController(
        text: initial?.height == null ? '' : fmtHeight(initial!.height!));
    var unit = initial?.unit ?? Unit.reps;
    var perSide = initial?.perSide ?? false;
    return showDialog<ExerciseDef>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(initial == null ? 'Nouvel exercice' : 'Modifier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                TextField(
                  controller: height,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Hauteur par défaut'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<Unit>(
                  segments: const [
                    ButtonSegment(value: Unit.reps, label: Text('Reps')),
                    ButtonSegment(value: Unit.seconds, label: Text('Secondes')),
                  ],
                  selected: {unit},
                  onSelectionChanged: (s) => set(() => unit = s.first),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('De chaque côté'),
                  value: perSide,
                  onChanged: (v) => set(() => perSide = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final n = name.text.trim();
                if (n.isEmpty) return;
                Navigator.pop(
                  c,
                  ExerciseDef(
                    name: n,
                    unit: unit,
                    perSide: perSide,
                    height: double.tryParse(height.text.trim().replaceAll(',', '.')),
                  ),
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final routine = store.routine;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Programme',
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text('Maintiens ⠿ pour réordonner, touche pour modifier.',
              style: t.bodySmall),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (a, b) {
            final list = [...routine];
            if (b > a) b--;
            list.insert(b, list.removeAt(a));
            store.setRoutine(list);
          },
          children: [
            for (var i = 0; i < routine.length; i++)
              ListTile(
                key: ValueKey('r$i${routine[i].name}'),
                leading: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_indicator),
                ),
                title: Text(routine[i].name),
                subtitle: Text([
                  routine[i].unit == Unit.seconds ? 'secondes' : 'reps',
                  if (routine[i].perSide) 'chaque côté',
                  if (routine[i].height != null) 'hauteur ${fmtHeight(routine[i].height!)}',
                ].join(' · ')),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    final list = [...routine]..removeAt(i);
                    store.setRoutine(list);
                  },
                ),
                onTap: () async {
                  final d = await _editDef(context, routine[i]);
                  if (d == null) return;
                  final list = [...routine];
                  list[i] = d;
                  store.setRoutine(list);
                },
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () async {
              final d = await _editDef(context, null);
              if (d == null) return;
              store.setRoutine([...routine, d]);
            },
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un exercice'),
          ),
        ),
        const Divider(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Repos entre les séries : ${fmtClock(store.restSeconds)}',
              style: t.titleMedium),
        ),
        Slider(
          value: store.restSeconds.toDouble(),
          min: 15,
          max: 300,
          divisions: 19,
          label: fmtClock(store.restSeconds),
          onChanged: (v) => store.setRest(v.round()),
        ),
        SwitchListTile(
          title: const Text('Bip sonore en fin de repos'),
          subtitle: const Text('La vibration reste active dans tous les cas'),
          value: store.sound,
          onChanged: store.setSound,
        ),
        SwitchListTile(
          title: const Text('Envoyer les séances à Samsung Health'),
          subtitle: const Text(
              'Via Health Connect, à la fin de chaque séance. Dans Samsung Health : '
              'Paramètres > Health Connect, autorise la synchro des exercices.'),
          value: store.healthEnabled,
          onChanged: (v) async {
            final messenger = ScaffoldMessenger.of(context);
            if (!v) {
              store.setHealth(false);
              return;
            }
            final ok = await HealthSync.authorize();
            await store.setHealth(ok);
            messenger.showSnackBar(SnackBar(
              content: Text(ok
                  ? 'Connecté à Health Connect.'
                  : 'Autorisation refusée ou Health Connect indisponible.'),
            ));
          },
        ),
        const Divider(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Sauvegarde', style: t.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
              'Les données restent sur ce téléphone. Copie la sauvegarde de temps en temps '
              '(dans une note ou un mail) pour ne rien perdre si tu changes de téléphone.',
              style: t.bodySmall),
        ),
        ListTile(
          leading: const Icon(Icons.upload),
          title: const Text('Copier la sauvegarde'),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: store.exportJson()));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Sauvegarde copiée.')));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Restaurer depuis le presse-papiers'),
          subtitle: const Text('Remplace toutes les données actuelles'),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final raw = data?.text;
            if (raw == null || raw.trim().isEmpty) {
              messenger.showSnackBar(
                  const SnackBar(content: Text('Presse-papiers vide.')));
              return;
            }
            try {
              await store.importJson(raw);
              messenger.showSnackBar(
                  const SnackBar(content: Text('Sauvegarde restaurée.')));
            } catch (_) {
              messenger.showSnackBar(
                  const SnackBar(content: Text('Ce texte n\'est pas une sauvegarde valide.')));
            }
          },
        ),
      ],
    );
  }
}
