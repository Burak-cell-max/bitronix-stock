import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../admin/migration_screen.dart';

/// Kullanıcının bir workspace'i yoksa gösterilir:
/// - [needsProfile] true ise önce `users/{uid}` profili oluşturulur (Console'dan
///   eklenip hiç profili olmayan hesaplar için),
/// - ardından bir workspace + admin üyeliği oluşturulur.
///
/// AuthGate, profil güncellenince otomatik olarak asıl uygulamaya geçer.
class CreateWorkspaceScreen extends ConsumerStatefulWidget {
  const CreateWorkspaceScreen({super.key, this.needsProfile = false});

  final bool needsProfile;

  @override
  ConsumerState<CreateWorkspaceScreen> createState() =>
      _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends ConsumerState<CreateWorkspaceScreen> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    _name.text = profile?.companyName ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Şirket / çalışma alanı adı gerekli.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final users = ref.read(userRepositoryProvider);
      if (widget.needsProfile) {
        await users.createProfile(
          uid: user.uid,
          email: user.email ?? '',
          displayName: (user.displayName?.trim().isNotEmpty ?? false)
              ? user.displayName!.trim()
              : (user.email ?? 'kullanici').split('@').first,
          companyName: name,
        );
      }
      await ref.read(workspaceRepositoryProvider).createWorkspaceForUser(
            uid: user.uid,
            name: name,
            email: user.email,
            displayName: user.displayName,
          );
      // AuthGate defaultWorkspaceId değişimini dinleyip otomatik yönlendirir.
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Oluşturulamadı: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin =
        ref.watch(currentUserProfileProvider).whenOrNull(data: (p) => p)?.isSuperAdmin ==
            true;
    final invites = ref.watch(myInvitesProvider).whenOrNull(data: (v) => v) ??
        const <WorkspaceInvite>[];
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (invites.isNotEmpty) _invitesCard(invites),
                Container(
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
                  const Icon(Icons.workspaces_rounded,
                      color: Color(0xFFF58220), size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    'Çalışma Alanı Oluştur',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Şirketiniz için izole bir stok alanı açılır. Stok, hareket ve '
                    'finans verileriniz yalnızca sizin ekibinize görünür.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _name,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Şirket / Çalışma Alanı Adı',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: Color(0xFF0B0D12),
                    ),
                    onSubmitted: (_) => _create(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _busy ? null : _create,
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
                        : const Text('Oluştur ve Devam Et',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (isSuperAdmin)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MigrationScreen(),
                        ),
                      ),
                      child: const Text('V1 → V2 Migrasyonu (superAdmin)',
                          style: TextStyle(color: Color(0xFFF58220))),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Çıkış Yap',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ),
                ],
              ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _invitesCard(List<WorkspaceInvite> invites) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF58220).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sizi bekleyen davetler',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
            'Bir çalışma alanına katılarak devam edebilir ya da aşağıdan '
            'kendi alanınızı oluşturabilirsiniz.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
          const SizedBox(height: 12),
          ...invites.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${i.workspaceName}  •  ${i.role.label}',
                          style: const TextStyle(
                              color: Color(0xFFCBD5E1), fontSize: 12)),
                    ),
                    ElevatedButton(
                      onPressed: _busy ? null : () => _acceptInvite(i),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF58220),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Katıl'),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _acceptInvite(WorkspaceInvite invite) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      if (widget.needsProfile) {
        await ref.read(userRepositoryProvider).createProfile(
              uid: user.uid,
              email: user.email ?? '',
              displayName: (user.displayName?.trim().isNotEmpty ?? false)
                  ? user.displayName!.trim()
                  : (user.email ?? 'kullanici').split('@').first,
            );
      }
      await ref.read(workspaceRepositoryProvider).acceptInvite(
            invite: invite,
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
          );
      // AuthGate defaultWorkspaceId değişimini görünce uygulamaya geçer.
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Katılınamadı: $e';
        });
      }
    }
  }
}
