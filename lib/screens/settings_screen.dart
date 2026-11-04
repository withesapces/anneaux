import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backup.dart';
import '../device_files.dart';
import '../estimate.dart';
import '../format.dart';
import '../health_sync.dart';
import '../models.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/ui.dart';
import 'exercise_editor_screen.dart';
import 'privacy_screen.dart';

/// Onglet « Programme » : exercices (ordre, hauteurs) + réglages.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const D('Programme', size: 52, w: FontWeight.w900, height: 1),
            const SizedBox(height: 16),
            Segmented(
              labels: const ['Exercices', 'Réglages'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Expanded(child: _tab == 0 ? const _ExercisesTab() : const _SettingsTab()),
      ],
    );
  }
}

/// Sélecteur à deux segments (fond gris, segment actif blanc).
class Segmented extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const Segmented({super.key, required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        height: 64,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: i == index ? C.text : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: D(labels[i], size: 21, color: i == index ? C.bg : C.muted),
                ),
              ),
            ),
        ]),
      );
}

class _ExercisesTab extends StatelessWidget {
  const _ExercisesTab();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final routine = store.routine;
    final exs = routine
        .map((r) => ExerciseLog(name: r.name, unit: r.unit, perSide: r.perSide))
        .toList();
    final mins = (estimateRemaining(store, exs) / 60).round();

