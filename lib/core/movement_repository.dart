import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';

class MovementRepository {
  MovementRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<StockMovement>> recentMovements({int limit = 50}) => _db
      .collection('stock_movements')
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(StockMovement.fromDoc).toList());

  Stream<List<StockMovement>> movementsByProduct(String productId,
          {int limit = 100}) =>
      _db
          .collection('stock_movements')
          .where('productId', isEqualTo: productId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(StockMovement.fromDoc).toList());

  Future<List<StockMovement>> movementsByDateRange(
      DateTime from, DateTime to) async {
    final snap = await _db
        .collection('stock_movements')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('timestamp', descending: true)
        .get();
    return snap.docs.map(StockMovement.fromDoc).toList();
  }

  Future<List<StockMovement>> movementsByType(MovementType type,
      {int limit = 100}) async {
    final snap = await _db
        .collection('stock_movements')
        .where('type', isEqualTo: type.value)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(StockMovement.fromDoc).toList();
  }
}
