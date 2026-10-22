import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../estimate.dart';
import '../format.dart';
import '../health_sync.dart';
import '../models.dart';
import '../sound.dart';
import '../store.dart';
import '../widgets/steppers.dart';

/// Écran de séance : une série à la fois, repos automatique entre chaque série.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late AppStore store;
  bool _init = false;

  final Beeper _beeper = Beeper();
  Timer? _ticker;
  final Stopwatch _chrono = Stopwatch();
  int _chronoTarget = 0;
  bool _chronoBeeped = false;
  int _lastCountdownBeep = -1;

  int _value = 10;
  double? _height;

  WorkoutDraft get _d => store.draft!;
  ExerciseLog get _ex => _d.session.exercises[_d.exIndex];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick());
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

  /// Pré-remplit la série avec ce que tu as fait la dernière fois au même rang.
  void _prefill() {
    final ex = _ex;
    final last = store.lastLogFor(ex.name);
    final i = ex.sets.length;
    final SetLog? ref = (last != null && last.sets.isNotEmpty)
        ? last.sets[min(i, last.sets.length - 1)]
        : null;
    _value = ref?.value ??
        (ex.sets.isNotEmpty ? ex.sets.last.value : (ex.unit == Unit.seconds ? 30 : 10));
    _height = ex.sets.isNotEmpty
        ? ex.sets.last.height
        : (ref?.height ?? store.defFor(ex.name)?.height);
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
    } else {
      // Rafraîchit l'estimation de fin de séance.
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

  void _validate() {
    if (_chrono.isRunning) _stopChrono();
    final ex = _ex;
    ex.sets.add(SetLog(_value, _height));
    HapticFeedback.mediumImpact();
    final exDone = ex.sets.length >= _target(ex);
    final lastEx = _d.exIndex >= _d.session.exercises.length - 1;
    if (exDone && lastEx) {
      store.saveDraft();
      setState(() {});
      _finish(fromLastSet: true);
      return;
    }
    if (exDone) _d.exIndex++;
    _startRest();
    _prefill();
    store.saveDraft();
    setState(() {});
  }

  void _goTo(int i) {
    if (i < 0 || i >= _d.session.exercises.length) return;
    if (_chrono.isRunning) _stopChrono();
    _d.exIndex = i;
    _prefill();
    store.saveDraft();
    setState(() {});
  }

  void _toggleChrono() {
    if (_chrono.isRunning) {
      _stopChrono();
    } else {
      _chronoTarget = _value;
      _chronoBeeped = false;
      _chrono
        ..reset()
        ..start();
      HapticFeedback.mediumImpact();
    }
    setState(() {});
  }

  void _stopChrono() {
    _chrono.stop();
    _value = _chrono.elapsed.inSeconds;
  }

  Future<void> _finish({bool fromLastSet = false}) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(fromLastSet ? 'Séance terminée 💪' : 'Terminer la séance ?'),
        content: Text('${_d.session.totalSets} séries enregistrées. '
            'Les exercices sans série seront ignorés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(fromLastSet ? 'Ajouter une série' : 'Continuer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok != true) {
      if (mounted) {
        _prefill();
        setState(() {});
      }
      return;
    }
    final saved = await store.finishWorkout();
    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(saved == null ? 'Séance vide, rien enregistré.' : 'Séance enregistrée.'),
    ));
    if (saved != null && store.healthEnabled) {
      final err = await HealthSync.writeSession(saved);
      if (err == null) await store.markHealthSynced(saved);
      messenger.showSnackBar(SnackBar(
        content: Text(err ?? 'Séance envoyée à Samsung Health (via Health Connect).'),
      ));
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
        title: Text('Série ${i + 1}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: vCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: ex.unit == Unit.seconds ? 'Secondes' : 'Répétitions'),
            ),
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
            child: const Text('Supprimer'),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
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
              constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < exs.length; i++)
                    ListTile(
                      selected: i == _d.exIndex,
                      leading: Icon(exs[i].sets.length >= _target(exs[i])
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked),
                      title: Text(exs[i].name),
                      subtitle: Text(exs[i].sets.isEmpty ? 'Pas encore fait' : setsSummary(exs[i])),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
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
                      onTap: () {
                        Navigator.pop(c);
                        _goTo(i);
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Ajouter un exercice'),
                    onTap: () async {
                      Navigator.pop(c);
                      await _addExercise();
                    },
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
        title: const Text('Ajouter un exercice'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n in known)
                ListTile(
                  dense: true,
                  title: Text(n),
                  onTap: () => Navigator.pop(c, n),
                ),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'Nouveau nom'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text('Ajouter'),
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
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Aucune séance en cours.')),
      );
    }
    final resting = _d.restEndsAt != null;
    return Scaffold(
      appBar: AppBar(
        title: _titleWithEstimate(context),
        actions: [
          IconButton(
            onPressed: _openExerciseList,
            icon: const Icon(Icons.list),
            tooltip: 'Exercices',
          ),
          TextButton(onPressed: () => _finish(), child: const Text('Terminer')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: resting ? _restView(context) : _setView(context),
        ),
      ),
    );
  }

  Widget _titleWithEstimate(BuildContext context) {
    final left = estimateRemaining(
      store,
      _d.session.exercises,
      restLeft: _d.restEndsAt == null ? 0 : max(0, _restLeft),
      start: _d.session.date,
    );
    final end = DateTime.now().add(Duration(seconds: left));
    final elapsed = DateTime.now().difference(_d.session.date).inSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Exo ${_d.exIndex + 1} / ${_d.session.exercises.length}'),
        Text(
          '${fmtDuration(elapsed)} écoulées · reste ≈ ${fmtDuration(left)} · fin ${fmtHour(end)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final last = store.lastLogFor(_ex.name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _ex.name + (_ex.perSide ? ' (chaque côté)' : ''),
          style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          last == null ? 'Première fois' : 'La dernière fois : ${setsSummary(last)}',
          style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _setView(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ex = _ex;
    final isSec = ex.unit == Unit.seconds;
    final target = _target(ex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < ex.sets.length; i++)
              ActionChip(
                avatar: const Icon(Icons.check, size: 18),
                label: Text('${fmtValue(ex.sets[i].value, ex.unit)}'
                    '${ex.sets[i].height == null ? '' : ' · h${fmtHeight(ex.sets[i].height!)}'}'),
                onPressed: () => _editSet(i),
              ),
          ],
        ),
        const Spacer(),
        Text(
          ex.sets.length >= target
              ? 'Série ${ex.sets.length + 1} (bonus)'
              : 'Série ${ex.sets.length + 1} / $target',
          textAlign: TextAlign.center,
          style: t.titleLarge?.copyWith(color: cs.primary),
        ),
        const SizedBox(height: 12),
        if (_chrono.isRunning)
          GestureDetector(
            onTap: _toggleChrono,
            child: Text(
              '${_chrono.elapsed.inSeconds} s',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.w800,
                color: _chrono.elapsed.inSeconds >= _chronoTarget ? cs.primary : cs.onSurface,
              ),
            ),
          )
        else
          BigCounter(
            value: _value,
            suffix: isSec ? ' s' : '',
            step: isSec ? 5 : 1,
            onChanged: (v) => setState(() => _value = v),
          ),
        Text(
          isSec ? 'secondes' : 'répétitions',
          textAlign: TextAlign.center,
          style: t.bodyMedium,
        ),
        if (isSec) ...[
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              onPressed: _toggleChrono,
              icon: Icon(_chrono.isRunning ? Icons.stop : Icons.timer_outlined),
              label: Text(_chrono.isRunning
                  ? 'Stop (objectif $_chronoTarget s)'
                  : 'Lancer le chrono'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        HeightStepper(value: _height, onChanged: (h) => setState(() => _height = h)),
        const Spacer(),
        SizedBox(
          height: 64,
          child: FilledButton.icon(
            onPressed: _validate,
            icon: const Icon(Icons.check, size: 28),
            label: const Text('Valider la série', style: TextStyle(fontSize: 20)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: _d.exIndex > 0 ? () => _goTo(_d.exIndex - 1) : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Exo précédent'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _d.exIndex < _d.session.exercises.length - 1
                  ? () => _goTo(_d.exIndex + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Exo suivant'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _restView(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final left = max(0, _restLeft);
    final total = max(1, store.restSeconds);
    final double progress = min(1.0, max(0.0, left / total));
    final ex = _ex;
    final target = _target(ex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Repos', textAlign: TextAlign.center, style: t.titleLarge),
        const Spacer(),
        Center(
          child: SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
                Center(
                  child: Text(
                    fmtClock(left),
                    style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(onPressed: () => _shiftRest(-30), child: const Text('− 30 s')),
            const SizedBox(width: 16),
            OutlinedButton(onPressed: () => _shiftRest(30), child: const Text('+ 30 s')),
          ],
        ),
        const Spacer(),
        Text('Ensuite', textAlign: TextAlign.center, style: t.bodyMedium),
        Text(
          '${ex.name} · série ${ex.sets.length + 1}/$target',
          textAlign: TextAlign.center,
          style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          '${fmtValue(_value, ex.unit)}${_height == null ? '' : ' · hauteur ${fmtHeight(_height!)}'}',
          textAlign: TextAlign.center,
          style: t.bodyLarge,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 64,
          child: FilledButton.icon(
            onPressed: () => _endRest(),
            icon: const Icon(Icons.skip_next, size: 28),
            label: const Text('Passer le repos', style: TextStyle(fontSize: 20)),
          ),
        ),
      ],
    );
  }
}
