import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(AnneauxApp(store: store));
}

class AnneauxApp extends StatelessWidget {
  final AppStore store;
  const AnneauxApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE8833A),
      brightness: Brightness.dark,
    );
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Anneaux',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: scheme, useMaterial3: true),
        home: const HomeShell(),
      ),
    );
  }
}
