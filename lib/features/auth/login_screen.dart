import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/user_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'bitronix');
  final password = TextEditingController(text: 'bitronix2026');
  bool busy = false;
  String? error;

  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });

    var inputEmail = email.text.trim();
    if (!inputEmail.contains('@')) {
      inputEmail = '$inputEmail@bitronix.com';
    }

    final inputPassword = password.text;

    try {
      // 1. Giriş yapmayı dene
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: inputEmail,
        password: inputPassword,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        // Kullanıcı yoksa otomatik hesabı ve Firestore profilini oluştur
        try {
          final cred = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
            email: inputEmail,
            password: inputPassword,
          );
          if (cred.user != null) {
            await UserRepository(FirebaseFirestore.instance).upsertProfile(
              UserProfile(
                uid: cred.user!.uid,
                email: inputEmail,
                displayName: 'Bitronix Yönetici',
                role: UserRole.admin,
              ),
            );
          }
        } catch (createErr) {
          error = 'Giriş hatası: ${e.message}';
        }
      } else if (e.code == 'configuration-not-found' ||
          e.message?.contains('CONFIGURATION_NOT_FOUND') == true) {
        error =
            'Firebase Console\'da E-posta/Şifre girişi kapalı.\nLütfen Firebase Console -> Authentication -> Sign-in method sekmesinden E-posta/Şifre seçeneğini etkinleştirin.';
      } else {
        error = e.message ?? 'Giriş yapılamadı.';
      }
    } catch (e) {
      if (e.toString().contains('CONFIGURATION_NOT_FOUND')) {
        error =
            'Firebase Console\'da E-posta/Şifre girişi kapalı.\nLütfen Firebase Console -> Authentication -> Sign-in method sekmesinden E-posta/Şifre seçeneğini etkinleştirin.';
      } else {
        error = 'Giriş hatası: $e';
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B0D12),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E2333)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF58220)
                                  .withValues(alpha: 0.35),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset('assets/logo.png',
                              fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'BITRONIX STOCK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFF58220),
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Stok & Envanter Takip Sistemi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: email,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Kullanıcı Adı veya E-posta',
                        labelStyle:
                            const TextStyle(color: Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.person_outline_rounded,
                            color: Color(0xFF64748B), size: 18),
                        filled: true,
                        fillColor: const Color(0xFF0B0D12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF262C3D)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF262C3D)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFF58220)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        labelStyle:
                            const TextStyle(color: Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.lock_outline_rounded,
                            color: Color(0xFF64748B), size: 18),
                        filled: true,
                        fillColor: const Color(0xFF0B0D12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF262C3D)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF262C3D)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFF58220)),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 12)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: busy ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF58220),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Giriş Yap',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
