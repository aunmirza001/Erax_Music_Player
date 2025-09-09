import 'package:flutter/foundation.dart';
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

  bool get _googleSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login(AuthRepository auth) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loadingEmail = true;
      _error = null;
    });
    final err = await auth.signInWithEmail(_email.text.trim(), _password.text);
    if (mounted) {
      setState(() => _loadingEmail = false);
      if (err != null) {
        setState(() => _error = err);
      } else {
        Navigator.pushReplacementNamed(context, HomePage.route);
      }
    }
  }

  Future<void> _loginWithGoogle(AuthRepository auth) async {
    if (!_googleSupported) {
      setState(() => _error = 'Google Sign-In not supported on this platform');
      return;
    }
    setState(() {
      _loadingGoogle = true;
      _error = null;
    });
    final err = await auth.signInWithGoogle();
    if (mounted) {
      setState(() => _loadingGoogle = false);
      if (err != null) {
        setState(() => _error = err);
      } else {
        Navigator.pushReplacementNamed(context, HomePage.route);
      }
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
                    const Text(
                      "ERAX",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Welcome Back!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                    const Text(
                      "Listen Your Favourite Music",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _email,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? "Enter your email"
                          : null,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "E-mail",
                        hintStyle: const TextStyle(color: Colors.white70),
                        prefixIcon:
                            const Icon(Icons.email, color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.2),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      validator: (v) =>
                          v == null || v.isEmpty ? "Enter your password" : null,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Password",
                        hintStyle: const TextStyle(color: Colors.white70),
                        prefixIcon:
                            const Icon(Icons.lock, color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.2),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text("Forgot password?",
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_error != null)
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loadingEmail ? null : () => _login(auth),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF303030),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(14),
                      ),
                      child: _loadingEmail
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text("Log In",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 16),
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
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text("or",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color.fromARGB(177, 255, 255, 255))),
                    const SizedBox(height: 12),
                    if (_googleSupported)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _loadingGoogle
                                ? null
                                : () => _loginWithGoogle(auth),
                            icon: const Icon(Icons.g_mobiledata,
                                color: Colors.white, size: 36),
                          ),
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
}
