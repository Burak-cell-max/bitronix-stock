import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

/// Çalışma alanı ayarları: ad, ekip üyeleri, e-posta davetleri.
class WorkspaceSettingsScreen extends ConsumerStatefulWidget {
  const WorkspaceSettingsScreen({super.key});

  @override
  ConsumerState<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState
    extends ConsumerState<WorkspaceSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _inviteEmailCtrl = TextEditingController();
  UserRole _inviteRole = UserRole.viewer;
  bool _nameDirty = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _inviteEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wsAsync = ref.watch(currentWorkspaceProvider);
    final membership = ref
        .watch(currentMembershipProvider)
        .whenOrNull(data: (m) => m);
    final isAdmin = membership?.isAdmin ?? false;
    final me = FirebaseAuth.instance.currentUser;

    // Ad alanını workspace yüklenince bir kez doldur.
    wsAsync.whenData((ws) {
      if (ws != null && !_nameDirty && _nameCtrl.text.isEmpty) {
        _nameCtrl.text = ws.name;
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Çalışma Alanı Ayarları',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: wsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFF58220))),
        error: (e, _) => Center(
            child: Text('Hata: $e',
                style: const TextStyle(color: Colors.redAccent))),
        data: (ws) {
          if (ws == null) {
            return const Center(
                child: Text('Çalışma alanı bulunamadı.',
                    style: TextStyle(color: Color(0xFF64748B))));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MyInvitesSection(currentWorkspaceId: ws.id),
                    _card(
                      title: 'Genel',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Çalışma Alanı Adı',
                              style: TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 12)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  enabled: isAdmin,
                                  onChanged: (_) =>
                                      setState(() => _nameDirty = true),
                                  style:
                                      const TextStyle(color: Colors.white),
                                  decoration: _dec(),
                                ),
                              ),
                              if (isAdmin) ...[
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: _nameDirty &&
                                          _nameCtrl.text.trim().isNotEmpty
                                      ? () => _saveName(ws.id)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF58220),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 14),
                                  ),
                                  child: const Text('Kaydet'),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('Workspace ID: ${ws.id}',
                              style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 11,
                                  fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    _card(
                      title: 'Ekip Üyeleri',
                      child: _MembersList(
                        workspaceId: ws.id,
                        ownerUid: ws.ownerUid,
                        isAdmin: isAdmin,
                        myUid: me?.uid ?? '',
                      ),
                    ),
                    if (isAdmin)
                      _card(
                        title: 'Davetler',
                        child: _InvitesSection(
                          workspace: ws,
                          emailCtrl: _inviteEmailCtrl,
                          role: _inviteRole,
                          onRoleChanged: (r) => setState(() => _inviteRole = r),
                          onSend: () => _sendInvite(ws),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _dec() => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF0B0D12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF262C3D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF262C3D)),
        ),
      );

  Widget _card({required String title, required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF12151E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E2333)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );

  Future<void> _saveName(String wid) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .updateName(wid: wid, name: _nameCtrl.text);
      setState(() => _nameDirty = false);
      messenger.showSnackBar(
          const SnackBar(content: Text('Çalışma alanı adı güncellendi.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _sendInvite(Workspace ws) async {
    final messenger = ScaffoldMessenger.of(context);
    final email = _inviteEmailCtrl.text.trim().toLowerCase();
    final me = FirebaseAuth.instance.currentUser;
    if (!email.contains('@') || me == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Geçerli bir e-posta girin.')));
      return;
    }
    try {
      await ref.read(workspaceRepositoryProvider).createInvite(
            workspaceId: ws.id,
            workspaceName: ws.name,
            email: email,
            role: _inviteRole,
            invitedBy: me.uid,
          );
      _inviteEmailCtrl.clear();
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Davet oluşturuldu. $email bu adresle kayıt olup Ayarlar > '
            'Davetler bölümünden kabul edebilir.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Davet gönderilemedi: $e')));
    }
  }
}

// ─── Üyeler ───────────────────────────────────────────────────────────────────

class _MembersList extends ConsumerWidget {
  const _MembersList({
    required this.workspaceId,
    required this.ownerUid,
    required this.isAdmin,
    required this.myUid,
  });

