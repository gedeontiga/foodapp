import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../services/api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String name = _nameController.text;
      String email = _emailController.text;
      String password = _passwordController.text;

      bool isRegistered = await _apiService.signup(name, email, password);

      setState(() {
        _isLoading = false;
      });

      if (isRegistered) {
        Fluttertoast.showToast(msg: "Inscription réussie");
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        Fluttertoast.showToast(
          msg: "Échec de l'inscription. Veuillez réessayer.",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un nom';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un email';
                      }
                      if (!value.contains('@')) {
                        return 'Veuillez entrer un email valide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un mot de passe';
                      }
                      if (value.length < 6) {
                        return 'Le mot de passe doit contenir au moins 6 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _register,
                            child: const Text(
                              'S\'inscrire',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      if (!_isLoading) {
                        Navigator.pushNamed(context, '/login');
                      }
                    },
                    child:
                        const Text('Vous avez déjà un compte ? Connectez-vous'),
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
