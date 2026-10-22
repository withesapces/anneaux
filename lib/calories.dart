import 'models.dart';

/// MET du Compendium of Physical Activities pour un circuit de renforcement
/// musculaire (8-15 reps, plusieurs exercices), repos compris.
const double resistanceMet = 3.5;

/// Estimation : MET × poids (kg) × durée (h). Null si la durée est inconnue.
int? estimateKcal(Session s, double weightKg) {
  final end = s.end;
  if (end == null || !end.isAfter(s.date)) return null;
  final hours = end.difference(s.date).inSeconds / 3600;
  return (resistanceMet * weightKg * hours).round();
}