  final String workspaceId, ownerUid, myUid;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(workspaceMembersProvider);
    return membersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
            child: CircularProgressIndicator(color: Color(0xFFF58220))),
      ),
      error: (e, _) => Text('Hata: $e',
          style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
      data: (members) {
        final sorted = [...members]..sort((a, b) => a.role.index
            .compareTo(b.role.index)); // admin önce
        return Column(
          children: sorted.map((m) {
            final isOwner = m.uid == ownerUid;
            final isSelf = m.uid == myUid;
            final canEdit = isAdmin && !isOwner && !isSelf;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor:
                        const Color(0xFFF58220).withValues(alpha: 0.15),
                    child: Text(
                      m.label.isNotEmpty ? m.label[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Color(0xFFF58220),
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(m.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (isOwner)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Text('• Sahip',
                                  style: TextStyle(
                                      color: Color(0xFFF58220), fontSize: 10)),
                            ),
                          if (isSelf)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Text('• Sen',
                                  style: TextStyle(
                                      color: Color(0xFF64748B), fontSize: 10)),
                            ),
                        ]),
                        if (m.email != null && m.email != m.label)
                          Text(m.email!,
                              style: const TextStyle(
                                  color: Color(0xFF64748B), fontSize: 10)),
                      ],
                    ),
                  ),
                  if (canEdit)
                    DropdownButton<UserRole>(
                      value: m.role,
                      dropdownColor: const Color(0xFF161922),
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(
                          color: Color(0xFFCBD5E1), fontSize: 12),
                      items: UserRole.values
                          .map((r) => DropdownMenuItem(
                              value: r, child: Text(r.label)))
                          .toList(),
                      onChanged: (r) {
                        if (r != null) {
                          ref.read(workspaceRepositoryProvider).setMemberRole(
                                wid: workspaceId,
                                uid: m.uid,
                                role: r,
                                actorUid: myUid,
                              );
                        }
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2333),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(m.role.label,
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 10)),
                    ),
                  if (canEdit)
                    IconButton(
                      icon: const Icon(Icons.person_remove_rounded,
                          size: 16, color: Color(0xFF64748B)),
                      tooltip: 'Üyeyi çıkar',
                      onPressed: () => _confirmRemove(context, ref, m),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, WorkspaceMembership m) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        title: const Text('Üyeyi Çıkar',
            style: TextStyle(color: Colors.white)),
        content: Text('${m.label} bu çalışma alanından çıkarılacak.',
            style: const TextStyle(color: Color(0xFFCBD5E1))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç',
                  style: TextStyle(color: Color(0xFF64748B)))),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .removeMember(workspaceId, m.uid);
      messenger.showSnackBar(const SnackBar(content: Text('Üye çıkarıldı.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }
}

// ─── Davet gönderme + bekleyen davetler ──────────────────────────────────────

class _InvitesSection extends ConsumerWidget {
  const _InvitesSection({
    required this.workspace,
    required this.emailCtrl,
    required this.role,
    required this.onRoleChanged,
    required this.onSend,
  });

  final Workspace workspace;
  final TextEditingController emailCtrl;
  final UserRole role;
  final ValueChanged<UserRole> onRoleChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(workspaceInvitesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'davet@edilecek.com',
                  hintStyle:
                      TextStyle(color: Color(0xFF475569), fontSize: 12),
                  filled: true,
                  fillColor: Color(0xFF0B0D12),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: Color(0xFF262C3D)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: Color(0xFF262C3D)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<UserRole>(
              value: role,
              dropdownColor: const Color(0xFF161922),
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
              underline: const SizedBox.shrink(),
              items: UserRole.values
                  .map((r) =>
                      DropdownMenuItem(value: r, child: Text(r.label)))
                  .toList(),
              onChanged: (r) => r != null ? onRoleChanged(r) : null,
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF58220),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: const Text('Davet Et'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Davet edilen kişi bu e-posta ile kayıt olup Ayarlar\'dan daveti '
          'kabul eder (otomatik e-posta gönderilmez).',
          style: TextStyle(color: Color(0xFF475569), fontSize: 11),
        ),
        const SizedBox(height: 14),
        invitesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (invites) {
            final pending = invites.where((i) => i.isPending).toList();
            if (pending.isEmpty) {
              return const Text('Bekleyen davet yok.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12));
            }
            return Column(
              children: pending.map((i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline_rounded,
                          size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${i.email}  •  ${i.role.label}',
                            style: const TextStyle(
                                color: Color(0xFFCBD5E1), fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(workspaceRepositoryProvider)
                            .revokeInvite(i.id),
                        child: const Text('İptal',
                            style: TextStyle(
                                color: Color(0xFFEF4444), fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ─── Bana gelen davetler ─────────────────────────────────────────────────────

class _MyInvitesSection extends ConsumerWidget {
  const _MyInvitesSection({required this.currentWorkspaceId});
  final String currentWorkspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(myInvitesProvider);
    final invites = invitesAsync.whenOrNull(data: (v) => v) ?? const [];
    final others =
        invites.where((i) => i.workspaceId != currentWorkspaceId).toList();
    if (others.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF58220).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF58220).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sizi Bekleyen Davetler',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...others.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${i.workspaceName}  •  ${i.role.label} olarak',
                        style: const TextStyle(
                            color: Color(0xFFCBD5E1), fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(workspaceRepositoryProvider)
                          .declineInvite(i),
                      child: const Text('Reddet',
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: () => _accept(context, ref, i),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF58220),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Kabul Et'),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _accept(
      BuildContext context, WidgetRef ref, WorkspaceInvite invite) async {
    final messenger = ScaffoldMessenger.of(context);
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    try {
      await ref.read(workspaceRepositoryProvider).acceptInvite(
            invite: invite,
            uid: me.uid,
            email: me.email,
            displayName: me.displayName,
          );
      ref.invalidate(myWorkspacesProvider);
      messenger.showSnackBar(SnackBar(
          content: Text('${invite.workspaceName} çalışma alanına katıldınız.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Kabul edilemedi: $e')));
    }
  }
}
