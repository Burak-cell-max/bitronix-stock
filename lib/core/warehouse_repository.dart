import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';

class WarehouseRepository {
  WarehouseRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<Warehouse>> warehouses() => _db
      .collection('warehouses')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(Warehouse.fromDoc).toList());

  Future<void> add(Warehouse w) =>
      _db.collection('warehouses').add(w.toMap());

  Future<void> update(String id, Map<String, dynamic> data) =>
      _db.collection('warehouses').doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deactivate(String id) =>
      _db.collection('warehouses').doc(id).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<Warehouse?> getById(String id) async {
    final doc = await _db.collection('warehouses').doc(id).get();
    if (!doc.exists) return null;
    return Warehouse.fromDoc(doc);
  }
}
