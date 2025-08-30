import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../home/presentation/pages/home_page.dart';
import '../../data/repositories/auth_repository.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  static const route = '/signup';
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _rePassword = TextEditingController();

  bool _loading = false;
  bool _agree = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _rePassword.dispose();
    super.dispose();
  }

  Future<void> _signup(AuthRepository auth) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      setState(() => _error = "You must agree to Terms & Conditions");
      return;
    }
    setState(() => _loading = true);
    try {
      final error = await auth.signup(
        name: _name.text, // ✅ FIXED: include name
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
      setState(() => _loading = false);
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
                    const Text("Create Account",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    const Text("Join and Listen Your Favourite Music",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 14)),
                    const SizedBox(height: 32),

                    // Username
                    TextFormField(
                      controller: _name,
                      validator: (v) => v!.isEmpty ? "Enter username" : null,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Username", Icons.person),
                    ),
                    const SizedBox(height: 16),

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
                    const SizedBox(height: 16),

                    // Re-Password
                    TextFormField(
                      controller: _rePassword,
                      obscureText: true,
                      validator: (v) =>
                          v != _password.text ? "Passwords do not match" : null,
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          _inputDecoration("Re-Password", Icons.lock_outline),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Checkbox(
                          value: _agree,
                          onChanged: (val) =>
                              setState(() => _agree = val ?? false),
                          checkColor: Colors.black,
                          activeColor: Colors.white,
                        ),
                        const Expanded(
                          child: Text("I agree with Terms & Conditions",
                              style: TextStyle(color: Colors.white70)),
                        )
                      ],
                    ),
                    if (_error != null)
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),

                    // Signup button
                    ElevatedButton(
                      onPressed: _loading ? null : () => _signup(auth),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(14)),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Sign Up",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?",
                            style: TextStyle(color: Colors.white70)),
                        TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, LoginPage.route),
                            child: const Text("Login",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)))
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
