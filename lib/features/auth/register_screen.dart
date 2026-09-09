import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _name.text.trim();
    final company = _company.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (name.isEmpty || company.isEmpty || email.isEmpty) {
      setState(() => _error = 'Lütfen tüm alanları doldurun.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Geçerli bir e-posta girin.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Şifre en az 6 karakter olmalı.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      await cred.user!.updateDisplayName(name);

      await ref.read(userRepositoryProvider).createProfile(
            uid: uid,
            email: email,
            displayName: name,
            companyName: company,
          );
      await ref.read(workspaceRepositoryProvider).createWorkspaceForUser(
            uid: uid,
            name: company,
            email: email,
            displayName: name,
          );

      if (mounted) {
        // AuthGate (home) profili/workspace'i görünce asıl uygulamayı açar.
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          'email-already-in-use' =>
            'Bu e-posta zaten kayıtlı. Giriş yapmayı deneyin.',
          'invalid-email' => 'E-posta adresi geçersiz.',
          'weak-password' => 'Şifre çok zayıf (en az 6 karakter).',
          'operation-not-allowed' || 'configuration-not-found' =>
            'Firebase Console → Authentication → Sign-in method bölümünden '
                'E-posta/Şifre kaydını etkinleştirin.',
          _ => e.message ?? 'Kayıt yapılamadı.',
        };
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Kayıt hatası: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF12151E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E2333)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset('assets/logo.png',
                          width: 64, height: 64, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Hesap Oluştur',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Şirketiniz için Bitronix Stock çalışma alanı açın',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  _field(_name, 'Ad Soyad', Icons.badge_outlined),
                  const SizedBox(height: 12),
                  _field(_company, 'Şirket / Organizasyon',
                      Icons.apartment_rounded),
                  const SizedBox(height: 12),
                  _field(_email, 'E-posta', Icons.mail_outline_rounded,
                      keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _field(_password, 'Şifre (en az 6 karakter)',
                      Icons.lock_outline_rounded,
                      obscure: true),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _busy ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF58220),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Kayıt Ol',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        _busy ? null : () => Navigator.of(context).maybePop(),
                    child: const Text(
                      'Zaten hesabım var — Giriş Yap',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
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

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
        filled: true,
        fillColor: const Color(0xFF0B0D12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF262C3D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF262C3D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF58220)),
        ),
      ),
    );
  }
}
