import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import 'movement_repository.dart';
import 'stock_repository.dart';
import 'user_repository.dart';
import 'warehouse_repository.dart';

// ─── Repository Providers ─────────────────────────────────────────────────────

final stockRepositoryProvider = Provider(
  (_) => StockRepository(FirebaseFirestore.instance),
);

final warehouseRepositoryProvider = Provider(
  (_) => WarehouseRepository(FirebaseFirestore.instance),
);

final movementRepositoryProvider = Provider(
  (_) => MovementRepository(FirebaseFirestore.instance),
);

final userRepositoryProvider = Provider(
  (_) => UserRepository(FirebaseFirestore.instance),
);

// ─── Product Providers ────────────────────────────────────────────────────────

final productsProvider = StreamProvider(
  (ref) => ref.watch(stockRepositoryProvider).products(),
);

final criticalProductsProvider = StreamProvider(
  (ref) => ref.watch(stockRepositoryProvider).criticalProducts(),
);

// ─── Warehouse Providers ──────────────────────────────────────────────────────

final warehousesProvider = StreamProvider(
  (ref) => ref.watch(warehouseRepositoryProvider).warehouses(),
);

// ─── Movement Providers ───────────────────────────────────────────────────────

final recentMovementsProvider = StreamProvider(
  (ref) =>
      ref.watch(movementRepositoryProvider).recentMovements(limit: 50),
);

final movementsByProductProvider =
    StreamProvider.family<List<StockMovement>, String>(
  (ref, productId) =>
      ref.watch(movementRepositoryProvider).movementsByProduct(productId),
);

// ─── User Providers ───────────────────────────────────────────────────────────

final currentUserProfileProvider = StreamProvider(
  (ref) => ref.watch(userRepositoryProvider).currentUserProfile(),
);

final allUsersProvider = StreamProvider(
  (ref) => ref.watch(userRepositoryProvider).allUsers(),
);
