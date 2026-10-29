import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../health_sync.dart';
import '../models.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/height_control.dart';
import '../widgets/ui.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime _month = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    // Ouvre sur le mois de la dernière séance.
    final store = StoreScope.read(context);
    if (store.sessions.isNotEmpty && sessionsInMonth(store.sessions, _month) == 0) {
      final d = store.sessions.first.date;
      _month = DateTime(d.year, d.month);
    }
  }

  void _shift(int k) => setState(() => _month = DateTime(_month.year, _month.month + k));

  void _open(Session s) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final inMonth = store.sessions
        .where((s) => s.date.year == _month.year && s.date.month == _month.month)
        .toList();
    final dur = inMonth.fold(0, (a, s) => a + (sessionDuration(s) ?? 0));
    final reps = inMonth.fold(0, (a, s) => a + sessionReps(s));
    final now = DateTime.now();
    final canNext = DateTime(_month.year, _month.month + 1).isBefore(DateTime(now.year, now.month + 1));
    final firstMonth = store.sessions.isEmpty
        ? _month
        : DateTime(store.sessions.last.date.year, store.sessions.last.date.month);
    final canPrev = _month.isAfter(firstMonth);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        Row(children: [
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: D('Historique', size: 52, w: FontWeight.w900, height: 1),
            ),
          ),
          _SquareBtn(Icons.copy_rounded, tooltip: 'Tout copier', onTap: () async {
            await Clipboard.setData(ClipboardData(text: exportAll(store.sessions)));
            if (context.mounted) toast(context, 'Tout l\'historique est copié.');
          }),
          const SizedBox(width: 8),
          _SquareBtn(Icons.chevron_left_rounded, onTap: canPrev ? () => _shift(-1) : null),
          const SizedBox(width: 8),
          _SquareBtn(Icons.chevron_right_rounded, onTap: canNext ? () => _shift(1) : null),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          D('${monthName(_month.month)}${_month.year != now.year ? ' ${_month.year}' : ''}',
              size: 26, w: FontWeight.w800),
          const Spacer(),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '${inMonth.length} SÉANCE${inMonth.length > 1 ? 'S' : ''}',
                  style: const TextStyle(color: C.accent)),
              if (dur > 0) TextSpan(text: ' · ${_hm(dur)}'),
              TextSpan(text: ' · ${fmtThousands(reps)} REPS'),
            ]),
            style: disp(16, w: FontWeight.w700, color: C.muted),
          ),
        ]),
        const SizedBox(height: 12),
        _Calendar(month: _month, sessions: inMonth, onOpen: _open),
        const SizedBox(height: 18),
        const Row(children: [
          Expanded(child: Lbl('Séances', size: 14)),
          Lbl('Tendance volume', size: 14),
        ]),
        const SizedBox(height: 4),
        if (inMonth.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Aucune séance ce mois-ci.', style: body(15, color: C.muted)),
          ),
        for (final s in inMonth) _SessionRow(session: s, all: store.sessions, onTap: () => _open(s)),
      ],
    );
  }

  String _hm(int seconds) {
    final m = (seconds / 60).round();
    return '${m ~/ 60} H ${(m % 60).toString().padLeft(2, '0')}';
  }
}

class _SquareBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  const _SquareBtn(this.icon, {this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: C.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, color: onTap == null ? C.faint : C.text, size: 26),
            ),
          ),
        ),
      );
}

