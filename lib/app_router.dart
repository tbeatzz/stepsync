import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/session_screen.dart'; // 👈 Nueva pantalla

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/session',
      builder: (context, state) {
        final mode = state.extra as String; // recibe el modo
        return SessionScreen(mode: mode);
      },
    ),
  ],
);
