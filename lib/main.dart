import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'core/audio/audio_player_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/library/data/library_repository.dart';
import 'my_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔑 MUST be awaited BEFORE any AudioPlayer is created
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.erax.audio',
    androidNotificationChannelName: 'Erax Playback',
    androidNotificationOngoing: true,
  );

  final theme = await ThemeController.init();
  final library = await LibraryRepository.init();
  final auth = await AuthRepository.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(
            create: (_) => AudioPlayerService()), // safe here
      ],
      child: const MyApp(),
    ),
  );
}