    Future<void> edit(int? i) async {
      final r = await Navigator.of(context).push<EditorResult>(MaterialPageRoute(
        builder: (_) => ExerciseEditorScreen(initial: i == null ? null : routine[i]),
      ));
      if (r == null) return;
      final list = [...routine];
      if (r.delete) {
        if (i != null) list.removeAt(i);
      } else if (i == null) {
        list.add(r.def!);
      } else {
        list[i] = r.def!;
      }
      store.setRoutine(list);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Row(children: [
          Expanded(child: Lbl('${routine.length} exercices · ~$mins min', size: 14)),
          const Lbl('Maintiens et glisse', size: 14),
        ]),
        const SizedBox(height: 10),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          proxyDecorator: (child, i, anim) => Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.accent, width: 2),
              ),
              child: child,
            ),
          ),
          onReorderItem: (a, b) {
            final list = [...routine];
            list.insert(b, list.removeAt(a));
            store.setRoutine(list);
          },
          children: [
            for (var i = 0; i < routine.length; i++)
              Padding(
                key: ValueKey('r$i${routine[i].name}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: ReorderableDelayedDragStartListener(
                  index: i,
                  child: Material(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => edit(i),
                      child: SizedBox(
                        height: 54,
                        child: Row(children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const SizedBox(
                              width: 48,
                              height: 54,
                              child: Icon(Icons.drag_indicator_rounded, color: C.faint),
                            ),
                          ),
                          Expanded(
                            child: D(routine[i].name, size: 22, w: FontWeight.w800, maxLines: 1),
                          ),
                          Container(
                            height: 26,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                                color: C.surface2, borderRadius: BorderRadius.circular(6)),
                            alignment: Alignment.center,
                            child: D(routine[i].unit == Unit.seconds ? 'Sec.' : 'Reps',
                                size: 14, w: FontWeight.w700, ls: 0.06, color: C.muted),
                          ),
                          SizedBox(
                            width: 64,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: D(fmtH(routine[i].height), size: 20),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, color: C.dim),
                          const SizedBox(width: 8),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => edit(null),
          child: const DashedBox(
            child: SizedBox(
              height: 62,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_rounded, color: C.accent, size: 28),
                SizedBox(width: 6),
                D('Ajouter un exercice', size: 21),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  Future<void> _editWeight(BuildContext context, AppStore store) async {
    final ctrl = TextEditingController(text: fmtHeight(store.weightKg));
    final v = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: const D('Poids (kg)', size: 28, w: FontWeight.w900),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: disp(40),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('ANNULER')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(c, double.tryParse(ctrl.text.trim().replaceAll(',', '.'))),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (v != null && v > 20 && v < 300) store.setWeight(v);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Panel(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Lbl('Repos par défaut', size: 14),
                D(fmtClock(store.restSeconds), size: 52, height: 1),
                Text('de 0:15 à 5:00, par pas de 15 s', style: body(12, color: C.muted)),
              ]),
            ),
            RoundButton(
                plus: false,
                size: 64,
                onTap: store.restSeconds > 15
                    ? () => store.setRest(store.restSeconds - 15)
                    : null),
            const SizedBox(width: 10),
            RoundButton(
                plus: true,
                size: 64,
                onTap: store.restSeconds < 300
                    ? () => store.setRest(store.restSeconds + 15)
                    : null),
          ]),
        ),
        const SizedBox(height: 14),
        Panel(
          padding: const EdgeInsets.fromLTRB(18, 8, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _SwitchRow(
              title: 'Bip de fin de repos',
              subtitle: '3 bips sur les 3 dernières secondes (la vibration reste active)',
              value: store.sound,
              onChanged: store.setSound,
            ),
            const Divider(color: C.line, height: 16),
            _SwitchRow(
              title: 'Samsung Health',
              subtitle: 'Envoie durée et calories en fin de séance, via Health Connect',
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
            if (store.healthEnabled) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Poids (calcul des kcal)', style: body(13, color: C.muted)),
                    const SizedBox(height: 6),
                    _FieldBox(
                      onTap: () => _editWeight(context, store),
                      child: Text('${fmtHeight(store.weightKg)} kg', style: body(16)),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Calories', style: body(13, color: C.muted)),
                    const SizedBox(height: 6),
                    _FieldBox(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<bool>(
                          value: store.sendCalories,
                          isExpanded: true,
                          dropdownColor: C.surface2,
                          style: body(16),
                          items: const [
                            DropdownMenuItem(value: true, child: Text('Estimées')),
                            DropdownMenuItem(value: false, child: Text('Non envoyées')),
                          ],
                          onChanged: (v) => store.setSendCalories(v ?? true),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              Text('MET 3,5 × poids × durée. Choisis « Non envoyées » si une montre mesure déjà la séance.',
                  style: body(12, color: C.faint)),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        const Lbl('Sauvegarde', size: 14),
        const SizedBox(height: 8),
        Text(_autoBackupStatus(store),
            style: body(13, color: store.autoBackupError == null ? C.muted : const Color(0xFFFF5A4E), height: 1.4)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TileButton('Sauver', icon: Icons.save_alt_rounded, height: 64, fontSize: 24,
                onTap: () async {
              final err = await store.autoBackupNow(force: true);
              if (context.mounted) {
                toast(context, err == null
                    ? 'Sauvegarde écrite dans ${DeviceFiles.folderLabel}.'
                    : 'Échec de la sauvegarde : $err');
              }
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TileButton('Fichier', icon: Icons.folder_open_rounded, height: 64, fontSize: 24,
                onTap: () async {
              final String? raw;
              try {
                raw = await DeviceFiles.open();
              } catch (e) {
                if (context.mounted) toast(context, 'Impossible d\'ouvrir le fichier : $e');
                return;
              }
              if (raw == null || !context.mounted) return;
              await _importBackupText(context, store, raw);
            }),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TileButton('Copier', icon: Icons.copy_rounded, height: 56, fontSize: 20,
                onTap: () async {
              await Clipboard.setData(ClipboardData(text: store.exportJson()));
              if (context.mounted) {
                toast(context, 'Sauvegarde copiée. Colle-la dans une note ou un mail.');
              }
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TileButton('Coller', icon: Icons.content_paste_rounded, height: 56, fontSize: 20,
                onTap: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              final raw = data?.text;
              if (!context.mounted) return;
              if (raw == null || raw.trim().isEmpty) {
                toast(context, 'Presse-papiers vide.');
                return;
              }
              await _importBackupText(context, store, raw);
            }),
          ),
        ]),
        const SizedBox(height: 6),
        Text('« Fichier » et « Coller » ajoutent les séances manquantes sans rien effacer.',
            style: body(12, color: C.faint)),
        const SizedBox(height: 16),
        Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: C.line, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(children: [
                const MageArt(width: 52, bust: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const D('Tes données', size: 22),
                    Text('Maître Magnésie t\'explique tout', style: body(13, color: C.muted)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: C.dim),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow(
      {required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: body(16, w: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: body(13, color: C.muted)),
              ]),
            ),
            const SizedBox(width: 10),
            Switch(value: value, onChanged: onChanged),
          ]),
        ),
      );
}

class _FieldBox extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _FieldBox({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: C.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.line, width: 2),
          ),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      );
}

String _two(int n) => n.toString().padLeft(2, '0');

String _autoBackupStatus(AppStore store) {
  final at = store.autoBackupAt;
  if (store.autoBackupError != null) {
    return 'Sauvegarde automatique en échec : ${store.autoBackupError}';
  }
  if (at == null) {
    return 'Après chaque séance, une copie est écrite dans ${DeviceFiles.folderLabel} '
        '(un fichier par jour). Elle reste même si l\'app est désinstallée.';
  }
  return 'Dernière sauvegarde automatique : ${fmtShort(at)} à ${at.hour}h${_two(at.minute)}, '
      'dans ${DeviceFiles.folderLabel}. Elle reste même si l\'app est désinstallée.';
}

/// Lit une sauvegarde, montre ce qu'elle apporte, puis ajoute les séances manquantes.
Future<void> _importBackupText(BuildContext context, AppStore store, String raw) async {
  final Backup backup;
  try {
    backup = parseBackup(raw);
  } on BackupException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), duration: const Duration(seconds: 8)));
    return;
  }
  final missing = store.missingFrom(backup);
  final known = backup.sessions.length - missing.length;
  final dates = missing.map((s) => s.date).toList()..sort();
  final parts = <String>[
    missing.isEmpty
        ? 'Aucune nouvelle séance : tout ce qu\'elle contient est déjà dans ton historique.'
        : '${missing.length} séance${missing.length > 1 ? 's' : ''} à ajouter'
            '${missing.length == 1 ? ' : ${fmtDate(dates.first)}' : ', du ${fmtDate(dates.first)} au ${fmtDate(dates.last)}'}.',
    if (known > 0) '$known déjà présente${known > 1 ? 's' : ''}, ignorée${known > 1 ? 's' : ''}.',
    if (backup.routine != null) 'Le programme sera remplacé par celui de la sauvegarde.',
    'Rien ne sera effacé.',
  ];
  if (missing.isEmpty && backup.routine == null) {
    toast(context, parts.first);
    return;
  }
  final ok = await confirmDialog(context, 'Importer ?', parts.join('\n'), yes: 'Importer');
  if (!ok) return;
  final added = await store.applyBackup(backup);
  if (context.mounted) {
    toast(context, added == 0 ? 'Programme restauré.' : '$added séance${added > 1 ? 's' : ''} ajoutée${added > 1 ? 's' : ''}.');
  }
}
