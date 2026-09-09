import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_repository.dart';
import 'models.dart';
import 'movement_repository.dart';
import 'finance_repository.dart';
import 'stock_repository.dart';
import 'user_repository.dart';
import 'warehouse_repository.dart';
import 'workspace_repository.dart';

/// Workspace verisi akışı için ortak sarmalayıcı:
/// - repo yoksa (henüz workspace seçilmedi) boş liste,
/// - 20 sn içinde hiçbir olay gelmezse anlaşılır bir hata (sonsuz spinner yerine).
///   Firestore sağlıklı bağlantıda saniyeler içinde yanıt verir; bu süre aşılırsa
///   genelde kurallar yayınlanmamıştır ya da hesabın çalışma alanı yoktur.
Stream<T> _wsStream<T>(Stream<T>? source, T whenNull) {
  return (source ?? Stream<T>.value(whenNull)).timeout(
    const Duration(seconds: 20),
    onTimeout: (sink) => sink.addError(
      'Veri yüklenemedi (zaman aşımı). Firestore kuralları yayınlandı mı '
      've bu hesabın bir çalışma alanı var mı? '
      'Terminal: firebase deploy --only firestore:rules',
    ),
  );
}

// ─── Workspace-agnostic Repository Providers ─────────────────────────────────

final userRepositoryProvider = Provider(
  (_) => UserRepository(FirebaseFirestore.instance),
);

final workspaceRepositoryProvider = Provider(
  (_) => WorkspaceRepository(FirebaseFirestore.instance),
);

// ─── User / Session ─────────────────────────────────────────────────────────

final currentUserProfileProvider = StreamProvider<UserProfile?>(
  (ref) => ref.watch(userRepositoryProvider).currentUserProfile(),
);

/// Giriş yapan kullanıcının aktif workspace id'si. Profili/workspace'i yoksa null.
final currentWorkspaceIdProvider = Provider<String?>(
  (ref) => ref
      .watch(currentUserProfileProvider)
      .whenOrNull(data: (p) => p?.defaultWorkspaceId),
);

