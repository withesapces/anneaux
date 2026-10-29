import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/height_control.dart';
import '../widgets/ui.dart';
import 'settings_screen.dart';

class EditorResult {
  final ExerciseDef? def;
  final bool delete;
  const EditorResult.save(this.def) : delete = false;
  const EditorResult.delete()
      : def = null,
        delete = true;
}

/// Création / modification d'un exercice du programme.
class ExerciseEditorScreen extends StatefulWidget {
  final ExerciseDef? initial;
  const ExerciseEditorScreen({super.key, this.initial});

  @override
  State<ExerciseEditorScreen> createState() => _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends State<ExerciseEditorScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.initial?.name ?? '');
  late Unit _unit = widget.initial?.unit ?? Unit.reps;
  late bool _perSide = widget.initial?.perSide ?? false;
  late double? _height = widget.initial == null ? 5 : widget.initial!.height;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final n = _name.text.trim();
    if (n.isEmpty) {
      toast(context, 'Donne un nom à l\'exercice.');
      return;
    }
    Navigator.pop(
      context,
      EditorResult.save(ExerciseDef(name: n, unit: _unit, perSide: _perSide, height: _height)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  const Align(alignment: Alignment.centerLeft, child: BackLink('Programme')),
                  const SizedBox(height: 4),
                  D(editing ? 'Modifier\nl\'exercice' : 'Nouvel\nexercice',
                      size: 52, w: FontWeight.w900, height: 0.95),
                  const SizedBox(height: 18),
                  const Lbl('Nom', size: 14),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    style: disp(28),
                    decoration: InputDecoration(
                      hintText: 'Ex : Pull ups',
                      hintStyle: disp(28, color: C.faint),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Lbl('Unité', size: 14),
                  const SizedBox(height: 8),
                  Segmented(
                    labels: const ['Reps', 'Secondes'],
                    index: _unit == Unit.reps ? 0 : 1,
                    onChanged: (i) => setState(() => _unit = i == 0 ? Unit.reps : Unit.seconds),
                  ),
                  const SizedBox(height: 12),
                  Panel(
                    padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
                    child: InkWell(
                      onTap: () => setState(() => _perSide = !_perSide),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Chaque côté', style: body(16, w: FontWeight.w600)),
                            Text('Affiche le badge et compte par côté',
                                style: body(13, color: C.muted)),
                          ]),
                        ),
                        Switch(value: _perSide, onChanged: (v) => setState(() => _perSide = v)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Lbl('Hauteur de sangle par défaut', size: 14),
                  const SizedBox(height: 10),
                  HeightControl(value: _height, onChanged: (v) => setState(() => _height = v)),
                  if (_height != null)
                    Center(
                      child: LinkButton('Sans hauteur',
                          size: 16, onTap: () => setState(() => _height = null)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(children: [
                BigButton('Enregistrer', height: 80, fontSize: 36, onTap: _save),
                if (editing)
                  TextButton(
                    onPressed: () async {
                      final ok = await confirmDialog(context, 'Retirer du programme ?',
                          'L\'exercice disparaît du programme. Son historique est gardé.',
                          yes: 'Retirer');
                      if (ok && context.mounted) {
                        Navigator.pop(context, const EditorResult.delete());
                      }
                    },
                    child: Text('Supprimer l\'exercice (l\'historique est gardé)',
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
