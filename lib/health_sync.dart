import 'package:health/health.dart';

import 'calories.dart';
import 'models.dart';

/// Envoi des séances vers Health Connect, que Samsung Health synchronise ensuite.
class HealthSync {
  static final Health _health = Health();
  static bool _configured = false;

  static const _types = [
    HealthDataType.WORKOUT,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];
  static const _perms = [
    HealthDataAccess.WRITE,
    HealthDataAccess.WRITE,
    HealthDataAccess.WRITE,
  ];

  static Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Demande l'autorisation d'écrire des exercices. Renvoie true si accordée.
  static Future<bool> authorize() async {
    try {
      await _configure();
      return await _health.requestAuthorization(_types, permissions: _perms);
    } catch (_) {
      return false;
    }
  }

  /// Écrit la séance comme un entraînement de musculation.
  /// Renvoie null si OK, sinon un message d'erreur lisible.
  static Future<String?> writeSession(Session s, {double? weightKg}) async {
    try {
      await _configure();
      final ok = await _health.requestAuthorization(_types, permissions: _perms);
      if (!ok) return 'Autorisation Health Connect refusée.';
      final end = s.end ?? s.date.add(const Duration(hours: 1));
      final written = await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
        start: s.date,
        end: end.isAfter(s.date) ? end : s.date.add(const Duration(minutes: 1)),
        title: 'Anneaux · ${s.totalSets} séries',
        totalEnergyBurned: weightKg == null ? null : estimateKcal(s, weightKg),
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      );
      return written ? null : 'Health Connect a refusé l\'enregistrement.';
    } catch (e) {
      return 'Health Connect indisponible : $e';
    }
  }
}
