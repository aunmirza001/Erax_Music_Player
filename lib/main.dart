import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'core/audio/audio_player_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/signup_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'firebase_options.dart';

Future<void> _initFirebase() async {
  try {
    if (kIsWeb) {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      }
      return;
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
  }
}

Future<void> _initAudioBackground() async {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.example.erax.channel.audio',
        androidNotificationChannelName: 'Erax Music Playback',
        androidNotificationOngoing: true,
      );
    } catch (_) {}
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  await _initAudioBackground();
  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(
            create: (_) => AuthRepository(FirebaseAuth.instance)),
        ChangeNotifierProvider(create: (_) => AudioPlayerService()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
            darkTheme:
                ThemeData(useMaterial3: true, brightness: Brightness.dark),
            initialRoute: '/',
            routes: {
              '/': (_) => const _Gate(),
              LoginPage.route: (_) => const LoginPage(),
              SignupPage.route: (_) => const SignupPage(),
              HomePage.route: (_) => const HomePage(),
            },
          );
        },
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return const Scaffold(
              body: Center(child: Text("Firebase initialization failed")));
        }
        if (snap.data == null) {
          return const LoginPage();
        }
        return const HomePage();
      },
    );
  }
}
