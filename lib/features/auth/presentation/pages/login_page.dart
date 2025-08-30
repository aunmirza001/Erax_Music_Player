import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../home/presentation/pages/home_page.dart';
import '../../data/repositories/auth_repository.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  static const route = '/login';
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loadingEmail = false;
  bool _loadingGoogle = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login(AuthRepository auth) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loadingEmail = true);
    try {
      final error = await auth.login(
        email: _email.text,
        password: _password.text,
      );
      if (error != null) {
        setState(() => _error = error);
      } else {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, HomePage.route);
      }
    } finally {
      setState(() => _loadingEmail = false);
    }
  }

  Future<void> _loginWithGoogle(AuthRepository auth) async {
    setState(() => _loadingGoogle = true);
    try {
      final error = await auth.signInWithGoogle();
      if (error != null) {
        setState(() => _error = error);
      } else {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, HomePage.route);
      }
    } finally {
      setState(() => _loadingGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthRepository>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset("assets/bg.jpg", fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.6)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("ERAX",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text("Welcome Back!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    const Text("Listen Your Favourite Music",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 14)),
                    const SizedBox(height: 32),

                    // Email
                    TextFormField(
                      controller: _email,
                      validator: (v) => v!.isEmpty ? "Enter your email" : null,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("E-mail", Icons.email),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      validator: (v) =>
                          v!.isEmpty ? "Enter your password" : null,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Password", Icons.lock),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: () {},
                          child: const Text("Forgot password?",
                              style: TextStyle(color: Colors.white70))),
                    ),
                    const SizedBox(height: 16),

                    if (_error != null)
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),

                    // Login button
                    ElevatedButton(
                      onPressed: _loadingEmail ? null : () => _login(auth),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 48, 48, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(14)),
                      child: _loadingEmail
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Log In",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 16),

                    // Signup link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don’t have an account?",
                            style: TextStyle(
                                color: Color.fromARGB(179, 255, 255, 255))),
                        TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, SignupPage.route),
                            child: const Text("Signup",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)))
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Social login
                    const Text("or",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color.fromARGB(177, 255, 255, 255))),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                            onPressed: () => _loginWithGoogle(auth),
                            icon: const Icon(Icons.g_mobiledata,
                                color: Colors.white, size: 36)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.2),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
