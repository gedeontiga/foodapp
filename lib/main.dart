import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'main_navigation.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat & Foods Agenda App',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.oswaldTextTheme(
          Theme.of(context).textTheme.copyWith(
                headlineSmall: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
                bodyMedium: const TextStyle(
                  color: Colors.black87,
                ),
              ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withAlpha((0.9 * 255).toInt()),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[900],
        textTheme: GoogleFonts.oswaldTextTheme(
          Theme.of(context).textTheme.copyWith(
                headlineSmall: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent,
                ),
                bodyMedium: const TextStyle(
                  color: Colors.white70,
                ),
              ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[800]!.withAlpha((0.9 * 255).toInt()),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        ),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/main': (context) => const MainNavigation(),
      },
    );
  }
}