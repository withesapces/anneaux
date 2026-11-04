import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup.dart';
import 'device_files.dart';
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
  static const _kAutoAt = 'auto_backup_at_v1';
  static const _kAutoErr = 'auto_backup_err_v1';

  late SharedPreferences _p;

  List<Session> sessions = [];
  List<ExerciseDef> routine = [];
  int restSeconds = 120;
  bool sound = true;
  bool healthEnabled = false;
  double weightKg = 71;
  bool sendCalories = true;
  WorkoutDraft? draft;

  /// Dernière sauvegarde automatique réussie, et dernière erreur éventuelle.
  DateTime? autoBackupAt;
  String? autoBackupError;
  Timer? _autoTimer;

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
    final rawAt = _p.getString(_kAutoAt);
    autoBackupAt = rawAt == null ? null : DateTime.tryParse(rawAt);
    autoBackupError = _p.getString(_kAutoErr);
    // Première ouverture de cette version : on sauvegarde tout de suite ce qui existe.
    if (autoBackupAt == null) _scheduleAutoBackup();
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
      _scheduleAutoBackup();
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
    _scheduleAutoBackup();
    notifyListeners();
  }

  Future<void> updateSession(Session s) async {
    _sort();
    await _saveSessions();
    _scheduleAutoBackup();
    notifyListeners();
  }

  // ---------- Programme et réglages ----------

  Future<void> setRoutine(List<ExerciseDef> r) async {
    routine = r;
    await _saveRoutine();
    _scheduleAutoBackup();
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

  /// Efface l'historique, la séance en cours et remet le programme par défaut.
  /// L'historique pré-rempli n'est pas réinjecté (la clé des séances reste présente, vide).
  Future<void> wipeAll() async {
    sessions = [];
    routine = defaultRoutine();
    draft = null;
    await _saveSessions();
    await _saveRoutine();
    await saveDraft();
    notifyListeners();
  }

  // ---------- Sauvegarde ----------

  String exportJson() => const JsonEncoder.withIndent(' ').convert({
        'version': 1,
        'restSeconds': restSeconds,
        'routine': routine.map((r) => r.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      });

  /// Séances de la sauvegarde absentes de l'historique actuel (même identifiant = même séance).
  List<Session> missingFrom(Backup b) {
    final known = sessions.map((s) => s.id).toSet();
    return b.sessions.where((s) => !known.contains(s.id)).toList();
  }

  /// Ajoute les séances manquantes de la sauvegarde, sans rien supprimer.
  /// Le programme et le temps de repos sont repris s'ils figurent dans la sauvegarde.
  /// Renvoie le nombre de séances ajoutées.
  Future<int> applyBackup(Backup b) async {
    final added = missingFrom(b);
    sessions.addAll(added);
    if (b.routine != null && b.routine!.isNotEmpty) routine = b.routine!;
    restSeconds = b.restSeconds ?? restSeconds;
    _sort();
    await _saveSessions();
    await _saveRoutine();
    await _p.setInt(_kRest, restSeconds);
    _scheduleAutoBackup();
    notifyListeners();
    return added.length;
  }

  /// Lit puis applique une sauvegarde. Lève [BackupException] si le texte est inutilisable.
  Future<int> importJson(String raw) => applyBackup(parseBackup(raw));

  // ---------- Sauvegarde automatique ----------

  /// Regroupe les modifications rapprochées (édition série par série) en une seule écriture.
  void _scheduleAutoBackup() {
    _autoTimer?.cancel();
    _autoTimer = Timer(const Duration(seconds: 2), () => autoBackupNow());
  }

  /// Rien de personnel à sauvegarder : historique vide ou seulement l'historique pré-rempli.
  /// Évite d'écraser le fichier du jour avec des données vides après un effacement.
  bool get _nothingToBackup =>
      sessions.isEmpty || sessions.every((s) => s.id.startsWith('seed-'));

  static String backupFileName(DateTime d) =>
      'anneaux-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';

  /// Écrit la sauvegarde du jour dans Téléchargements/Anneaux (un fichier par jour,
  /// remplacé dans la journée). Renvoie null si OK, sinon le message d'erreur.
  Future<String?> autoBackupNow({bool force = false}) async {
    _autoTimer?.cancel();
    if (!force && _nothingToBackup) return null;
    final now = DateTime.now();
    try {
      await DeviceFiles.save(backupFileName(now), exportJson());
      autoBackupAt = now;
      autoBackupError = null;
      await _p.setString(_kAutoAt, now.toIso8601String());
      await _p.remove(_kAutoErr);
    } catch (e) {
      autoBackupError = e is PlatformException ? (e.message ?? e.code) : e.toString();
      await _p.setString(_kAutoErr, autoBackupError!);
    }
    notifyListeners();
    return autoBackupError;
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
