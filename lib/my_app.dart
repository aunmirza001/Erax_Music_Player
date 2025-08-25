import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/signup_page.dart';
import 'features/home/presentation/pages/home_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final auth = context.watch<AuthRepository>();

    return MaterialApp(
      title: 'ERAX',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.mode,
      debugShowCheckedModeBanner: false,
      home: auth.isLoggedIn ? const HomePage() : const LoginPage(),
      routes: {
        HomePage.route: (_) => const HomePage(),
        LoginPage.route: (_) => const LoginPage(),
        SignupPage.route: (_) => const SignupPage(),
      },
    );
  }
}