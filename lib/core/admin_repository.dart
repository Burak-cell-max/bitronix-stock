import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';

/// Bir kullanıcının workspace'ine ait özet istatistik (admin panelinde gösterilir).
class AdminUserStats {
  const AdminUserStats({
    this.workspaceName,
    this.productCount = 0,
    this.totalStock = 0,
    this.recentMovements = const [],
  });

  final String? workspaceName;
  final int productCount;
  final num totalStock;
  final List<StockMovement> recentMovements;
}

/// Platform (SUPER ADMIN / ADMIN) düzeyi yönetim işlemleri.
///
/// Tüm mutasyonlar `audit_logs` koleksiyonuna kayıt düşer. Firestore güvenlik
/// kuralları bu işlemleri ayrıca sınırlar (platformRole değişimi yalnızca
/// superAdmin; durum değişimi admin/superAdmin ve yalnızca `user` hedefler).
class AdminRepository {
  AdminRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  /// Tüm kullanıcılar. `createdAt` eski kayıtlarda olmayabileceğinden istemci
  /// tarafında sıralanır.
  Stream<List<UserProfile>> users() =>
      _users.snapshots().map((s) {
        final list = s.docs.map(UserProfile.fromDoc).toList();
        list.sort((a, b) {
          final ad = a.createdAt, bd = b.createdAt;
          if (ad == null && bd == null) return a.name.compareTo(b.name);
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });
        return list;
      });

  Future<AdminUserStats> statsForWorkspace(String? wid) async {
    if (wid == null || wid.isEmpty) return const AdminUserStats();
    final wsRef = _db.collection('workspaces').doc(wid);

    final results = await Future.wait([
      wsRef.get(),
      wsRef.collection('products').where('isDeleted', isEqualTo: false).get(),
      wsRef
          .collection('stock_movements')
          .orderBy('timestamp', descending: true)
          .limit(6)
          .get(),
    ]);

    final ws = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final products = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final movements = results[2] as QuerySnapshot<Map<String, dynamic>>;

    num total = 0;
    for (final d in products.docs) {
      total += (d.data()['currentStock'] as num?) ?? 0;
    }

    return AdminUserStats(
      workspaceName: ws.data()?['name'] as String?,
      productCount: products.size,
      totalStock: total,
      recentMovements:
          movements.docs.map(StockMovement.fromDoc).toList(growable: false),
    );
  }

  Future<void> setPlatformRole({
    required UserProfile target,
    required PlatformRole role,
    required String actorUid,
    String? actorEmail,
  }) async {
    await _users.doc(target.uid).update({
      'platformRole': role.wire,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(
      action: 'user.platformRole',
      actorUid: actorUid,
      actorEmail: actorEmail,
      targetId: target.uid,
      details: {
        'email': target.email,
        'from': target.platformRole.wire,
        'to': role.wire,
      },
    );
  }

  /// [status]: 'active' | 'suspended' | 'deleted'
  Future<void> setStatus({
    required UserProfile target,
    required String status,
    required String actorUid,
    String? actorEmail,
  }) async {
    await _users.doc(target.uid).update({
      'status': status,
      'isActive': status == 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(
      action: status == 'deleted' ? 'user.delete' : 'user.status',
      actorUid: actorUid,
      actorEmail: actorEmail,
      targetId: target.uid,
      details: {
        'email': target.email,
        'from': target.status,
        'to': status,
      },
    );
  }

  Stream<List<AuditLog>> recentLogs({int limit = 100}) => _db
      .collection('audit_logs')
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(AuditLog.fromDoc).toList());

  Future<void> _log({
    required String action,
    required String actorUid,
    String? actorEmail,
    String targetType = 'user',
    String? targetId,
    Map<String, dynamic> details = const {},
  }) =>
      _db.collection('audit_logs').add({
        'action': action,
        'actorUid': actorUid,
        'actorEmail': actorEmail,
        'targetType': targetType,
        'targetId': targetId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
}
