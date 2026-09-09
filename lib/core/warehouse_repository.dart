import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';

class WarehouseRepository {
  WarehouseRepository(this._db, this.workspaceId);
  final FirebaseFirestore _db;
  final String workspaceId;

  CollectionReference<Map<String, dynamic>> get _warehouses =>
      _db.collection('workspaces').doc(workspaceId).collection('warehouses');

  Stream<List<Warehouse>> warehouses() => _warehouses
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(Warehouse.fromDoc).toList());

  Future<void> add(Warehouse w) => _warehouses.add(w.toMap());

  Future<void> update(String id, Map<String, dynamic> data) =>
      _warehouses.doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deactivate(String id) => _warehouses.doc(id).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<Warehouse?> getById(String id) async {
    final doc = await _warehouses.doc(id).get();
    if (!doc.exists) return null;
    return Warehouse.fromDoc(doc);
  }
}
