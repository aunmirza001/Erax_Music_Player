import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'core/audio/audio_player_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/library/data/library_repository.dart'; // ✅ import here
import 'my_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.erax.audio',
    androidNotificationChannelName: 'Erax Playback',
    androidNotificationOngoing: true,
  );

  final themeCtrl = await ThemeController.init();
  final authRepo = await AuthRepository.init();
  final libraryRepo = await LibraryRepository.init(); // ✅ new

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeCtrl),
        ChangeNotifierProvider(create: (_) => authRepo),
        ChangeNotifierProvider(create: (_) => AudioPlayerService()),
        ChangeNotifierProvider(create: (_) => libraryRepo), // ✅ fixed
      ],
      child: const MyApp(),
    ),
  );
}
