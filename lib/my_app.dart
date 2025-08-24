import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/signup_page.dart';
import 'features/home/presentation/pages/home_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      title: 'Erex Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeController.isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: LoginPage.route,
      routes: {
        LoginPage.route: (_) => const LoginPage(),
        SignupPage.route: (_) => const SignupPage(),
        HomePage.route: (_) => const HomePage(),
      },
    );
  }
}
