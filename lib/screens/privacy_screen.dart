import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/ui.dart';

/// Confidentialité, expliquée par Maître Magnésie.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  Future<void> _wipe() async {
    final store = StoreScope.read(context);
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const D('Tout effacer ?', size: 30, w: FontWeight.w900),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              'Toutes tes séances, ton programme et la séance en cours seront supprimés de ce téléphone. '
              'Impossible de revenir en arrière.\n\nExporte une sauvegarde avant si tu veux la garder.\n\n'
              'Tape EFFACER pour confirmer.',
              style: body(14, color: C.muted, height: 1.4)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.characters),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ANNULER')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5A4E)),
            onPressed: () => Navigator.pop(c, ctrl.text.trim().toUpperCase() == 'EFFACER'),
            child: const Text('EFFACER'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.wipeAll();
    if (mounted) {
      toast(context, 'Données effacées.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.smartphone_rounded, 'Tout reste sur ton téléphone',
          'Séances, programme, réglages. Pas de compte, pas de serveur, pas de pub, pas de pisteur.'),
      (Icons.favorite_border_rounded, 'Samsung Health, seulement si tu l\'actives',
          'Durée et calories estimées. Ton poids sert au calcul et reste ici. Désactivable à tout moment.'),
      (Icons.copy_rounded, 'Export quand tu veux',
          'Une copie complète de tes données dans le presse-papiers, en texte lisible.'),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  const Row(children: [
                    BackLink('Réglages'),
                    Spacer(),
                    Lbl('Confidentialité · RGPD', size: 14),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    AnimatedBuilder(
                      animation: _float,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, -6 * Curves.easeInOut.transform(_float.value)),
                        child: child,
                      ),
                      child: const MageArt(width: 170),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        D('Maître\nMagnésie', size: 46, w: FontWeight.w900, height: 0.92),
                        SizedBox(height: 8),
                        D('Gardien de tes données', size: 16, w: FontWeight.w700, ls: 0.08, color: C.accent),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  const D('« Rien ne quitte ce téléphone sans ton accord. Parole de mage. »',
                      size: 32, w: FontWeight.w800, height: 1.05),
                  const SizedBox(height: 14),
                  for (final it in items)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.surface2))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(it.$1, color: C.accent, size: 28),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(it.$2, style: body(16, w: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(it.$3, style: body(14, color: C.muted, height: 1.4)),
                          ]),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(children: [
                BigButton('C\'est clair, on s\'entraîne',
                    height: 80, fontSize: 32, onTap: () => Navigator.pop(context)),
                TextButton(
                  onPressed: _wipe,
                  child: Text('Effacer toutes mes données',
                      style: body(14, color: C.muted, w: FontWeight.w600)
                          .copyWith(decoration: TextDecoration.underline)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
