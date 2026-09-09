import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

/// Workspace (şirket) içi rol — V1'deki ekip yetki modeli, artık workspace'e scoped.
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

/// Platform (SaaS) düzeyi rol — admin panelini ve kiracılar arası erişimi belirler.
/// Kayıt olan herkes [user]; yalnızca Bitronix personeli [admin]/[superAdmin].
enum PlatformRole { superAdmin, admin, user }

extension PlatformRoleX on PlatformRole {
  String get label => switch (this) {
    PlatformRole.superAdmin => 'Süper Admin',
    PlatformRole.admin => 'Admin',
    PlatformRole.user => 'Kullanıcı',
  };

  String get wire => name; // 'superAdmin' | 'admin' | 'user'

  static PlatformRole fromString(String? s) => switch (s) {
    'superAdmin' => PlatformRole.superAdmin,
    'admin' => PlatformRole.admin,
    _ => PlatformRole.user,
  };
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
    this.platformRole = PlatformRole.user,
    this.status = 'active',
    this.companyName,
    this.defaultWorkspaceId,
    this.lastLogin,
    this.createdAt,
  });

  final String uid, email;
  final String? displayName, photoUrl, companyName, defaultWorkspaceId;
  final UserRole role; // legacy V1 alanı — workspace rolü artık üyelikten okunur
  final bool isActive;
  final PlatformRole platformRole;
  final String status; // 'active' | 'suspended' | 'deleted'
  final DateTime? lastLogin, createdAt;

  String get name => displayName ?? email.split('@').first;

  bool get isSuspended => status == 'suspended';
  bool get isDeleted => status == 'deleted';
  /// Uygulamaya girişi engellenmiş herhangi bir durum.
  bool get isBlocked => status != 'active';
  bool get isPlatformAdmin =>
      platformRole == PlatformRole.superAdmin ||
      platformRole == PlatformRole.admin;
  bool get isSuperAdmin => platformRole == PlatformRole.superAdmin;
  bool get hasWorkspace =>
      defaultWorkspaceId != null && defaultWorkspaceId!.isNotEmpty;

  /// Geriye dönük uyumluluk: V1 "Kullanıcılar" ekranı bu getter'ı kullanıyor.
  /// V2'de "admin" = platform admin.
  bool get isAdmin => isPlatformAdmin;

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final ll = d['lastLogin'];
    final ca = d['createdAt'];
    return UserProfile(
      uid: doc.id,
      email: d['email'] ?? '',
      displayName: d['displayName'] ?? d['name'],
      photoUrl: d['photoUrl'],
      role: UserRoleLabel.fromString(d['role'] ?? 'viewer'),
      isActive: d['isActive'] ?? true,
      platformRole: PlatformRoleX.fromString(d['platformRole']),
      status: d['status'] ?? 'active',
      companyName: d['companyName'],
      defaultWorkspaceId: d['defaultWorkspaceId'],
      lastLogin: ll is Timestamp ? ll.toDate() : null,
      createdAt: ca is Timestamp ? ca.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'role': role.name,
    'isActive': isActive,
    'platformRole': platformRole.wire,
    'status': status,
    if (companyName != null) 'companyName': companyName,
    if (defaultWorkspaceId != null) 'defaultWorkspaceId': defaultWorkspaceId,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

// ─── Workspace (Şirket / Çalışma Alanı) ──────────────────────────────────────

class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.ownerUid,
    this.status = 'active',
    this.createdAt,
  });

  final String id, name, ownerUid, status;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  factory Workspace.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final c = d['createdAt'];
    return Workspace(
      id: doc.id,
      name: d['name'] ?? '',
      ownerUid: d['ownerUid'] ?? '',
      status: d['status'] ?? 'active',
      createdAt: c is Timestamp ? c.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'ownerUid': ownerUid,
    'status': status,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class WorkspaceMembership {
  const WorkspaceMembership({
    required this.uid,
    required this.role,
    this.email,
    this.name,
    this.addedAt,
  });

  final String uid;
  final UserRole role;
  final String? email, name;
  final DateTime? addedAt;

  String get label => name ?? email ?? uid;

  bool get isAdmin => role == UserRole.admin;
  bool get canManageProducts =>
      role == UserRole.admin || role == UserRole.manager;
  bool get canAdjustStock =>
      role == UserRole.admin ||
      role == UserRole.manager ||
      role == UserRole.warehouse;
  bool get canTransfer => canAdjustStock;
  bool get canViewFinancials =>
      role == UserRole.admin || role == UserRole.manager;

  factory WorkspaceMembership.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final a = d['addedAt'];
    return WorkspaceMembership(
      uid: doc.id,
      role: UserRoleLabel.fromString(d['role'] ?? 'viewer'),
      email: d['email'],
      name: d['name'],
      addedAt: a is Timestamp ? a.toDate() : null,
    );
  }
}

// ─── Workspace daveti (e-posta ile ekip üyeliği) ────────────────────────────

class WorkspaceInvite {
  const WorkspaceInvite({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    required this.email,
    required this.role,
    required this.invitedBy,
    this.status = 'pending',
    this.createdAt,
  });

  final String id, workspaceId, workspaceName, email, invitedBy, status;
  final UserRole role;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';

  factory WorkspaceInvite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final c = d['createdAt'];
    return WorkspaceInvite(
      id: doc.id,
      workspaceId: d['workspaceId'] ?? '',
      workspaceName: d['workspaceName'] ?? '',
      email: d['email'] ?? '',
      role: UserRoleLabel.fromString(d['role'] ?? 'viewer'),
      invitedBy: d['invitedBy'] ?? '',
      status: d['status'] ?? 'pending',
      createdAt: c is Timestamp ? c.toDate() : null,
    );
  }
}

// ─── Audit Log (platform kritik işlem kaydı) ────────────────────────────────

class AuditLog {
  const AuditLog({
    required this.id,
    required this.action,
    required this.actorUid,
    this.actorEmail,
    this.targetType,
    this.targetId,
    this.details = const {},
    this.timestamp,
  });

  final String id, action, actorUid;
  final String? actorEmail, targetType, targetId;
  final Map<String, dynamic> details;
  final DateTime? timestamp;

  factory AuditLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final t = d['timestamp'];
    return AuditLog(
      id: doc.id,
      action: d['action'] ?? '',
      actorUid: d['actorUid'] ?? '',
      actorEmail: d['actorEmail'],
      targetType: d['targetType'],
      targetId: d['targetId'],
      details: (d['details'] as Map?)?.cast<String, dynamic>() ?? const {},
      timestamp: t is Timestamp ? t.toDate() : null,
    );
  }
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
