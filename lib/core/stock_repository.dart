import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';

class StockRepository {
  StockRepository(this._db);
  final FirebaseFirestore _db;

  // ─── Ürün Streams ──────────────────────────────────────────────────────────

  Stream<List<Product>> products() => _db
      .collection('products')
      .where('isDeleted', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.map(Product.fromDoc).toList());

  Stream<List<Product>> criticalProducts() =>
      products().map((p) => p.where((x) => x.isLow || x.isCritical).toList());

  Stream<List<Product>> productsByWarehouse(String warehouseId) => _db
      .collection('products')
      .where('isDeleted', isEqualTo: false)
      .where('warehouseId', isEqualTo: warehouseId)
      .snapshots()
      .map((s) => s.docs.map(Product.fromDoc).toList());

  // ─── Ürün Arama ────────────────────────────────────────────────────────────

  Future<Product?> findByCode(String code) async {
    final b = await _db
        .collection('products')
        .where('barcode', isEqualTo: code)
        .limit(1)
        .get();
    if (b.docs.isNotEmpty) return Product.fromDoc(b.docs.first);
    final s = await _db
        .collection('products')
        .where('sku', isEqualTo: code)
        .limit(1)
        .get();
    return s.docs.isEmpty ? null : Product.fromDoc(s.docs.first);
  }

  Future<Product?> getById(String id) async {
    final doc = await _db.collection('products').doc(id).get();
    return doc.exists ? Product.fromDoc(doc) : null;
  }

  // ─── Ürün CRUD ─────────────────────────────────────────────────────────────

  Future<String> addProduct(Map<String, dynamic> data) async {
    final ref = await _db.collection('products').add({
      ...data,
      'currentStock': 0,
      'isDeleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) =>
      _db.collection('products').doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Soft delete — veriyi silmez, isDeleted=true yapar
  Future<void> deleteProduct(String id) =>
      _db.collection('products').doc(id).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ─── Stok Ayarlama (Transaction) ──────────────────────────────────────────

  Future<void> adjustStock({
    required Product product,
    required num quantity,
    required MovementType type,
    required String userId,
    String? userName,
    String reason = '',
    String note = '',
  }) => _db.runTransaction((tx) async {
    final ref = _db.collection('products').doc(product.id);
    final current = await tx.get(ref);
    if (!current.exists) throw StateError('Ürün bulunamadı');
    final before = (current.data()!['currentStock'] as num?) ?? 0;
    final after = before + quantity;
    if (after < 0) throw StateError('Yetersiz stok');
    final m = _db.collection('stock_movements').doc();
    tx.update(ref, {
      'currentStock': after,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    tx.set(m, {
      'movementId': m.id,
      'productId': product.id,
      'productName': product.name,
      'warehouseId': product.warehouseId,
      'userId': userId,
      'userName': userName,
      'type': type.value,
      'quantity': quantity,
      'previousStock': before,
      'newStock': after,
      'reason': reason,
      'note': note,
      'timestamp': FieldValue.serverTimestamp(),
    });
  });

  // ─── Depo Transferi (Atomik) ───────────────────────────────────────────────

  Future<void> transferStock({
    required Product product,
    required String targetWarehouseId,
    required num quantity,
    required String userId,
    String? userName,
    String note = '',
  }) => _db.runTransaction((tx) async {
    final ref = _db.collection('products').doc(product.id);
    final current = await tx.get(ref);
    if (!current.exists) throw StateError('Ürün bulunamadı');
    final before = (current.data()!['currentStock'] as num?) ?? 0;
    if (before < quantity) throw StateError('Yetersiz stok');

    // Ürünün warehouseId'sini güncelle ve mevcut stoğu transfer et
    tx.update(ref, {
      'warehouseId': targetWarehouseId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final m = _db.collection('stock_movements').doc();
    tx.set(m, {
      'movementId': m.id,
      'productId': product.id,
      'productName': product.name,
      'warehouseId': product.warehouseId,
      'targetWarehouseId': targetWarehouseId,
      'userId': userId,
      'userName': userName,
      'type': MovementType.transfer.value,
      'quantity': quantity,
      'previousStock': before,
      'newStock': before,
      'reason': 'Transfer: ${product.warehouseId} → $targetWarehouseId',
      'note': note,
      'timestamp': FieldValue.serverTimestamp(),
    });
  });

  // ─── Sayım Onaylama ───────────────────────────────────────────────────────

  Future<void> applyStockCount({
    required List<StockCountItem> items,
    required String userId,
    String? userName,
  }) async {
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    for (final item in items) {
      if (!item.hasDifference) continue;
      final ref = _db.collection('products').doc(item.product.id);
      batch.update(ref, {
        'currentStock': item.countedQuantity,
        'updatedAt': now,
      });
      final m = _db.collection('stock_movements').doc();
      batch.set(m, {
        'movementId': m.id,
        'productId': item.product.id,
        'productName': item.product.name,
        'warehouseId': item.product.warehouseId,
        'userId': userId,
        'userName': userName,
        'type': MovementType.countAdjustment.value,
        'quantity': item.difference,
        'previousStock': item.product.stock,
        'newStock': item.countedQuantity,
        'reason': 'Depo Sayımı',
        'note': '',
        'timestamp': now,
      });
    }
    await batch.commit();
  }
}
