import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  /// --- Sign In with Google
  Future<void> _signInWithGoogle() async {
    try {
      setState(() {
        _loadingGoogle = true;
        _error = null;
      });

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loadingGoogle = false);
        return; // user canceled
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(HomePage.route);
      }
    } catch (e) {
      setState(() => _error = "Google Sign-In failed: $e");
    } finally {
      setState(() => _loadingGoogle = false);
    }
  }

  /// --- Sign In with Email
  Future<void> _signInWithEmail(AuthRepository auth) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loadingEmail = true;
      _error = null;
    });

    final err = await auth.login(
      email: _email.text.trim(),
      password: _password.text,
    );

    setState(() {
      _loadingEmail = false;
      _error = err;
    });

    if (err == null && mounted) {
      Navigator.of(context).pushReplacementNamed(HomePage.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Email field
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter email';
                      if (!v.contains('@')) return 'Enter valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // --- Password field
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) => (v == null || v.length < 4)
                        ? 'Minimum 4 characters'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // --- Error message
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // --- Email login button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _loadingEmail ? null : () => _signInWithEmail(auth),
                      child: Text(_loadingEmail ? 'Signing in...' : 'Sign In'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // --- Google Sign-In button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: Image.asset(
                        'assets/google_logo.png',
                        height: 24,
                        errorBuilder: (_, __, ___) => const Icon(Icons.login),
                      ),
                      label: Text(_loadingGoogle
                          ? "Signing in..."
                          : "Sign in with Google"),
                      onPressed: _loadingGoogle ? null : _signInWithGoogle,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // --- Signup link
                  TextButton(
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed(SignupPage.route),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
