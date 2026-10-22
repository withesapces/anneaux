import 'package:flutter/material.dart';

import '../format.dart';

/// Gros compteur − / + pour les reps ou les secondes, pensé pour être utilisé en sueur.
class BigCounter extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final String suffix;
  final int step;

  const BigCounter({
    super.key,
    required this.value,
    required this.onChanged,
    this.suffix = '',
    this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(
          icon: Icons.remove,
          onTap: value - step >= 0 ? () => onChanged(value - step) : null,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _edit(context),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value$suffix',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 88,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        _RoundButton(icon: Icons.add, onTap: () => onChanged(value + step)),
      ],
    );
  }

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: '$value');
    final v = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Valeur'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(c, int.tryParse(ctrl.text.trim())),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (v != null && v >= 0) onChanged(v);
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: IconButton.filledTonal(
        onPressed: onTap,
        icon: Icon(icon, size: 36),
      ),
    );
  }
}

/// Réglage de la hauteur de sangle, par pas de 0,5.
class HeightStepper extends StatelessWidget {
  final double? value;
  final ValueChanged<double?> onChanged;

  const HeightStepper({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: v == null || v <= 0 ? null : () => onChanged(v - 0.5),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: v == null ? () => onChanged(5) : null,
          onLongPress: v == null ? null : () => onChanged(null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              v == null ? 'Hauteur : —' : 'Hauteur ${fmtHeight(v)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          onPressed: () => onChanged((v ?? 4.5) + 0.5),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
