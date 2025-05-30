import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../services/api_service.dart';
import '../widgets/widget_text.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.8, end: 1.2)
        .chain(CurveTween(curve: Curves.elasticInOut))
        .animate(_controller);

    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    if (await ApiService.isLoggedIn()) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleWelcomePress() async {
    bool isLoggedIn = await ApiService.isLoggedIn();
    if (mounted) {
      if (isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        Fluttertoast.showToast(msg: "Veuillez vous connecter");
        Navigator.pushNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _animation,
              child: const GradientText(
                'Hello World',
                gradient: LinearGradient(
                  colors: [Colors.red, Color.fromARGB(255, 0, 29, 255)],
                ),
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _handleWelcomePress,
              child: const Text('Welcome', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
