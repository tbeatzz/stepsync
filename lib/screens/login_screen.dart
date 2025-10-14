import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Pantalla de Login (en desarrollo)',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}
