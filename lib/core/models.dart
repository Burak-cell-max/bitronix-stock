import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum UserRole { admin, manager, warehouse, production, accounting, viewer }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.admin => 'Yönetici (Admin)',
    UserRole.manager => 'Müdür (Manager)',
    UserRole.warehouse => 'Depo Görevlisi',
    UserRole.production => 'Üretim Görevlisi',
    UserRole.accounting => 'Muhasebe',
    UserRole.viewer => 'Görüntüleyici',
  };

  String get value => name.toUpperCase();

  static UserRole fromString(String s) =>
      UserRole.values.firstWhere((e) => e.name == s.toLowerCase(),
          orElse: () => UserRole.viewer);
}

enum MovementType {
  purchase,
  sale,
  stockIn,
  stockOut,
  transfer,
  production,
  productionConsumption,
  returnItem,
  damage,
  countAdjustment,
  manualAdjustment,
}

extension MovementLabel on MovementType {
  String get value => switch (this) {
    MovementType.stockIn => 'STOCK_IN',
    MovementType.stockOut => 'STOCK_OUT',
    MovementType.returnItem => 'RETURN',
    MovementType.countAdjustment => 'COUNT_ADJUSTMENT',
    MovementType.manualAdjustment => 'MANUAL_ADJUSTMENT',
    MovementType.productionConsumption => 'PRODUCTION_CONSUMPTION',
    _ => name.toUpperCase(),
  };

  String get displayLabel => switch (this) {
    MovementType.purchase => 'Satın Alma',
    MovementType.sale => 'Satış',
    MovementType.stockIn => 'Stok Girişi',
    MovementType.stockOut => 'Stok Çıkışı',
    MovementType.transfer => 'Transfer',
    MovementType.production => 'Üretim',
    MovementType.productionConsumption => 'Üretim Tüketimi',
    MovementType.returnItem => 'İade',
    MovementType.damage => 'Hasar/Zayi',
    MovementType.countAdjustment => 'Sayım Düzeltmesi',
    MovementType.manualAdjustment => 'Manuel Düzeltme',
  };

  static MovementType fromString(String s) {
    for (final t in MovementType.values) {
      if (t.value == s.toUpperCase()) return t;
    }
    return MovementType.manualAdjustment;
  }
}

// ─── Product ─────────────────────────────────────────────────────────────────

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.stock,
    required this.minimumStock,
    required this.criticalStock,
    this.barcode,
    this.unit = 'adet',
    this.warehouseId,
    this.locationLabel,
    this.category,
    this.brand,
    this.supplierId,
    this.description,
    this.photoUrl,
    this.purchasePrice,
    this.salePrice,
    this.averageCost,
    this.isDeleted = false,
  });

  final String id, name, sku, unit;
  final String? barcode, warehouseId, locationLabel;
  final String? category, brand, supplierId, description, photoUrl;
  final num stock, minimumStock, criticalStock;
  final num? purchasePrice, salePrice, averageCost;
  final bool isDeleted;

  bool get isCritical => stock <= criticalStock;
  bool get isLow => stock > criticalStock && stock <= minimumStock;
  bool get isOutOfStock => stock <= 0;

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Product(
      id: doc.id,
      name: d['name'] ?? '',
      sku: d['sku'] ?? '',
      barcode: d['barcode'],
      stock: d['currentStock'] ?? 0,
      minimumStock: d['minimumStock'] ?? 0,
      criticalStock: d['criticalStock'] ?? 0,
      unit: d['unit'] ?? 'adet',
      warehouseId: d['warehouseId'],
      locationLabel: d['locationLabel'],
      category: d['category'],
      brand: d['brand'],
      supplierId: d['supplierId'],
      description: d['description'],
      photoUrl: d['photoUrl'],
      purchasePrice: d['purchasePrice'],
      salePrice: d['salePrice'],
      averageCost: d['averageCost'],
      isDeleted: d['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'sku': sku,
    'barcode': barcode,
    'currentStock': stock,
    'minimumStock': minimumStock,
    'criticalStock': criticalStock,
    'unit': unit,
    'warehouseId': warehouseId,
    'locationLabel': locationLabel,
    'category': category,
    'brand': brand,
    'supplierId': supplierId,
    'description': description,
    'photoUrl': photoUrl,
    'purchasePrice': purchasePrice,
    'salePrice': salePrice,
    'averageCost': averageCost,
    'isDeleted': isDeleted,
  };

  Product copyWith({
    String? name,
    String? sku,
    String? barcode,
    num? stock,
    num? minimumStock,
    num? criticalStock,
    String? unit,
    String? warehouseId,
    String? locationLabel,
    String? category,
    String? brand,
    String? supplierId,
    String? description,
    String? photoUrl,
    num? purchasePrice,
    num? salePrice,
    num? averageCost,
    bool? isDeleted,
  }) => Product(
    id: id,
    name: name ?? this.name,
    sku: sku ?? this.sku,
    barcode: barcode ?? this.barcode,
    stock: stock ?? this.stock,
    minimumStock: minimumStock ?? this.minimumStock,
    criticalStock: criticalStock ?? this.criticalStock,
    unit: unit ?? this.unit,
    warehouseId: warehouseId ?? this.warehouseId,
    locationLabel: locationLabel ?? this.locationLabel,
    category: category ?? this.category,
    brand: brand ?? this.brand,
    supplierId: supplierId ?? this.supplierId,
    description: description ?? this.description,
    photoUrl: photoUrl ?? this.photoUrl,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    salePrice: salePrice ?? this.salePrice,
    averageCost: averageCost ?? this.averageCost,
    isDeleted: isDeleted ?? this.isDeleted,
  );
}

