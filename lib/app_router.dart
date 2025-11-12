import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/session_screen.dart';
import 'screens/game_screen.dart';


// Servicios
import 'services/step_service_fft.dart';

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
        final mode = state.extra as String;
        return SessionScreen(mode: mode);
      },
    ),
    GoRoute(
      path: '/game',
      builder: (context, state) {
        // vamos a esperar que .extra sea un map con todos los datos
        final data = state.extra as Map<String, dynamic>;

        final int initialBpm = data['initialBpm'] as int;
        final int initialSteps = data['initialSteps'] as int;
        final StepServiceFFT stepService = data['stepService'] as StepServiceFFT;

        return GameScreen(
          initialBpm: initialBpm,
          initialSteps: initialSteps,
          stepService: stepService,
        );
      },
    ),



  ],
);
