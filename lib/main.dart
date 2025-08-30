import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/audio/audio_player_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/signup_page.dart';
import 'features/home/presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final auth = await AuthRepository.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => auth),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => AudioPlayerService()), // ✅ FIX
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      title: 'Erax',
      theme: themeController.isDark ? ThemeData.dark() : ThemeData.light(),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const HomePage(); // ✅ logged in
          }
          return const LoginPage(); // ✅ login/signup first
        },
      ),
      routes: {
        LoginPage.route: (_) => const LoginPage(),
        SignupPage.route: (_) => const SignupPage(),
        HomePage.route: (_) => const HomePage(),
      },
    );
  }
}
