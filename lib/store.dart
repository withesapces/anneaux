import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'seed.dart';

/// Tout l'état de l'app, stocké en local sur le téléphone (aucun compte, aucun serveur).
class AppStore extends ChangeNotifier {
  static const _kSessions = 'sessions_v1';
  static const _kRoutine = 'routine_v1';
  static const _kRest = 'rest_seconds_v1';
  static const _kDraft = 'draft_v1';
  static const _kSound = 'sound_v1';
  static const _kHealth = 'health_v1';
  static const _kWeight = 'weight_v1';
  static const _kKcal = 'kcal_v1';

  late SharedPreferences _p;

  List<Session> sessions = [];
  List<ExerciseDef> routine = [];
  int restSeconds = 120;
  bool sound = true;
  bool healthEnabled = false;
  double weightKg = 71;
  bool sendCalories = true;
  WorkoutDraft? draft;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final rawSessions = _p.getString(_kSessions);
    if (rawSessions == null) {
      // Premier lancement : on reprend l'historique des notes.
      sessions = seedSessions();
      routine = defaultRoutine();
      await _saveSessions();
      await _saveRoutine();
    } else {
      sessions = (jsonDecode(rawSessions) as List)
          .map((e) => Session.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final rawRoutine = _p.getString(_kRoutine);
      routine = rawRoutine == null
          ? defaultRoutine()
          : (jsonDecode(rawRoutine) as List)
              .map((e) => ExerciseDef.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
    }
    _sort();
    restSeconds = _p.getInt(_kRest) ?? 120;
    sound = _p.getBool(_kSound) ?? true;
    healthEnabled = _p.getBool(_kHealth) ?? false;
    weightKg = _p.getDouble(_kWeight) ?? 71;
    sendCalories = _p.getBool(_kKcal) ?? true;
    final rawDraft = _p.getString(_kDraft);
    if (rawDraft != null) {
      try {
        draft = WorkoutDraft.fromJson(
            Map<String, dynamic>.from(jsonDecode(rawDraft) as Map));
      } catch (_) {
        draft = null;
      }
    }
  }

  void _sort() => sessions.sort((a, b) => b.date.compareTo(a.date));

  Future<void> _saveSessions() => _p.setString(
      _kSessions, jsonEncode(sessions.map((s) => s.toJson()).toList()));

  Future<void> _saveRoutine() => _p.setString(
      _kRoutine, jsonEncode(routine.map((r) => r.toJson()).toList()));

  // ---------- Recherche ----------

  bool _same(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  /// Dernière fois que cet exercice a été fait (hors séance en cours).
  ExerciseLog? lastLogFor(String name) {
    for (final s in sessions) {
      for (final e in s.exercises) {
        if (_same(e.name, name) && e.sets.isNotEmpty) return e;
      }
    }
    return null;
  }

  ExerciseDef? defFor(String name) {
    for (final d in [...routine, ...extraLibrary()]) {
      if (_same(d.name, name)) return d;
    }
    return null;
  }

  /// Tous les noms d'exercices connus (programme + historique).
  List<String> allExerciseNames() {
    final names = <String>[];
    void add(String n) {
      if (!names.any((x) => _same(x, n))) names.add(n);
    }

    for (final r in routine) {
      add(r.name);
    }
    for (final s in sessions) {
      for (final e in s.exercises) {
        add(e.name);
      }
    }
    return names;
  }

  /// Historique d'un exercice, du plus ancien au plus récent.
  List<(DateTime, ExerciseLog)> historyFor(String name) {
    final out = <(DateTime, ExerciseLog)>[];
    for (final s in sessions.reversed) {
      for (final e in s.exercises) {
        if (_same(e.name, name) && e.sets.isNotEmpty) out.add((s.date, e));
      }
    }
    return out;
  }

  // ---------- Séance en cours ----------

  WorkoutDraft startWorkout() {
    final now = DateTime.now();
    draft = WorkoutDraft(
      session: Session(
        id: now.microsecondsSinceEpoch.toString(),
        date: now,
        exercises: routine
            .map((r) => ExerciseLog(name: r.name, unit: r.unit, perSide: r.perSide))
            .toList(),
      ),
    );
    saveDraft();
    notifyListeners();
    return draft!;
  }

  Future<void> saveDraft() async {
    if (draft == null) {
      await _p.remove(_kDraft);
    } else {
      await _p.setString(_kDraft, jsonEncode(draft!.toJson()));
    }
  }

  Future<void> discardDraft() async {
    draft = null;
    await saveDraft();
    notifyListeners();
  }

  /// Enregistre la séance en cours dans l'historique.
  Future<Session?> finishWorkout() async {
    final d = draft;
    if (d == null) return null;
    d.session.exercises.removeWhere((e) => e.sets.isEmpty);
    d.session.end = DateTime.now();
    // Les hauteurs utilisées deviennent les hauteurs par défaut du programme.
    for (final e in d.session.exercises) {
      final def = routine.where((r) => _same(r.name, e.name));
      if (def.isNotEmpty && e.sets.last.height != null) {
        def.first.height = e.sets.last.height;
      }
    }
    if (d.session.exercises.isNotEmpty) {
      sessions.add(d.session);
      _sort();
      await _saveSessions();
      await _saveRoutine();
    }
    draft = null;
    await saveDraft();
    notifyListeners();
    return d.session.exercises.isEmpty ? null : d.session;
  }

  // ---------- Historique ----------

  Future<void> deleteSession(Session s) async {
    sessions.removeWhere((x) => x.id == s.id);
    await _saveSessions();
    notifyListeners();
  }

  Future<void> updateSession(Session s) async {
    _sort();
    await _saveSessions();
    notifyListeners();
  }

  // ---------- Programme et réglages ----------

  Future<void> setRoutine(List<ExerciseDef> r) async {
    routine = r;
    await _saveRoutine();
    notifyListeners();
  }

  Future<void> setRest(int s) async {
    restSeconds = s;
    await _p.setInt(_kRest, s);
    notifyListeners();
  }

  Future<void> setHealth(bool v) async {
    healthEnabled = v;
    await _p.setBool(_kHealth, v);
    notifyListeners();
  }

  Future<void> setWeight(double kg) async {
    weightKg = kg;
    await _p.setDouble(_kWeight, kg);
    notifyListeners();
  }

  Future<void> setSendCalories(bool v) async {
    sendCalories = v;
    await _p.setBool(_kKcal, v);
    notifyListeners();
  }

  Future<void> markHealthSynced(Session s) async {
    s.healthSynced = true;
    await _saveSessions();
    notifyListeners();
  }

  Future<void> setSound(bool v) async {
    sound = v;
    await _p.setBool(_kSound, v);
    notifyListeners();
  }

  // ---------- Sauvegarde ----------

  String exportJson() => const JsonEncoder.withIndent(' ').convert({
        'version': 1,
        'restSeconds': restSeconds,
        'routine': routine.map((r) => r.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      });

  /// Remplace les données par une sauvegarde. Lève une exception si le texte est invalide.
  Future<void> importJson(String raw) async {
    final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final newSessions = (j['sessions'] as List)
        .map((e) => Session.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final newRoutine = (j['routine'] as List)
        .map((e) => ExerciseDef.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    sessions = newSessions;
    routine = newRoutine;
    restSeconds = (j['restSeconds'] as num?)?.toInt() ?? restSeconds;
    _sort();
    await _saveSessions();
    await _saveRoutine();
    await _p.setInt(_kRest, restSeconds);
    notifyListeners();
  }
}

/// Rend le store accessible partout dans l'arbre de widgets.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
