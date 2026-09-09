import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

/// V1 → V2 tek seferlik veri taşıma ekranı.
///
/// V1'de tüm veri düz global koleksiyonlarda (`products`, `stock_movements`, …).
/// Bu ekran onları `workspaces/{BITRONIX_WID}/…` altına kopyalar ve mevcut
/// `users/*` dokümanlarına V2 alanlarını (platformRole, defaultWorkspaceId, …)
/// ekler.
///
/// ÖN KOŞUL: Çalıştıran hesabın `users/{uid}.platformRole` alanı Firebase
/// Console'dan `superAdmin` yapılmış olmalıdır (güvenlik kuralları ilk süper
/// admin ataması için istemciye izin vermez).
const _bitronixWorkspaceId = 'bitronix';
const _bitronixWorkspaceName = 'Bitronix Hardware & Software A.Ş.';

const _collectionsToCopy = [
  'products',
  'stock_movements',
  'warehouses',
  'stock_counts',
  'finance_accounts',
  'finance_transactions',
];

class MigrationScreen extends ConsumerStatefulWidget {
  const MigrationScreen({super.key});

  @override
  ConsumerState<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends ConsumerState<MigrationScreen> {
  final _log = <String>[];
  bool _running = false;
  bool _done = false;

  void _add(String line) {
    if (mounted) setState(() => _log.add(line));
  }

  Future<void> _run() async {
    final db = FirebaseFirestore.instance;
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    setState(() {
      _running = true;
      _done = false;
      _log.clear();
    });

    try {
      // 1) Bitronix workspace'i (sabit id → idempotent)
      final wsRef = db.collection('workspaces').doc(_bitronixWorkspaceId);
      final wsSnap = await wsRef.get();
      if (!wsSnap.exists) {
        await wsRef.set({
          'name': _bitronixWorkspaceName,
          'ownerUid': me.uid,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _add('✓ workspace oluşturuldu: $_bitronixWorkspaceId');
      } else {
        _add('• workspace zaten var: $_bitronixWorkspaceId');
      }

      // 2) Çalıştıran kişiyi admin üye yap
      await wsRef.collection('members').doc(me.uid).set({
        'uid': me.uid,
        'role': 'admin',
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': me.uid,
      }, SetOptions(merge: true));
      _add('✓ ${me.email} → workspace admin');

      // 3) Global koleksiyonları kopyala
      for (final name in _collectionsToCopy) {
        final src = await db.collection(name).get();
        if (src.docs.isEmpty) {
          _add('• $name: kopyalanacak kayıt yok');
          continue;
        }
        var copied = 0;
        var batch = db.batch();
        var ops = 0;
        for (final doc in src.docs) {
          batch.set(wsRef.collection(name).doc(doc.id), doc.data());
          ops++;
          copied++;
          if (ops >= 400) {
            await batch.commit();
            batch = db.batch();
            ops = 0;
          }
        }
        if (ops > 0) await batch.commit();
        _add('✓ $name: $copied kayıt kopyalandı');
      }

      // 4) users/* dokümanlarına V2 alanları + workspace üyeliği
      final users = await db.collection('users').get();
      var patched = 0;
      for (final u in users.docs) {
        final data = u.data();
        final legacyRole = (data['role'] ?? 'viewer').toString();
        await db.collection('users').doc(u.id).set({
          'defaultWorkspaceId': _bitronixWorkspaceId,
          'companyName': data['companyName'] ?? 'Bitronix',
          'status': data['status'] ?? 'active',
          'platformRole': data['platformRole'] ??
              (u.id == me.uid ? 'superAdmin' : 'user'),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await wsRef.collection('members').doc(u.id).set({
          'uid': u.id,
          'role': legacyRole,
          'addedAt': FieldValue.serverTimestamp(),
          'addedBy': me.uid,
        }, SetOptions(merge: true));
        patched++;
      }
      _add('✓ $patched kullanıcı V2 yapısına taşındı');

      _add('');
      _add('✅ Migrasyon tamamlandı. Uygulamayı yeniden başlatın.');
      if (mounted) setState(() => _done = true);
    } catch (e) {
      _add('');
      _add('❌ HATA: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProfileProvider).whenOrNull(data: (p) => p);
    final allowed = me?.isSuperAdmin == true;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('V1 → V2 Veri Migrasyonu'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!allowed)
              const Text(
                'Bu işlemi yalnızca platformRole = superAdmin olan bir hesap '
                'çalıştırabilir. Firebase Console → Firestore → users/{uid} '
                'dokümanında platformRole alanını "superAdmin" yapın.',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 13),
              )
            else
              const Text(
                'Global koleksiyonlar (products, stock_movements, warehouses, '
                'stock_counts, finance_*) "$_bitronixWorkspaceName" workspace\'ine '
                'kopyalanır ve kullanıcı profillerine V2 alanları eklenir. '
                'İşlem tekrar çalıştırılabilir (idempotent).',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: (!allowed || _running) ? null : _run,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_sync_rounded, size: 18),
              label: Text(_running ? 'Çalışıyor…' : 'Migrasyonu Başlat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF58220),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E2333)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _log.isEmpty ? 'Kayıt bekleniyor…' : _log.join('\n'),
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            if (_done)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Not: Eski global koleksiyonlar hâlâ duruyor. Doğrulama '
                  'sonrası firestore.rules ile erişimlerini kapatın.',
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
