import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/audio/audio_player_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/library/data/library_repository.dart';
import 'my_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize repositories/controllers
  final theme = await ThemeController.init();
  final library = await LibraryRepository.init();
  final auth = await AuthRepository.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => theme),
        ChangeNotifierProvider(create: (_) => library),
        ChangeNotifierProvider(create: (_) => auth),
        ChangeNotifierProvider(
            create: (_) => AudioPlayerService()), // ✅ correct
      ],
      child: const MyApp(),
    ),
  );
}
