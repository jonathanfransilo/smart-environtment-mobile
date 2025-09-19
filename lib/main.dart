import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';  // import splash
import 'screens/login_screen.dart';  // import login

void main() {
  runApp(const SirkularApp());
}

class SirkularApp extends StatelessWidget {
  const SirkularApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sirkular',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      initialRoute: '/', // rute awal
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
