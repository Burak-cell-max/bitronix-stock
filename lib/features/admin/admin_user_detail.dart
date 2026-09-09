import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

/// Admin panelinde bir kullanıcının detayları + platform yönetim işlemleri.
/// Geniş ekranda sağ panel olarak gömülür; darda ayrı sayfa olarak açılır.
class AdminUserDetail extends ConsumerWidget {
  const AdminUserDetail({super.key, required this.user});

  final UserProfile user;

  /// Mobil / dar ekran için tam sayfa sürüm.
  static Widget screen({required UserProfile user}) =>
      _AdminUserDetailScreen(user: user);

  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me =
        ref.watch(currentUserProfileProvider).whenOrNull(data: (p) => p);
    final actor = FirebaseAuth.instance.currentUser;
    final statsAsync =
        ref.watch(adminUserStatsProvider(user.defaultWorkspaceId ?? ''));

    final isSelf = actor?.uid == user.uid;
    final canManage = me?.isSuperAdmin == true ||
        (me?.isPlatformAdmin == true &&
            user.platformRole == PlatformRole.user);
    final canManageStatus = canManage && !isSelf;
    final canManageRole = me?.isSuperAdmin == true && !isSelf;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2333)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Kimlik ──
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    const Color(0xFFF58220).withValues(alpha: 0.15),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Color(0xFFF58220),
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(children: [
                      PlatformRoleChip(user.platformRole),
                      const SizedBox(width: 8),
                      StatusPill(user.status),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Profil alanları ──
          _row('E-posta', user.email),
          _row('Şirket', user.companyName ?? '—'),
          _row(
            'Çalışma Alanı',
            statsAsync.whenOrNull(data: (s) => s.workspaceName) ??
                (user.hasWorkspace ? '…' : 'Yok'),
          ),
          _row('Kayıt Tarihi',
              user.createdAt != null ? _df.format(user.createdAt!) : '—'),
          _row('Son Giriş',
              user.lastLogin != null ? _df.format(user.lastLogin!) : 'Hiç'),
          _row('Workspace ID', user.defaultWorkspaceId ?? '—', mono: true),

          const SizedBox(height: 20),
          const _SectionTitle('Stok Özeti'),
          const SizedBox(height: 10),
          statsAsync.when(
            loading: () => const _StatsRow(loading: true),
            error: (e, _) => Text('İstatistik alınamadı: $e',
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 12)),
            data: (s) => Column(
              children: [
                _StatsRow(
                  productCount: s.productCount,
                  totalStock: s.totalStock,
                ),
                if (s.recentMovements.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _SectionTitle('Son Stok Hareketleri'),
                  const SizedBox(height: 8),
                  ...s.recentMovements.map(_movementRow),
                ],
              ],
            ),
          ),

          const SizedBox(height: 22),
          const _SectionTitle('Yönetim İşlemleri'),
          const SizedBox(height: 10),

          if (isSelf)
            const _InfoBox('Kendi hesabınız üzerinde işlem yapamazsınız.')
          else if (!canManage)
            const _InfoBox(
                'Bu hesabı yönetme yetkiniz yok (yalnızca Süper Admin '
                'diğer yöneticileri değiştirebilir).')
          else ...[
            if (canManageRole) ...[
              _actionLabel('Platform Rolü'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: PlatformRole.values.map((r) {
                  final on = r == user.platformRole;
                  return OutlinedButton(
                    onPressed: on
                        ? null
                        : () => _confirmRole(context, ref, actor, r),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          on ? const Color(0xFFF58220) : const Color(0xFF94A3B8),
                      side: BorderSide(
                          color: on
                              ? const Color(0xFFF58220)
                              : const Color(0xFF262C3D)),
                    ),
                    child: Text(r.label, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (canManageStatus) ...[
              _actionLabel('Hesap Durumu'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (user.status != 'active')
                    _btn('Aktifleştir', const Color(0xFF10B981),
                        () => _confirmStatus(context, ref, actor, 'active')),
                  if (user.status == 'active')
                    _btn('Pasife Al', const Color(0xFFF59E0B),
                        () => _confirmStatus(context, ref, actor, 'suspended')),
                  if (user.status != 'deleted')
                    _btn('Hesabı Kapat', const Color(0xFFEF4444),
                        () => _confirmDelete(context, ref, actor)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Onaylar ──
  Future<void> _confirmRole(BuildContext context, WidgetRef ref, User? actor,
      PlatformRole role) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(context,
        title: 'Platform Rolü Değiştir',
        message:
            '${user.name} hesabının platform rolü "${role.label}" olarak '
            'değiştirilecek.',
        danger: role != PlatformRole.user);
    if (ok != true || actor == null) return;
    try {
      await ref.read(adminRepositoryProvider).setPlatformRole(
            target: user,
            role: role,
            actorUid: actor.uid,
            actorEmail: actor.email,
          );
      messenger.showSnackBar(const SnackBar(content: Text('Rol güncellendi.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _confirmStatus(BuildContext context, WidgetRef ref, User? actor,
      String status) async {
    final messenger = ScaffoldMessenger.of(context);
    final label = status == 'active' ? 'aktifleştirilecek' : 'pasife alınacak';
    final ok = await _confirm(context,
        title: 'Hesap Durumu',
        message: '${user.name} hesabı $label. Pasif hesaplar uygulamaya '
            'giriş yapamaz.',
        danger: status != 'active');
    if (ok != true || actor == null) return;
    try {
      await ref.read(adminRepositoryProvider).setStatus(
            target: user,
            status: status,
            actorUid: actor.uid,
            actorEmail: actor.email,
          );
      messenger
          .showSnackBar(const SnackBar(content: Text('Durum güncellendi.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, User? actor) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(context,
        title: 'Hesabı Kapat',
        message:
            '${user.name} (${user.email}) hesabı kapatılacak. Kullanıcı giriş '
            'yapamaz ancak verileri korunur; daha sonra yeniden açılabilir.',
        confirmText: 'Hesabı Kapat',
        danger: true);
    if (ok != true || actor == null) return;
    try {
      await ref.read(adminRepositoryProvider).setStatus(
            target: user,
            status: 'deleted',
            actorUid: actor.uid,
            actorEmail: actor.email,
          );
      messenger.showSnackBar(const SnackBar(content: Text('Hesap kapatıldı.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  // ── Küçük yardımcılar ──
  Widget _row(String k, String v, {bool mono = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 120,
                child: Text(k,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 12))),
            Expanded(
              child: SelectableText(
                v,
                style: TextStyle(
                  color: const Color(0xFFCBD5E1),
                  fontSize: 12,
                  fontFamily: mono ? 'monospace' : null,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _actionLabel(String s) => Text(s,
      style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.bold));

  Widget _btn(String label, Color color, VoidCallback onTap) =>
      ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          elevation: 0,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );

  static Widget _movementRow(StockMovement m) {
    final pos = m.quantity > 0;
    final color =
        pos ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(pos ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 13, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              m.productName.isNotEmpty ? m.productName : m.productId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
            ),
          ),
          Text(m.type.displayLabel,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          const SizedBox(width: 10),
          Text('${pos ? '+' : ''}${m.quantity}',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Onayla',
    bool danger = false,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF161922),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF262C3D)),
          ),
          title: Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(message,
              style: const TextStyle(color: Color(0xFFCBD5E1))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: (danger
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF58220))
                    .withValues(alpha: 0.2),
                foregroundColor:
                    danger ? Colors.redAccent : const Color(0xFFF58220),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmText),
            ),
          ],
        ),
      );

}

// ─── Ortak rozetler (admin panelinde de kullanılır) ──────────────────────────

class PlatformRoleChip extends StatelessWidget {
  const PlatformRoleChip(this.role, {super.key});
  final PlatformRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      PlatformRole.superAdmin => const Color(0xFFEF4444),
      PlatformRole.admin => const Color(0xFFF58220),
      PlatformRole.user => const Color(0xFF64748B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(role.label,
          style: TextStyle(
              color: color, fontSize: 9.5, fontWeight: FontWeight.bold)),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'active' => (const Color(0xFF10B981), 'Aktif'),
      'suspended' => (const Color(0xFFF59E0B), 'Pasif'),
      'deleted' => (const Color(0xFFEF4444), 'Kapatılmış'),
      _ => (const Color(0xFF64748B), status),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _AdminUserDetailScreen extends StatelessWidget {
  const _AdminUserDetailScreen({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B0D12),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1017),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(user.name,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AdminUserDetail(user: user),
        ),
      );
}

// ─── Alt bileşenler ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold));
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    this.productCount = 0,
    this.totalStock = 0,
    this.loading = false,
  });

  final int productCount;
  final num totalStock;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value, IconData icon, Color color) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0D12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E2333)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(height: 8),
                Text(loading ? '…' : value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 11)),
              ],
            ),
          ),
        );

    return Row(children: [
      tile('Ürün Sayısı', '$productCount', Icons.widgets_rounded,
          const Color(0xFF3B82F6)),
      const SizedBox(width: 12),
      tile('Toplam Stok', '$totalStock', Icons.inventory_2_rounded,
          const Color(0xFFF58220)),
    ]);
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0D12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E2333)),
        ),
        child: Text(text,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      );
}
