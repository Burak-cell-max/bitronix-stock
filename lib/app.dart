import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/desktop_shell.dart';
import 'features/dashboard/mobile_shell.dart';
import 'features/onboarding/create_workspace_screen.dart';

final authUserProvider = StreamProvider<User?>(
  (_) => FirebaseAuth.instance.authStateChanges(),
);

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

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Oturum açıldığında son giriş zamanını güncelle.
    ref.listen(authUserProvider, (prev, next) {
      final uid = next.asData?.value?.uid;
      if (uid != null) {
        ref.read(userRepositoryProvider).touchLastLogin(uid).catchError((_) {});
      }
    });

    final auth = ref.watch(authUserProvider);

    return auth.when(
      loading: () => const _Splash(),
      error: (e, _) => _ErrorScreen('Oturum hatası: $e'),
      data: (user) {
        if (user == null) return const LoginScreen();

        final profileAsync = ref.watch(currentUserProfileProvider);
        return profileAsync.when(
          loading: () => const _Splash(),
          error: (e, _) => _ErrorScreen('Profil yüklenemedi: $e'),
          data: (profile) {
            // Konsol'dan eklenmiş, henüz profili olmayan hesap.
            if (profile == null) {
              return const CreateWorkspaceScreen(needsProfile: true);
            }
            if (profile.isBlocked) {
              return _BlockedScreen(deleted: profile.isDeleted);
            }
            if (!profile.hasWorkspace) {
              return const CreateWorkspaceScreen();
            }
            return LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 700
                  ? const MobileShell()
                  : const DesktopShell(),
            );
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF58220)),
        ),
      );
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      );
}

class _BlockedScreen extends StatelessWidget {
  const _BlockedScreen({required this.deleted});
  final bool deleted;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(deleted ? Icons.no_accounts_rounded : Icons.block_rounded,
                      size: 44, color: const Color(0xFFEF4444)),
                  const SizedBox(height: 16),
                  Text(
                    deleted
                        ? 'Hesabınız kapatıldı'
                        : 'Hesabınız pasif durumda',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    deleted
                        ? 'Bu hesap bir yönetici tarafından kapatıldı. '
                            'Yeniden açılması için Bitronix ile iletişime geçin.'
                        : 'Erişiminiz bir yönetici tarafından geçici olarak '
                            'durduruldu. Destek için Bitronix ile iletişime geçin.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Çıkış Yap',
                        style: TextStyle(color: Color(0xFFF58220))),
                  ),
                ],
              ),
            ),
          ),
        ),
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