// ─── Warehouse ────────────────────────────────────────────────────────────────

class Warehouse {
  const Warehouse({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
  });

  final String id, name;
  final String? description;
  final bool isActive;

  factory Warehouse.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Warehouse(
      id: doc.id,
      name: d['name'] ?? '',
      description: d['description'],
      isActive: d['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'isActive': isActive,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

// ─── StockMovement ───────────────────────────────────────────────────────────

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.userId,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    required this.timestamp,
    this.warehouseId,
    this.reason = '',
    this.note = '',
    this.userName,
  });

  final String id, productId, productName, userId;
  final String? warehouseId, userName;
  final MovementType type;
  final num quantity, previousStock, newStock;
  final String reason, note;
  final DateTime timestamp;

  factory StockMovement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final ts = d['timestamp'];
    return StockMovement(
      id: doc.id,
      productId: d['productId'] ?? '',
      productName: d['productName'] ?? '',
      userId: d['userId'] ?? '',
      userName: d['userName'],
      warehouseId: d['warehouseId'],
      type: MovementLabel.fromString(d['type'] ?? 'MANUAL_ADJUSTMENT'),
      quantity: d['quantity'] ?? 0,
      previousStock: d['previousStock'] ?? 0,
      newStock: d['newStock'] ?? 0,
      reason: d['reason'] ?? '',
      note: d['note'] ?? '',
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}

// ─── UserProfile ─────────────────────────────────────────────────────────────

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName,
    this.photoUrl,
    this.isActive = true,
  });

  final String uid, email;
  final String? displayName, photoUrl;
  final UserRole role;
  final bool isActive;

  String get name => displayName ?? email.split('@').first;

  bool get isAdmin => role == UserRole.admin;
  bool get canManageProducts =>
      role == UserRole.admin || role == UserRole.manager;
  bool get canAdjustStock =>
      role == UserRole.admin ||
      role == UserRole.manager ||
      role == UserRole.warehouse;
  bool get canTransfer =>
      role == UserRole.admin ||
      role == UserRole.manager ||
      role == UserRole.warehouse;
  bool get canViewFinancials =>
      role == UserRole.admin ||
      role == UserRole.manager ||
      role == UserRole.accounting;

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return UserProfile(
      uid: doc.id,
      email: d['email'] ?? '',
      displayName: d['displayName'],
      photoUrl: d['photoUrl'],
      role: UserRoleLabel.fromString(d['role'] ?? 'viewer'),
      isActive: d['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'role': role.name,
    'isActive': isActive,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

// ─── StockCount ───────────────────────────────────────────────────────────────

class StockCountItem {
  StockCountItem({
    required this.product,
    this.countedQuantity = 0,
  });

  final Product product;
  num countedQuantity;

  num get difference => countedQuantity - product.stock;
  bool get hasDifference => difference != 0;
}
