import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../admin/admin_user_detail.dart';
import '../admin/migration_screen.dart';

/// Platform yönetim paneli (SUPER ADMIN / ADMIN).
/// Kabuğun "Yönetim" sekmesinde açılır.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  int _tab = 0; // 0 = Kullanıcılar, 1 = İşlem Kayıtları
  String _search = '';
  String _statusFilter = 'all'; // all | active | suspended | deleted
  String? _selectedUid;

  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProfileProvider).whenOrNull(data: (p) => p);

    if (me != null && !me.isPlatformAdmin) {
      return const _AccessDenied();
    }

    final isWide = MediaQuery.sizeOf(context).width >= 1080;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(me),
            const SizedBox(height: 18),
            _tabs(),
            const SizedBox(height: 16),
            Expanded(
              child: _tab == 0
                  ? _usersTab(me, isWide)
                  : const _AuditLogTab(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(UserProfile? me) {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yönetim Paneli',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Tüm kiracıların hesaplarını ve platform erişimini yönetin',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
        const Spacer(),
        if (me?.isSuperAdmin == true) ...[
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MigrationScreen()),
            ),
            icon: const Icon(Icons.cloud_sync_rounded, size: 16),
            label: const Text('V1 → V2 Migrasyon'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF94A3B8),
              side: const BorderSide(color: Color(0xFF262C3D)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(width: 10),
        ],
        OutlinedButton.icon(
          onPressed: _showInviteDialog,
          icon: const Icon(Icons.person_add_alt_rounded, size: 16),
          label: const Text('Kullanıcı Davet Et'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFCBD5E1),
            side: const BorderSide(color: Color(0xFF262C3D)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _tabs() {
    Widget t(int i, String label, IconData icon) => InkWell(
          onTap: () => setState(() => _tab = i),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: _tab == i
                  ? const Color(0xFFF58220).withValues(alpha: 0.15)
                  : const Color(0xFF12151E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _tab == i
                    ? const Color(0xFFF58220).withValues(alpha: 0.6)
                    : const Color(0xFF1E2333),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 15,
                  color: _tab == i
                      ? const Color(0xFFF58220)
                      : const Color(0xFF94A3B8)),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      color: _tab == i ? Colors.white : const Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight:
                          _tab == i ? FontWeight.bold : FontWeight.normal)),
            ]),
          ),
        );
    return Row(children: [
      t(0, 'Kullanıcılar', Icons.group_rounded),
      const SizedBox(width: 8),
      t(1, 'İşlem Kayıtları', Icons.receipt_long_rounded),
    ]);
  }

  // ── Kullanıcılar sekmesi ─────────────────────────────────────────────────
  Widget _usersTab(UserProfile? me, bool isWide) {
    final usersAsync = ref.watch(adminUsersProvider);

    return usersAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFF58220))),
      error: (e, _) => Center(
          child: Text('Hata: $e',
              style: const TextStyle(color: Colors.redAccent))),
      data: (all) {
        final q = _search.toLowerCase().trim();
        final filtered = all.where((u) {
          if (_statusFilter != 'all' && u.status != _statusFilter) return false;
          if (q.isEmpty) return true;
          return u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              (u.companyName ?? '').toLowerCase().contains(q);
        }).toList();

        final selected = _selectedUid == null
            ? null
            : all.where((u) => u.uid == _selectedUid).firstOrNull;

        final list = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _toolbar(all, filtered.length),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Eşleşen kullanıcı yok.',
                          style: TextStyle(color: Color(0xFF64748B))))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final u = filtered[i];
                        return _UserCard(
                          user: u,
                          df: _df,
                          selected: isWide && u.uid == _selectedUid,
                          onTap: () {
                            if (isWide) {
                              setState(() => _selectedUid = u.uid);
                            } else {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => AdminUserDetail.screen(user: u),
                              ));
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );

        if (!isWide) return list;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: list),
            const SizedBox(width: 20),
            Expanded(
              flex: 6,
              child: selected == null
                  ? _EmptyDetail()
                  : AdminUserDetail(
                      key: ValueKey(selected.uid),
                      user: selected,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _toolbar(List<UserProfile> all, int shown) {
    Widget chip(String value, String label) {
      final on = _statusFilter == value;
      final count = value == 'all'
          ? all.length
          : all.where((u) => u.status == value).length;
      return InkWell(
        onTap: () => setState(() => _statusFilter = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on
                ? const Color(0xFFF58220).withValues(alpha: 0.15)
                : const Color(0xFF12151E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: on
                    ? const Color(0xFFF58220).withValues(alpha: 0.5)
                    : const Color(0xFF1E2333)),
          ),
          child: Text('$label ($count)',
              style: TextStyle(
                  color: on ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: on ? FontWeight.bold : FontWeight.normal)),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          height: 38,
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ad, e-posta veya şirket ara...',
              hintStyle:
                  const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF64748B), size: 18),
              filled: true,
              fillColor: const Color(0xFF12151E),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF1E2333)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF1E2333)),
              ),
            ),
          ),
        ),
        chip('all', 'Tümü'),
        chip('active', 'Aktif'),
        chip('suspended', 'Pasif'),
        chip('deleted', 'Kapatılmış'),
      ],
    );
  }

  // ── Davet dialogu ────────────────────────────────────────────────────────
  void _showInviteDialog() {
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
          width: 380,
          child: Text(
            'Yeni müşteriler uygulamadaki "Kayıt Ol" ekranından kendi '
            'hesaplarını ve çalışma alanlarını oluşturur. Bir Bitronix '
            'personeli eklemek için Firebase Console → Authentication → Add '
            'User ile hesabı açın; kullanıcı giriş yapınca profili otomatik '
            'oluşur, ardından buradan platform rolü atayın.',
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

// ─── Kullanıcı kartı ──────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.df,
    required this.selected,
    required this.onTap,
  });

  final UserProfile user;
  final DateFormat df;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF12151E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFFF58220)
                : const Color(0xFF1E2333),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  const Color(0xFFF58220).withValues(alpha: 0.15),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Color(0xFFF58220), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      PlatformRoleChip(user.platformRole),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.email}  •  ${user.companyName ?? '—'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusPill(user.status),
                const SizedBox(height: 4),
                Text(
                  user.lastLogin != null
                      ? 'Son: ${df.format(user.lastLogin!)}'
                      : 'Hiç giriş yok',
                  style:
                      const TextStyle(color: Color(0xFF475569), fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── İşlem kayıtları sekmesi ──────────────────────────────────────────────────

class _AuditLogTab extends ConsumerWidget {
  const _AuditLogTab();

  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

  String _label(String action) => switch (action) {
        'user.platformRole' => 'Platform rolü değiştirildi',
        'user.status' => 'Hesap durumu değiştirildi',
        'user.delete' => 'Hesap kapatıldı',
        _ => action,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);
    return logsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFF58220))),
      error: (e, _) => Center(
          child: Text('Hata: $e',
              style: const TextStyle(color: Colors.redAccent))),
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(
              child: Text('Henüz kayıt yok.',
                  style: TextStyle(color: Color(0xFF64748B))));
        }
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF12151E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E2333)),
          ),
          child: ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: Color(0xFF1E2333)),
            itemBuilder: (_, i) {
              final l = logs[i];
              final d = l.details;
              final detail = [
                if (d['email'] != null) d['email'],
                if (d['from'] != null && d['to'] != null)
                  '${d['from']} → ${d['to']}',
              ].join('  •  ');
              return ListTile(
                dense: true,
                leading: const Icon(Icons.security_rounded,
                    size: 16, color: Color(0xFFF58220)),
                title: Text(_label(l.action),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${detail.isEmpty ? '' : '$detail\n'}'
                  '${l.actorEmail ?? l.actorUid}'
                  '${l.timestamp != null ? '  •  ${_df.format(l.timestamp!)}' : ''}',
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 11),
                ),
                isThreeLine: detail.isNotEmpty,
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Yardımcı ekranlar ────────────────────────────────────────────────────────

class _EmptyDetail extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF12151E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E2333)),
        ),
        child: const Center(
          child: Text('Detay için bir kullanıcı seçin',
              style: TextStyle(color: Color(0xFF475569), fontSize: 13)),
        ),
      );
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.admin_panel_settings_outlined,
                  size: 48, color: Color(0xFF64748B)),
              SizedBox(height: 12),
              Text('Yönetim Paneli',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Bu alan yalnızca Bitronix platform yöneticileri içindir.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
        ),
      );
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
