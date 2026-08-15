import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/user_repository.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final currentUser = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Spacer(),
                currentUser.whenOrNull(
                  data: (profile) => profile?.isAdmin == true
                      ? ElevatedButton.icon(
                          onPressed: () =>
                              _showAddUserDialog(context),
                          icon: const Icon(Icons.person_add_rounded,
                              size: 18),
                          label: const Text('Kullanıcı Davet Et'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF58220),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                          ),
                        )
                      : const SizedBox.shrink(),
                ) ??
                    const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 16),

            // Table header
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF12151E),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border.all(color: const Color(0xFF1E2333)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const Row(
                children: [
                  Expanded(flex: 1, child: _TH('Kullanıcı')),
                  Expanded(flex: 1, child: _TH('E-posta')),
                  Expanded(flex: 1, child: _TH('Rol')),
                  SizedBox(width: 100, child: _TH('Durum')),
                  SizedBox(width: 100),
                ],
              ),
            ),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  border: Border(
                    left: const BorderSide(color: Color(0xFF1E2333)),
                    right: const BorderSide(color: Color(0xFF1E2333)),
                    bottom: const BorderSide(color: Color(0xFF1E2333)),
                  ),
                ),
                child: usersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFF58220)),
                  ),
                  error: (e, _) => Center(
                    child: Text('Hata: $e',
                        style:
                            const TextStyle(color: Colors.redAccent)),
                  ),
                  data: (users) {
                    if (users.isEmpty) {
                      return const Center(
                        child: Text(
                          'Hiç kullanıcı bulunamadı.',
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 14),
                        ),
                      );
                    }
                    final currentProfile =
                        currentUser.asData?.value;
                    return ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, index) => const Divider(
                        color: Color(0xFF1E2333),
                        height: 1,
                      ),
                      itemBuilder: (context, i) => _UserRow(
                        user: users[i],
                        canEdit: currentProfile?.isAdmin == true,
                        onRoleChange: (role) =>
                            _changeRole(users[i].uid, role),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeRole(String uid, UserRole role) async {
    await UserRepository(FirebaseFirestore.instance).setRole(uid, role);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Rol güncellendi: ${role.label}')),
      );
    }
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF262C3D)),
        ),
        title: const Text('Kullanıcı Davet Et',
            style: TextStyle(color: Colors.white)),
        content: const SizedBox(
          width: 360,
          child: Text(
            'Yeni kullanıcılar Firebase Authentication üzerinden davet edilebilir. Firebase Console → Authentication → Add User bölümünü kullanın veya "Şifremi Unuttum" ile kullanıcının e-posta adresini kaydedin.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat',
                style: TextStyle(color: Color(0xFFF58220))),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.canEdit,
    required this.onRoleChange,
  });

  final UserProfile user;
  final bool canEdit;
  final ValueChanged<UserRole> onRoleChange;

  Color get _roleColor => switch (user.role) {
        UserRole.admin => const Color(0xFFF58220),
        UserRole.manager => const Color(0xFF3B82F6),
        UserRole.warehouse => const Color(0xFF10B981),
        UserRole.production => const Color(0xFF8B5CF6),
        UserRole.accounting => const Color(0xFFF59E0B),
        UserRole.viewer => const Color(0xFF64748B),
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Expanded(
            flex: 1,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      const Color(0xFFF58220).withValues(alpha: 0.15),
                  child: Text(
                    user.name.isNotEmpty
                        ? user.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFFF58220),
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Text(user.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(user.email,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 13)),
          ),
          Expanded(
            flex: 1,
            child: canEdit
                ? DropdownButton<UserRole>(
                    value: user.role,
                    dropdownColor: const Color(0xFF161922),
                    style: TextStyle(color: _roleColor, fontSize: 12),
                    underline: const SizedBox.shrink(),
                    items: UserRole.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            ))
                        .toList(),
                    onChanged: (r) => r != null ? onRoleChange(r) : null,
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(user.role.label,
                        style: TextStyle(
                            color: _roleColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
          ),
          SizedBox(
            width: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user.isActive
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFF64748B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                user.isActive ? 'Aktif' : 'Pasif',
                style: TextStyle(
                    color: user.isActive
                        ? const Color(0xFF10B981)
                        : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 100),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  const _TH(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.bold),
      );
}
