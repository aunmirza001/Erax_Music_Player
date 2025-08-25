import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../home/presentation/pages/home_page.dart';
import '../../data/repositories/auth_repository.dart'; // ✅ fixed path
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
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
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
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 12),
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
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) => (v == null || v.length < 4)
                        ? 'Minimum 4 characters'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              final err = await auth.signup(
                                name: _name.text.trim(),
                                email: _email.text.trim(),
                                password: _password.text,
                              );
                              setState(() {
                                _loading = false;
                                _error = err;
                              });
                              if (err == null && mounted) {
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed(HomePage.route);
                              }
                            },
                      child: Text(_loading ? 'Creating account...' : 'Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushReplacementNamed(LoginPage.route),
                    child: const Text('Already have an account? Sign in'),
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
