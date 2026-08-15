import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/desktop_shell.dart';
import 'features/dashboard/mobile_shell.dart';

class BitronixApp extends StatelessWidget {
  const BitronixApp({super.key, required this.firebaseReady});
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Bitronix Stock',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          fontFamily: 'Segoe UI',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF58220),
            brightness: Brightness.dark,
            surface: const Color(0xFF12151E),
          ),
          scaffoldBackgroundColor: const Color(0xFF0B0D12),
          cardTheme: CardThemeData(
            color: const Color(0xFF12151E),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF1E2333)),
            ),
          ),
        ),
        home: !firebaseReady ? const FirebaseSetupScreen() : const AuthGate(),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFF58220)),
              ),
            );
          }

          final user = s.data;
          if (user == null) {
            return const LoginScreen();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700) {
                return const MobileShell();
              } else {
                return const DesktopShell();
              }
            },
          );
        },
      );
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: const Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_off_rounded,
                      size: 42, color: Color(0xFFF58220)),
                  SizedBox(height: 16),
                  Text(
                    'Firebase yapılandırması gerekli',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Firebase projenizi bağlamak için proje kökünde flutterfire configure çalıştırın.',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
