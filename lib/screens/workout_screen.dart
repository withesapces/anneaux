import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../estimate.dart';
import '../format.dart';
import '../models.dart';
import '../sound.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/height_control.dart';
import '../widgets/ui.dart';
import 'recap_screen.dart';

/// Segments de la barre de progression (1 par exercice).
List<SegSpec> segsFor(AppStore store, List<ExerciseLog> exs, int current) => [
      for (var i = 0; i < exs.length; i++)
        SegSpec(exs[i].sets.length, targetSets(store, exs[i]), i == current),
    ];

/// Écran de séance : une série à la fois, repos automatique entre chaque série.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with TickerProviderStateMixin {
  late AppStore store;
  bool _init = false;

  final Beeper _beeper = Beeper();
  Timer? _ticker;
  final Stopwatch _chrono = Stopwatch();
  int _chronoTarget = 0;
  bool _chronoBeeped = false;
  int _lastCountdownBeep = -1;
  bool _manual = false;

  int _value = 10;
  double? _height;

  late final AnimationController _flash =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  String _flashLine = '';
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  WorkoutDraft get _d => store.draft!;
  ExerciseLog get _ex => _d.session.exercises[_d.exIndex];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    store = StoreScope.read(context);
    final d = store.draft;
    if (d != null) {
      if (d.session.exercises.isEmpty) {
        d.exIndex = 0;
      } else {
        d.exIndex = min(max(d.exIndex, 0), d.session.exercises.length - 1);
        _prefill();
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _beeper.dispose();
    _flash.dispose();
    _pulse.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // ---------- Logique ----------

  int _target(ExerciseLog ex) => targetSets(store, ex);

  int get _restLeft {
    final end = _d.restEndsAt;
    if (end == null) return 0;
    return (end.difference(DateTime.now()).inMilliseconds / 1000).ceil();
  }

  double get _restLeftExact {
    final end = _d.restEndsAt;
    if (end == null) return 0;
    return end.difference(DateTime.now()).inMilliseconds / 1000;
  }

  /// Série de référence : ce que tu as fait la dernière fois au même rang.
  SetLog? _refSet(ExerciseLog ex, int i) {
    final last = store.lastLogFor(ex.name);
    if (last == null || last.sets.isEmpty) return null;
    return last.sets[min(i, last.sets.length - 1)];
  }

  /// Pré-remplit la série avec ce que tu as fait la dernière fois au même rang.
  void _prefill() {
    final ex = _ex;
    final ref = _refSet(ex, ex.sets.length);
    _value = ref?.value ??
        (ex.sets.isNotEmpty ? ex.sets.last.value : (ex.unit == Unit.seconds ? 30 : 10));
    _height = ex.sets.isNotEmpty
        ? ex.sets.last.height
        : (ref?.height ?? store.defFor(ex.name)?.height);
    _manual = false;
  }

  void _onTick() {
    if (!mounted || store.draft == null) return;
    if (_d.restEndsAt != null) {
      final left = _restLeft;
      if (left <= 0) {
        _endRest(alert: left > -5);
        return;
      }
      if (left <= 3 && left != _lastCountdownBeep) {
        _lastCountdownBeep = left;
        _beeper.tick(sound: store.sound);
      }
      setState(() {});
    } else if (_chrono.isRunning) {
      if (!_chronoBeeped && _chronoTarget > 0 && _chrono.elapsed.inSeconds >= _chronoTarget) {
        _chronoBeeped = true;
        _beeper.restOver(sound: store.sound);
      }
      setState(() {});
    } else if (DateTime.now().millisecond < 100) {
      // Rafraîchit le temps écoulé une fois par seconde.
      setState(() {});
    }
  }

  void _startRest() {
    _lastCountdownBeep = -1;
    _d.restEndsAt = DateTime.now().add(Duration(seconds: store.restSeconds));
  }

  void _endRest({bool alert = false}) {
    _d.restEndsAt = null;
    store.saveDraft();
    if (alert) _beeper.restOver(sound: store.sound);
    setState(() {});
  }

  void _shiftRest(int seconds) {
    final end = _d.restEndsAt;
    if (end == null) return;
    final next = end.add(Duration(seconds: seconds));
    if (!next.isAfter(DateTime.now())) {
      _endRest();
      return;
    }
    _d.restEndsAt = next;
    _lastCountdownBeep = -1;
    store.saveDraft();
    setState(() {});
  }

  /// Prochain exercice pas encore terminé après [from] (en bouclant), ou null.
  int? _nextIncomplete(int from) {
    final exs = _d.session.exercises;
    for (var k = 1; k <= exs.length; k++) {
      final i = (from + k) % exs.length;
      if (exs[i].sets.length < _target(exs[i])) return i;
    }
    return null;
  }

  void _validate() {
    if (_chrono.isRunning) _stopChrono();
    final ex = _ex;
    final wasBonus = ex.sets.length >= _target(ex);
    final ref = _refSet(ex, ex.sets.length);
    final hadRef = ex.sets.length < (store.lastLogFor(ex.name)?.sets.length ?? 0);
    ex.sets.add(SetLog(_value, _height));
    HapticFeedback.mediumImpact();

    final delta = ref == null || !hadRef ? null : _value - ref.value;
    final u = ex.unit == Unit.seconds ? 's' : 'reps';
    _flashLine = wasBonus
        ? 'Bonus dans la poche'
        : delta == null
            ? 'Nouvelle référence'
            : delta > 0
                ? '+$delta $u vs la dernière fois'
                : delta == 0
                    ? 'Comme la dernière fois'
                    : 'On se rattrape à la prochaine';
    _flash.forward(from: 0);

    if (!wasBonus && ex.sets.length >= _target(ex)) {
      final next = _nextIncomplete(_d.exIndex);
      if (next == null) {
        store.saveDraft();
        setState(() {});
        _finish();
        return;
      }
      _d.exIndex = next;
    }
    _startRest();
    _prefill();
    store.saveDraft();
    setState(() {});
  }

  void _goTo(int i) {
    if (i < 0 || i >= _d.session.exercises.length) return;
    if (_chrono.isRunning) _chrono.stop();
    _d.exIndex = i;
    _prefill();
    store.saveDraft();
    setState(() {});
  }

  void _skipToNext() {
    final next = _nextIncomplete(_d.exIndex);
    if (next == null) {
      _finish();
    } else {
      _goTo(next);
    }
  }

  void _startChrono() {
    _chronoTarget = _value;
    _chronoBeeped = false;
    _chrono
      ..reset()
      ..start();
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _stopChrono() {
    _chrono.stop();
    _value = _chrono.elapsed.inSeconds;
  }

  Future<void> _finish() async {
    if (_chrono.isRunning) _chrono.stop();
    final nav = Navigator.of(context);
    final saved = await nav.push<bool>(
      MaterialPageRoute(builder: (_) => const RecapScreen()),
    );
    if (saved == true) {
      if (mounted) nav.pop();
      return;
    }
    if (mounted && store.draft != null) {
      _prefill();
      setState(() {});
    }
  }

  // ---------- Dialogues ----------

  Future<void> _editSet(int i) async {
    final ex = _ex;
    final s = ex.sets[i];
    final vCtrl = TextEditingController(text: '${s.value}');
    final hCtrl = TextEditingController(text: s.height == null ? '' : fmtHeight(s.height!));
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: D('Série ${i + 1}', size: 30, w: FontWeight.w900),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: vCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: ex.unit == Unit.seconds ? 'Secondes' : 'Répétitions'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Hauteur'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'delete'),
            child: const Text('SUPPRIMER'),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('ANNULER')),
          FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('OK')),
        ],
      ),
    );
    if (r == 'delete') {
      ex.sets.removeAt(i);
    } else if (r == 'save') {
      s.value = int.tryParse(vCtrl.text.trim()) ?? s.value;
      final h = hCtrl.text.trim().replaceAll(',', '.');
      s.height = h.isEmpty ? null : (double.tryParse(h) ?? s.height);
    } else {
      return;
    }
    _prefill();
    store.saveDraft();
    setState(() {});
  }

  Future<void> _pickHeight() async {
    final h = await pickHeight(context, _height, title: 'Hauteur de sangle · ${_ex.name}');
    setState(() => _height = h);
  }

  Future<void> _editValue() async {
    final v = await numberDialog(
        context, _ex.unit == Unit.seconds ? 'Secondes' : 'Répétitions', _value);
    if (v != null && v >= 0) setState(() => _value = v);
  }

  Future<void> _openExerciseList() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) {
          final exs = _d.session.exercises;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  const Lbl('Exercices de la séance'),
                  const SizedBox(height: 8),
                  for (var i = 0; i < exs.length; i++)
                    InkWell(
                      onTap: () {
                        Navigator.pop(c);
                        _goTo(i);
                      },
                      child: Container(
                        height: 60,
                        decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: C.surface2))),
                        child: Row(children: [
                          SizedBox(
                            width: 32,
                            child: exs[i].sets.length >= _target(exs[i])
                                ? Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                        color: C.text, shape: BoxShape.circle),
                                    child: const Icon(Icons.check, size: 16, color: C.bg))
                                : i == _d.exIndex
                                    ? Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: C.accent, width: 4)))
                                    : D((i + 1).toString().padLeft(2, '0'),
                                        size: 16, w: FontWeight.w700, color: C.faint),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                D(exs[i].name,
                                    size: 22,
                                    w: FontWeight.w700,
                                    color: i == _d.exIndex ? C.accent : C.text,
                                    maxLines: 1),
                                Text(
                                    exs[i].sets.isEmpty
                                        ? 'Pas encore fait'
                                        : '${dottedSets(exs[i])} · ${exs[i].sets.length}/${_target(exs[i])}',
                                    style: body(13, color: C.muted)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: C.faint),
                            tooltip: 'Retirer de la séance',
                            onPressed: exs.length <= 1
                                ? null
                                : () {
                                    exs.removeAt(i);
                                    if (_d.exIndex >= exs.length) _d.exIndex = exs.length - 1;
                                    _prefill();
                                    store.saveDraft();
                                    setSheet(() {});
                                    setState(() {});
                                  },
                          ),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TileButton('Ajouter un exercice',
                      icon: Icons.add,
                      height: 56,
                      fontSize: 22,
                      bg: Colors.transparent,
                      border: C.line, onTap: () async {
                    Navigator.pop(c);
                    await _addExercise();
                  }),
                  const SizedBox(height: 12),
                  BigButton('Terminer la séance', height: 72, fontSize: 30, onTap: () {
                    Navigator.pop(c);
                    _finish();
                  }),
                  const SizedBox(height: 4),
                  Center(
                    child: LinkButton('Retour à l\'accueil', size: 18, onTap: () {
                      Navigator.pop(c);
                      Navigator.pop(context);
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addExercise() async {
    final inSession = _d.session.exercises.map((e) => e.name.toLowerCase()).toSet();
    final known = store
        .allExerciseNames()
        .where((n) => !inSession.contains(n.toLowerCase()))
        .toList();
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const D('Ajouter un exercice', size: 28, w: FontWeight.w900),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n in known)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: D(n, size: 20, w: FontWeight.w700),
                  onTap: () => Navigator.pop(c, n),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'Nouveau nom'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('ANNULER')),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text('AJOUTER'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final def = store.defFor(name);
    final last = store.lastLogFor(name);
    _d.session.exercises.insert(
      _d.exIndex + 1,
      ExerciseLog(
        name: name,
        unit: def?.unit ?? last?.unit ?? Unit.reps,
        perSide: def?.perSide ?? last?.perSide ?? false,
      ),
    );
    _goTo(_d.exIndex + 1);
  }

  // ---------- Interface ----------

  @override
  Widget build(BuildContext context) {
    StoreScope.of(context);
    if (store.draft == null || _d.session.exercises.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BackLink('Accueil'),
              Spacer(),
              D('Aucune séance en cours', size: 48, w: FontWeight.w900),
              Spacer(),
            ]),
          ),
        ),
      );
    }
    final resting = _d.restEndsAt != null;
    final restEnd = resting && _restLeft <= 3;
    final chrono = !resting && _ex.unit == Unit.seconds && !_manual;
    final goal = chrono && _chrono.isRunning && _chrono.elapsed.inSeconds >= _chronoTarget;

    final Color bg = restEnd ? C.accentNight : (goal ? C.accent : C.bg);
    final Widget content = resting
        ? (restEnd ? _restEndView() : _restView())
        : chrono
            ? _chronoView(goal)
            : _setView();

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: content,
            ),
          ),
          Positioned.fill(child: IgnorePointer(child: _flashOverlay())),
        ],
      ),
    );
  }

  Widget _flashOverlay() => AnimatedBuilder(
        animation: _flash,
        builder: (context, _) {
          final t = _flash.value;
          if (!_flash.isAnimating) return const SizedBox.shrink();
          final o = t < 0.55 ? 1.0 : 1 - (t - 0.55) / 0.45;
          return Opacity(
            opacity: o.clamp(0.0, 1.0),
            child: Container(
              color: C.accent,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, border: Border.all(color: C.bg, width: 12)),
                  child: const Icon(Icons.check_rounded, size: 96, color: C.bg),
                ),
                const SizedBox(height: 14),
                const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: D('Série validée', size: 64, w: FontWeight.w900, color: C.bg)),
                D(_flashLine, size: 30, color: C.bg, align: TextAlign.center),
              ]),
            ),
          );
        },
      );

  /// Barre segmentée + temps écoulé / restant / fin.
  Widget _topBar({bool onAccent = false}) {
    final left = estimateRemaining(
      store,
      _d.session.exercises,
      restLeft: _d.restEndsAt == null ? 0 : max(0, _restLeft),
      start: _d.session.date,
    );
    final end = DateTime.now().add(Duration(seconds: left));
    final elapsed = DateTime.now().difference(_d.session.date).inSeconds;
    final strong = onAccent ? C.bg : C.text;
    final soft = onAccent ? C.bg : C.muted;
    TextSpan sp(String a, String b, {bool first = true}) => TextSpan(children: [
          if (first) TextSpan(text: a, style: TextStyle(color: strong)),
          TextSpan(text: b, style: TextStyle(color: soft)),
          if (!first) TextSpan(text: a, style: TextStyle(color: strong)),
        ]);
    final style = disp(19, w: FontWeight.w700, ls: 0.04, color: soft);
    return Column(children: [
      SegmentedBar(
        segsFor(store, _d.session.exercises, _d.exIndex),
        doneColor: onAccent ? C.bg : C.text,
        todoColor: onAccent ? C.bg.withValues(alpha: 0.25) : C.line,
        currentColor: onAccent ? C.text : C.accent,
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text.rich(sp(fmtElapsed(elapsed), ' ÉCOULÉ'), style: style),
        Text.rich(sp('~${(left / 60).round()} MIN', ' RESTANT'), style: style),
        Text.rich(sp(fmtHour(end), 'FIN ', first: false), style: style),
      ]),
    ]);
  }

  Widget _listButton({bool onAccent = false}) => Material(
        color: onAccent ? C.bg.withValues(alpha: 0.12) : C.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openExerciseList,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.format_list_bulleted_rounded,
                color: onAccent ? C.bg : C.text, size: 28),
          ),
        ),
      );

  Widget _setView() {
    final ex = _ex;
    final isSec = ex.unit == Unit.seconds;
    final target = _target(ex);
    final bonus = ex.sets.length >= target;
    final last = store.lastLogFor(ex.name);
    final first = last == null;
    final i = ex.sets.length;
    final hasRef = last != null && i < last.sets.length;
    final ref = hasRef ? last.sets[i].value : null;
    final exs = _d.session.exercises;
    final prev = _d.exIndex > 0 ? exs[_d.exIndex - 1].name : null;
    final next = _d.exIndex < exs.length - 1 ? exs[_d.exIndex + 1].name : null;

    final dots = Row(mainAxisSize: MainAxisSize.min, children: [
      SetDots(
          done: i,
          target: target,
          showCurrent: !bonus,
          bonusLabel: bonus ? '+${i - target + 1}' : null,
          onTapDone: _editSet),
      if (!bonus) ...[
        const SizedBox(width: 10),
        D('${i + 1}/$target', size: 22),
      ],
    ]);

    final unitLabel = bonus
        ? (isSec ? 'secondes en rab' : 'reps en rab')
        : isSec
            ? (ex.perSide ? 'secondes par côté' : 'secondes')
            : (ex.perSide ? 'reps par côté' : 'reps');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topBar(),
        const SizedBox(height: 14),
        if (bonus) ...[
          Container(
            height: 52,
            decoration:
                BoxDecoration(color: C.accentNight, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_rounded, color: C.accent, size: 26),
                SizedBox(width: 10),
                D('Objectif atteint · rab possible', size: 24, color: C.accent, ls: 0.04),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(children: [
          Lbl('Exercice ${_d.exIndex + 1}/${exs.length}', size: 17),
          const Spacer(),
          if (bonus)
            const Tag('Série bonus', style: TagStyle.outlineAccent)
          else if (first)
            const Tag('Première fois', style: TagStyle.outlineGray),
          const SizedBox(width: 10),
          _listButton(),
        ]),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: D(ex.name, size: 92, w: FontWeight.w900, height: 0.9, ls: -0.005),
        ),
        const SizedBox(height: 10),
        Row(children: [
          HeightBadge(_height, onTap: _pickHeight),
          if (ex.perSide) ...[
            const SizedBox(width: 10),
            const Tag('Chaque côté', size: 18),
          ],
          const Spacer(),
          if (!ex.perSide) dots,
        ]),
        if (ex.perSide) ...[
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: dots),
        ],
        if (bonus && i > target)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Touche une pastille pour corriger une série.',
                textAlign: TextAlign.right, style: body(12, color: C.faint)),
          ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Row(children: [
                  RoundButton(
                      plus: false,
                      onTap: _value - (isSec ? 5 : 1) >= 0
                          ? () => setState(() => _value -= isSec ? 5 : 1)
                          : null),
                  Expanded(
                    child: GestureDetector(
                      onTap: _editValue,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('$_value',
                            style: disp(250,
                                color: bonus ? C.accent : C.text, height: 0.9)),
                        ),
                      ),
                    ),
                  ),
                  RoundButton(plus: true, onTap: () => setState(() => _value += isSec ? 5 : 1)),
                ]),
              ),
              const SizedBox(height: 10),
              D(unitLabel, size: 20, w: FontWeight.w700, ls: 0.14, color: C.muted),
              const SizedBox(height: 14),
              if (first)
                DashedBox(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const D('Pas encore de dernière fois', size: 24, w: FontWeight.w800),
                      const SizedBox(height: 4),
                      Text('Cette série devient ta référence.', style: body(13, color: C.muted)),
                    ]),
                  ),
                )
              else if (bonus || ref == null)
                Text(
                  'Pas de série ${i + 1} la dernière fois.\nTout ce que tu fais ici compte comme un plus.',
                  textAlign: TextAlign.center,
                  style: body(15, color: C.muted, height: 1.45),
                )
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'DERNIÈRE FOIS : '),
                        TextSpan(text: '$ref', style: const TextStyle(color: C.text)),
                      ]),
                      style: disp(28, w: FontWeight.w700, color: C.muted),
                    ),
                    const SizedBox(width: 12),
                    DeltaChip(_value - ref),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BigButton(
          bonus ? 'Valider le bonus' : 'Valider la série',
          icon: const Icon(Icons.check_rounded, color: C.bg, size: 40),
          onTap: _validate,
        ),
        const SizedBox(height: 8),
        if (bonus)
          BigButton(
            _nextIncomplete(_d.exIndex) == null ? 'Terminer la séance ›' : 'Stop, exercice suivant ›',
            outline: true,
            fg: C.text,
            height: 64,
            fontSize: 24,
            radius: 18,
            onTap: _skipToNext,
          )
        else
          Row(children: [
            LinkButton(prev == null ? '‹ Préc.' : '‹ $prev',
                onTap: prev == null ? null : () => _goTo(_d.exIndex - 1)),
            const Spacer(),
            if (isSec) LinkButton('Chrono', onTap: () => setState(() => _manual = false)),
            const Spacer(),
            LinkButton(next == null ? 'Terminer ›' : '$next ›',
                onTap: next == null ? _finish : () => _goTo(_d.exIndex + 1)),
          ]),
      ],
    );
  }

  Widget _chronoView(bool goal) {
    final ex = _ex;
    final target = _target(ex);
    final running = _chrono.isRunning;
    final elapsed = running ? _chrono.elapsed.inMilliseconds / 1000 : 0.0;
    final secs = elapsed.floor();
    final objective = running ? _chronoTarget : _value;
    final best = bestSet(store.sessions, ex.name);
    final record = goal && best != null && secs > best;
    final exs = _d.session.exercises;
    final prev = _d.exIndex > 0 ? exs[_d.exIndex - 1].name : null;
    final next = _d.exIndex < exs.length - 1 ? exs[_d.exIndex + 1].name : null;
    final fg = goal ? C.bg : C.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topBar(onAccent: goal),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Lbl(
                'Exercice ${_d.exIndex + 1}/${exs.length} · série ${min(ex.sets.length + 1, max(target, ex.sets.length + 1))}/$target',
                size: 17,
                color: goal ? C.bg : C.muted),
          ),
          if (!goal) _listButton(),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: D(ex.name, size: 76, w: FontWeight.w900, height: 0.95, color: fg),
            ),
          ),
          const SizedBox(width: 14),
          if (record)
            const Tag('★ Record', style: TagStyle.dark, size: 22)
          else
            HeightBadge(_height,
                size: 32, icon: false, color: fg, onTap: running ? null : _pickHeight),
        ]),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final size = min(box.maxWidth, box.maxHeight - 90).clamp(160.0, 380.0);
            final p = objective <= 0 ? 0.0 : elapsed / objective;
            final over = goal ? ((elapsed - objective) / max(1, objective)).clamp(0.0, 1.0) : 0.0;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Ring(
                  progress: goal ? over : p,
                  size: size,
                  stroke: size * 0.075,
                  color: goal ? C.accentDark : C.text,
                  track: goal ? C.bg : C.surface2,
                  knob: running && !goal,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(running ? '$secs' : '$objective',
                              style: disp(size * 0.5, color: fg, height: 0.9)),
                          Padding(
                            padding: EdgeInsets.only(bottom: size * 0.04),
                            child: D('s', size: size * 0.13, color: fg),
                          ),
                        ],
                      ),
                    ),
                    if (goal)
                      D('Objectif $objective s · +${secs - objective} s',
                          size: size * 0.07, color: C.bg)
                    else
                      Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'OBJECTIF '),
                          TextSpan(
                              text: '$objective S', style: const TextStyle(color: C.accent)),
                        ]),
                        style: disp(size * 0.07, color: C.muted),
                      ),
                  ]),
                ),
                const SizedBox(height: 22),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: D(
                    goal
                        ? 'Objectif explosé'
                        : running
                            ? 'Tiens ! Encore ${max(0, objective - secs)} s'
                            : (store.lastLogFor(ex.name) == null
                                ? 'Première fois · vise $objective s'
                                : 'Prêt ? Monte sur les anneaux'),
                    size: 40,
                    color: fg,
                  ),
                ),
              ],
            );
          }),
        ),
        if (!running)
          BigButton('Lancer le chrono',
              icon: const Icon(Icons.play_arrow_rounded, color: C.bg, size: 44),
              onTap: _startChrono)
        else if (goal)
          BigButton('Stop et valider',
              bg: C.bg,
              fg: C.accent,
              icon: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                      color: C.accent, borderRadius: BorderRadius.circular(5))),
              onTap: _validate)
        else
          BigButton('Stop',
              icon: Container(
                  width: 26,
                  height: 26,
                  decoration:
                      BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(5))),
              onTap: _validate),
        const SizedBox(height: 8),
        if (goal)
          SizedBox(
            height: 56,
            child: Center(
                child: Text('Le chrono continue tant que tu tiens.',
                    style: body(14, color: C.bg, w: FontWeight.w600))),
          )
        else
          Row(children: [
            Flexible(
              child: LinkButton('‹ Préc.',
                  size: 19, onTap: prev == null || running ? null : () => _goTo(_d.exIndex - 1)),
            ),
            const Spacer(),
            LinkButton('Saisir à la main',
                size: 19,
                onTap: () {
                  if (_chrono.isRunning) _stopChrono();
                  setState(() => _manual = true);
                }),
            const Spacer(),
            Flexible(
              child: LinkButton(next == null ? 'Terminer ›' : 'Suiv. ›',
                  size: 19,
                  onTap: running ? null : (next == null ? _finish : () => _goTo(_d.exIndex + 1))),
            ),
          ]),
      ],
    );
  }

  Widget _restView() {
    final ex = _ex;
    final target = _target(ex);
    final left = max(0.0, _restLeftExact);
    final total = max(store.restSeconds.toDouble(), left);
    final elapsed = DateTime.now().difference(_d.session.date).inSeconds;
    final estLeft = estimateRemaining(store, _d.session.exercises,
        restLeft: max(0, _restLeft), start: _d.session.date);
    final end = DateTime.now().add(Duration(seconds: estLeft));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const D('Repos', size: 40, w: FontWeight.w900),
          const Spacer(),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '${fmtMinSec(elapsed)} ÉCOULÉ · FIN '),
              TextSpan(text: fmtHour(end), style: const TextStyle(color: C.text)),
            ]),
            style: disp(17, w: FontWeight.w700, color: C.muted),
          ),
        ]),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final size = min(box.maxWidth, box.maxHeight).clamp(160.0, 360.0);
            return Center(
              child: Ring(
                progress: left / total,
                size: size,
                stroke: size * 0.08,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(fmtClock(left.ceil()), style: disp(size * 0.36, height: 0.95)),
                  ),
                  D('Sur ${fmtClock(store.restSeconds)}',
                      size: size * 0.06, w: FontWeight.w700, ls: 0.1, color: C.muted),
                ]),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TileButton('−30 s', onTap: () => _shiftRest(-30))),
          const SizedBox(width: 12),
          Expanded(child: TileButton('+30 s', onTap: () => _shiftRest(30))),
        ]),
        const SizedBox(height: 16),
        Panel(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Lbl('Ensuite', color: C.accent),
              const Spacer(),
              SetDots(done: ex.sets.length, target: target, size: 14),
              const SizedBox(width: 8),
              D(ex.sets.length >= target ? 'bonus' : '${ex.sets.length + 1}/$target',
                  size: 17),
            ]),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: D(ex.name, size: 52, w: FontWeight.w900, height: 1),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Lbl('Cible', size: 14),
                  D(ex.unit == Unit.seconds ? '$_value s' : '$_value reps',
                      size: 44, height: 1),
                ]),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _pickHeight,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Lbl('Sangle', size: 14),
                    D(fmtH(_height, space: true), size: 44, height: 1),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        BigButton('Passer le repos',
            icon: const Icon(Icons.fast_forward_rounded, color: C.bg, size: 40),
            fontSize: 36,
            onTap: () => _endRest()),
      ],
    );
  }

  Widget _restEndView() {
    final ex = _ex;
    final target = _target(ex);
    final left = max(1, _restLeft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          D('Prépare-toi', size: 40, w: FontWeight.w900, color: C.accent),
          Spacer(),
          D('Bip · bip · bip', size: 16, w: FontWeight.w700, color: C.muted),
        ]),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final size = min(box.maxWidth, box.maxHeight).clamp(160.0, 380.0);
            return Center(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final t = _pulse.value;
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: C.accentDark.withValues(alpha: 1 - 0.6 * t), width: 10 + 6 * t),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: child,
                  );
                },
                child: Ring(
                  progress: _restLeftExact / max(1, store.restSeconds),
                  size: size - 48,
                  stroke: (size - 48) * 0.085,
                  track: C.accent.withValues(alpha: 0.18),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('$left', style: disp(size * 0.62, color: C.accent, height: 0.9)),
                  ),
                ),
              ),
            );
          }),
        ),
        const D('Monte sur les anneaux', size: 44, align: TextAlign.center, height: 1),
        const SizedBox(height: 18),
        Panel(
          color: Colors.transparent,
          border: C.accent,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Lbl(ex.sets.length >= target ? 'Série bonus' : 'Série ${ex.sets.length + 1}/$target',
                    color: C.accent),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: D(ex.name, size: 40, w: FontWeight.w900, height: 1.05),
                ),
                D('Cible ${ex.unit == Unit.seconds ? '$_value s' : '$_value reps'}',
                    size: 20, w: FontWeight.w700, color: C.muted),
              ]),
            ),
            D(fmtH(_height, space: true), size: 52, w: FontWeight.w900),
          ]),
        ),
        const SizedBox(height: 18),
        BigButton('Go', onTap: () => _endRest()),
      ],
    );
  }
}