/// Giriş yapan kullanıcının aktif workspace içindeki rolü/yetkileri.
final currentMembershipProvider = StreamProvider<WorkspaceMembership?>((ref) {
  final wid = ref.watch(currentWorkspaceIdProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (wid == null || uid == null) return Stream.value(null);
  return ref.watch(workspaceRepositoryProvider).myMembership(wid, uid);
});

final currentWorkspaceProvider = StreamProvider<Workspace?>((ref) {
  final wid = ref.watch(currentWorkspaceIdProvider);
  if (wid == null) return Stream.value(null);
  return ref.watch(workspaceRepositoryProvider).watch(wid);
});

/// Aktif workspace'in üyeleri.
final workspaceMembersProvider =
    StreamProvider<List<WorkspaceMembership>>((ref) {
  final wid = ref.watch(currentWorkspaceIdProvider);
  if (wid == null) return Stream.value(const []);
  return ref.watch(workspaceRepositoryProvider).members(wid);
});

/// Aktif workspace'in bekleyen/işlenmiş davetleri.
final workspaceInvitesProvider =
    StreamProvider<List<WorkspaceInvite>>((ref) {
  final wid = ref.watch(currentWorkspaceIdProvider);
  if (wid == null) return Stream.value(const []);
  return ref.watch(workspaceRepositoryProvider).workspaceInvites(wid);
});

/// Giriş yapan kullanıcının e-postasına gelen bekleyen davetler.
final myInvitesProvider = StreamProvider<List<WorkspaceInvite>>((ref) {
  // Auth durumu değişince yeniden değerlendir.
  ref.watch(currentUserProfileProvider);
  final email = FirebaseAuth.instance.currentUser?.email;
  if (email == null || email.isEmpty) return Stream.value(const []);
  return ref.watch(workspaceRepositoryProvider).invitesForEmail(email);
});

/// Kullanıcının üye olduğu tüm workspace'ler (geçiş menüsü için).
final myWorkspacesProvider =
    FutureProvider.autoDispose<List<WorkspaceRef>>((ref) async {
  ref.watch(currentUserProfileProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const [];
  return ref.watch(workspaceRepositoryProvider).myWorkspaces(uid);
});

// ─── Workspace-scoped Repository Providers (workspace yoksa null) ────────────

bool _validWid(String? w) => w != null && w.isNotEmpty;

final stockRepositoryProvider = Provider<StockRepository?>((ref) {
  final wid = ref.watch(currentWorkspaceIdProvider);
  return _validWid(wid)
      ? StockRepository(FirebaseFirestore.instance, wid!)
      : null;
});

final warehouseRepositoryProvider = Provider<WarehouseRepository?>((ref) {
  final wid = ref.watch(currentWorkspaceIdProvider);
  return _validWid(wid)
      ? WarehouseRepository(FirebaseFirestore.instance, wid!)
      : null;
});

final movementRepositoryProvider = Provider<MovementRepository?>((ref) {
  final wid = ref.watch(currentWorkspaceIdProvider);
  return _validWid(wid)
      ? MovementRepository(FirebaseFirestore.instance, wid!)
      : null;
});

final financeRepositoryProvider = Provider<FinanceRepository?>((ref) {
  final wid = ref.watch(currentWorkspaceIdProvider);
  return _validWid(wid)
      ? FinanceRepository(FirebaseFirestore.instance, wid!)
      : null;
});

// ─── Finance Providers ──────────────────────────────────────────────────────

final financeAccountsProvider = StreamProvider<List<FinanceAccount>>((ref) =>
    _wsStream(ref.watch(financeRepositoryProvider)?.accounts(), const []));

final financeTransactionsProvider =
    StreamProvider<List<FinanceTransaction>>((ref) => _wsStream(
        ref.watch(financeRepositoryProvider)?.transactions(), const []));

// ─── Product Providers ──────────────────────────────────────────────────────

final productsProvider = StreamProvider<List<Product>>((ref) =>
    _wsStream(ref.watch(stockRepositoryProvider)?.products(), const []));

final criticalProductsProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(stockRepositoryProvider);
  return repo?.criticalProducts() ?? Stream.value(const []);
});

// ─── Warehouse Providers ────────────────────────────────────────────────────

final warehousesProvider = StreamProvider<List<Warehouse>>((ref) =>
    _wsStream(ref.watch(warehouseRepositoryProvider)?.warehouses(), const []));

// ─── Movement Providers ─────────────────────────────────────────────────────

final recentMovementsProvider = StreamProvider<List<StockMovement>>((ref) =>
    _wsStream(
        ref.watch(movementRepositoryProvider)?.recentMovements(limit: 50),
        const []));

final movementsByProductProvider =
    StreamProvider.family<List<StockMovement>, String>((ref, productId) {
  final repo = ref.watch(movementRepositoryProvider);
  return repo?.movementsByProduct(productId) ?? Stream.value(const []);
});

// ─── Admin paneli (platform) ────────────────────────────────────────────────

final allUsersProvider = StreamProvider<List<UserProfile>>(
  (ref) => ref.watch(userRepositoryProvider).allUsers(),
);

final adminRepositoryProvider = Provider(
  (_) => AdminRepository(FirebaseFirestore.instance),
);

final adminUsersProvider = StreamProvider<List<UserProfile>>(
  (ref) => ref.watch(adminRepositoryProvider).users(),
);

/// Bir workspace'in özet istatistiği. Anahtar = workspace id (boşsa boş özet).
final adminUserStatsProvider =
    FutureProvider.autoDispose.family<AdminUserStats, String>(
  (ref, wid) => ref.watch(adminRepositoryProvider).statsForWorkspace(wid),
);

final auditLogsProvider = StreamProvider<List<AuditLog>>(
  (ref) => ref.watch(adminRepositoryProvider).recentLogs(),
);
