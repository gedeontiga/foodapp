import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../main_navigation.dart';
import '../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String email = _emailController.text;
      String password = _passwordController.text;

      bool isLogin = await _apiService.login(email, password);
      setState(() {
        _isLoading = false;
      });

      if (isLogin) {
        Fluttertoast.showToast(msg: "Connexion réussie");
        if (mounted) {
          // Replace the entire navigation stack with MainNavigation
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const MainNavigation(initialIndex: 0), // 0 is for chat tab
            ),
          );
        }
      } else {
        Fluttertoast.showToast(msg: "Email ou mot de passe invalide");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un mot de passe';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                      ),
                      child: const Text(
                        'Se connecter',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (!_isLoading) {
                    Navigator.pushNamed(context, '/register');
                  }
                },
                child: const Text('Créer un compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