class _Calendar extends StatelessWidget {
  final DateTime month;
  final List<Session> sessions;
  final void Function(Session) onOpen;
  const _Calendar({required this.month, required this.sessions, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cells = <Widget>[
      for (final l in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
        Center(child: D(l, size: 14, w: FontWeight.w700, color: C.muted)),
    ];
    for (var i = 0; i < offset; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= days; d++) {
      final date = DateTime(month.year, month.month, d);
      final s = sessions.where((x) =>
          x.date.year == date.year && x.date.month == date.month && x.date.day == date.day);
      final has = s.isNotEmpty;
      final isToday = date == today;
      final future = date.isAfter(today);
      cells.add(GestureDetector(
        onTap: has ? () => onOpen(s.first) : null,
        child: Container(
          decoration: BoxDecoration(
            color: has ? C.accent : (future ? Colors.transparent : C.surface),
            borderRadius: BorderRadius.circular(12),
            border: isToday
                ? Border.all(color: C.text, width: 2)
                : (future ? Border.all(color: C.surface, width: 1.5) : null),
          ),
          alignment: Alignment.center,
          child: D('$d',
              size: 17,
              w: FontWeight.w700,
              color: has ? C.bg : (future ? C.faint : (isToday ? C.text : C.muted))),
        ),
      ));
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 7,
      crossAxisSpacing: 7,
      childAspectRatio: 1.05,
      children: cells,
    );
  }
}

class _SessionRow extends StatelessWidget {
  final Session session;
  final List<Session> all;
  final VoidCallback onTap;
  const _SessionRow({required this.session, required this.all, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = session;
    // all est trié du plus récent au plus ancien.
    final idx = all.indexWhere((x) => x.id == s.id);
    final upTo = idx < 0 ? [s] : all.sublist(idx, min(all.length, idx + 5)).reversed.toList();
    final vols = upTo.map((x) => sessionReps(x).toDouble()).toList();
    final prev = idx >= 0 && idx + 1 < all.length ? all[idx + 1] : null;
    final delta = prev == null ? null : sessionReps(s) - sessionReps(prev);
    final dur = sessionDuration(s);
    final hold = sessionHold(s);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.surface2))),
        child: Row(children: [
          SizedBox(
            width: 56,
            child: Column(children: [
              D(weekdayShort(s.date), size: 14, w: FontWeight.w700, color: C.muted),
              D('${s.date.day}', size: 36, height: 1),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: D('${dur == null ? '' : '${fmtMinSec(dur)} · '}${s.totalSets} séries',
                    size: 24),
              ),
              Text(
                  '${sessionReps(s)} reps${hold > 0 ? ' · ${fmtMinSec(hold)} tenue' : ''}',
                  style: body(13, color: C.muted)),
            ]),
          ),
          Sparkline(vols, dotColor: (delta ?? 1) >= 0 ? C.accent : C.muted),
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerRight,
              child: D(delta == null ? '' : fmtDelta(delta),
                  size: 22, color: (delta ?? 0) > 0 ? C.accent : C.muted),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Détail d'une séance
// ---------------------------------------------------------------------------

class SessionDetailScreen extends StatefulWidget {
  final Session session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  Session get s => widget.session;
  ExerciseLog? _selEx;
  int _selSet = -1;

  Future<void> _save() async {
    await StoreScope.read(context).updateSession(s);
    setState(() {});
  }

  Future<void> _editDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: s.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null) return;
    final shift = DateTime(d.year, d.month, d.day, s.date.hour, s.date.minute).difference(s.date);
    s.date = s.date.add(shift);
    if (s.end != null) s.end = s.end!.add(shift);
    await _save();
  }

  void _select(ExerciseLog e, int i) => setState(() {
        if (_selEx == e && _selSet == i) {
          _selEx = null;
          _selSet = -1;
        } else {
          _selEx = e;
          _selSet = i;
        }
      });

  Future<void> _addSet(ExerciseLog e) async {
    final last = e.sets.isEmpty ? null : e.sets.last;
    e.sets.add(SetLog(last?.value ?? (e.unit == Unit.seconds ? 30 : 10), last?.height));
    _selEx = e;
    _selSet = e.sets.length - 1;
    await _save();
  }

  Future<void> _deleteSel() async {
    final e = _selEx;
    if (e == null || _selSet < 0) return;
    e.sets.removeAt(_selSet);
    if (e.sets.isEmpty) s.exercises.remove(e);
    _selEx = null;
    _selSet = -1;
    await _save();
  }

  Future<void> _addExercise() async {
    final store = StoreScope.read(context);
    final inSession = s.exercises.map((e) => e.name.toLowerCase()).toSet();
    final known =
        store.allExerciseNames().where((n) => !inSession.contains(n.toLowerCase())).toList();
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const D('Ajouter un exercice', size: 28, w: FontWeight.w900),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final n in known)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: D(n, size: 20, w: FontWeight.w700),
                onTap: () => Navigator.pop(c, n),
              ),
            const SizedBox(height: 8),
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nouveau nom')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('ANNULER')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('AJOUTER')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final def = store.defFor(name);
    final last = store.lastLogFor(name);
    final e = ExerciseLog(
      name: name,
      unit: def?.unit ?? last?.unit ?? Unit.reps,
      perSide: def?.perSide ?? last?.perSide ?? false,
      sets: [
        SetLog(last?.sets.first.value ?? (def?.unit == Unit.seconds ? 30 : 10),
            last?.sets.first.height ?? def?.height)
      ],
    );
    s.exercises.add(e);
    _selEx = e;
    _selSet = 0;
    await _save();
  }

  Future<void> _delete() async {
    final store = StoreScope.read(context);
    final ok = await confirmDialog(context, 'Supprimer cette séance ?',
        'Elle disparaît de l\'historique et des courbes. Pense à copier la sauvegarde avant si besoin.',
        yes: 'Supprimer', danger: true);
    if (!ok) return;
    await store.deleteSession(s);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final dur = sessionDuration(s);
    final hold = sessionHold(s);
    final sel = _selEx;
    final selOk = sel != null && _selSet >= 0 && _selSet < sel.sets.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Row(children: [
                    const BackLink('Historique'),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Supprimer la séance',
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline_rounded, color: C.faint),
                    ),
                  ]),
                  GestureDetector(
                    onTap: _editDate,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: D(fmtDayShort(s.date), size: 52, w: FontWeight.w900, height: 1),
                    ),
                  ),
                  const SizedBox(height: 6),
                  D([
                    if (dur != null) fmtMinSec(dur),
                    '${s.totalSets} séries',
                    '${sessionReps(s)} reps',
                    if (hold > 0) '${fmtMinSec(hold)} tenue',
                  ].join(' · '), size: 17, w: FontWeight.w700, color: C.muted),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: TileButton('Copier le texte',
                          icon: Icons.copy_rounded,
                          height: 56,
                          fontSize: 20,
                          bg: C.text,
                          fg: C.bg, onTap: () async {
                        await Clipboard.setData(ClipboardData(text: exportSession(s)));
                        if (context.mounted) toast(context, 'Séance copiée.');
                      }),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TileButton('Ajouter un exo',
                          icon: Icons.edit_outlined,
                          height: 56,
                          fontSize: 20,
                          bg: Colors.transparent,
                          border: C.line,
                          onTap: _addExercise),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  for (final e in s.exercises) _exRow(e),
                  const SizedBox(height: 16),
                  DashedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(exportSession(s),
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12.5, color: C.muted, height: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TileButton(
                    s.healthSynced ? 'Déjà envoyée · renvoyer' : 'Envoyer à Samsung Health',
                    icon: s.healthSynced ? Icons.check_rounded : Icons.favorite_border,
                    height: 52,
                    fontSize: 18,
                    bg: Colors.transparent,
                    fg: C.muted,
                    border: C.surface2,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final err = await HealthSync.writeSession(s,
                          weightKg: store.sendCalories ? store.weightKg : null);
                      if (err == null) await store.markHealthSynced(s);
                      messenger.showSnackBar(
                          SnackBar(content: Text(err ?? 'Envoyée à Samsung Health.')));
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Touche la date pour la changer, une série pour la corriger, + pour en ajouter une.',
                      style: body(12, color: C.faint)),
                ],
              ),
            ),
            if (selOk) _editor(sel, _selSet),
          ],
        ),
      ),
    );
  }

  Widget _exRow(ExerciseLog e) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.surface2))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              D(e.name, size: 22, w: FontWeight.w800, maxLines: 2, height: 1),
              D('${fmtH(e.sets.isEmpty ? null : e.sets.first.height)} · ${e.unit == Unit.seconds ? 'secondes' : 'reps'}${e.perSide ? ' · chaque côté' : ''}',
                  size: 14, w: FontWeight.w700, ls: 0.06, color: C.muted),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 5,
              runSpacing: 5,
              children: [
                for (var i = 0; i < e.sets.length; i++)
                  GestureDetector(
                    onTap: () => _select(e, i),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _selEx == e && _selSet == i ? C.accent : C.surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: D('${e.sets[i].value}',
                            size: 22, color: _selEx == e && _selSet == i ? C.bg : C.text),
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: () => _addSet(e),
                  child: const DashedBox(
                    radius: 10,
                    child: SizedBox(
                        width: 42, height: 42, child: Icon(Icons.add, color: C.faint, size: 22)),
                  ),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _editor(ExerciseLog e, int i) {
    final set = e.sets[i];
    final step = e.unit == Unit.seconds ? 5 : 1;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: C.accent, width: 2),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            D('${e.name} · série ${i + 1}', size: 17, color: C.accent, maxLines: 1),
            const SizedBox(height: 2),
            Row(children: [
              GestureDetector(
                onTap: () async {
                  final h = await pickHeight(context, set.height, title: 'Hauteur · ${e.name}');
                  set.height = h;
                  await _save();
                },
                child: D('Hauteur ${fmtH(set.height, space: true)}',
                    size: 17, w: FontWeight.w700, color: C.muted),
              ),
              const D(' · ', size: 17, color: C.muted),
              GestureDetector(
                onTap: _deleteSel,
                child: const D('Supprimer', size: 17, w: FontWeight.w700),
              ),
            ]),
          ]),
        ),
        RoundButton(
            plus: false,
            size: 52,
            onTap: set.value - step >= 0
                ? () {
                    set.value -= step;
                    _save();
                  }
                : null),
        GestureDetector(
          onTap: () async {
            final v = await numberDialog(context, 'Valeur', set.value);
            if (v != null && v >= 0) {
              set.value = v;
              await _save();
            }
          },
          child: SizedBox(
            width: 64,
            child: Center(child: D('${set.value}', size: 44)),
          ),
        ),
        RoundButton(
            plus: true,
            size: 52,
            onTap: () {
              set.value += step;
              _save();
            }),
      ]),
    );
  }
}
