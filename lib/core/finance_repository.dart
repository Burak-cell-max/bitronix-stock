import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'stock_api.dart';

enum FinanceType { income, expense, transfer }

class FinanceAccount {
  const FinanceAccount({
    required this.id,
    required this.name,
    required this.balance,
    required this.kind,
  });

  final String id, name, kind;
  final num balance;

  factory FinanceAccount.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data() ?? {};
    return FinanceAccount(
      id: d.id,
      name: x['name'] ?? '',
      kind: x['kind'] ?? 'Nakit',
      balance: x['balance'] ?? 0,
    );
  }
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.accountId,
    this.targetAccountId,
    this.category,
    this.status = 'ACTIVE',
    this.invoiceUrl,
    this.invoiceName,
  });

  final String id, description, accountId, status;
  final String? targetAccountId;
  final FinanceType type;
  final num amount;
  final DateTime date;
  final String? category;
  final String? invoiceUrl;
  final String? invoiceName;

  bool get hasInvoice => invoiceUrl != null && invoiceUrl!.isNotEmpty;

  factory FinanceTransaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data() ?? {};
    final t = x['date'];
    return FinanceTransaction(
      id: d.id,
      type: FinanceType.values.firstWhere(
        (v) => v.name == x['type'],
        orElse: () => FinanceType.expense,
      ),
      amount: x['amount'] ?? 0,
      description: x['description'] ?? '',
      date: t is Timestamp ? t.toDate() : DateTime.now(),
      accountId: x['accountId'] ?? '',
      targetAccountId: x['targetAccountId'],
      category: x['category'],
      status: x['status'] ?? 'ACTIVE',
      invoiceUrl: x['invoiceUrl'],
      invoiceName: x['invoiceName'],
    );
  }
}

class FinanceRepository {
  FinanceRepository(this._db, this.workspaceId);
  final FirebaseFirestore _db;
  final String workspaceId;

  DocumentReference<Map<String, dynamic>> get _ws =>
      _db.collection('workspaces').doc(workspaceId);
  CollectionReference<Map<String, dynamic>> get _accounts =>
      _ws.collection('finance_accounts');
  CollectionReference<Map<String, dynamic>> get _transactions =>
      _ws.collection('finance_transactions');

  Stream<List<FinanceAccount>> accounts() => _accounts
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(FinanceAccount.fromDoc).toList());

  Stream<List<FinanceTransaction>> transactions() => _transactions
      .orderBy('date', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs
          .map(FinanceTransaction.fromDoc)
          .where((t) => t.status == 'ACTIVE')
          .toList());

  Future<void> createAccount({
    required String name,
    required String kind,
    num initialBalance = 0,
  }) async {
    await _accounts.add({
      'name': name.trim(),
      'kind': kind.trim(),
      'balance': initialBalance,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAccount(String accountId) async {
    await _accounts.doc(accountId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> addTransaction({
    required FinanceType type,
    required num amount,
    required String description,
    required String accountId,
    required String userId,
    String? category,
    DateTime? date,
  }) => _db.runTransaction((tx) async {
    if (amount <= 0) throw ArgumentError('Tutar sıfırdan büyük olmalı');
    final account = _accounts.doc(accountId);
    final doc = await tx.get(account);
    if (!doc.exists) throw StateError('Finans hesabı bulunamadı');
    final delta = type == FinanceType.income ? amount : -amount;
    final entry = _transactions.doc();
    tx.update(account, {
      'balance': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    tx.set(entry, {
      'transactionId': entry.id,
      'type': type.name,
      'amount': amount,
      'description': description,
      'accountId': accountId,
      'category': category,
      'status': 'ACTIVE',
      'createdBy': userId,
      'date': date != null
          ? Timestamp.fromDate(date)
          : FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return entry.id;
  });

  /// Bir finans hareketine fatura/fiş dosyası yükler (kendi VPS'imiz) ve dokümana bağlar.
  /// `invoiceUrl` alanında artık `vps:<id>` referansı tutulur; gerçek dosya
  /// erişim-kontrollü olarak `stock-api/invoice` üzerinden sunulur.
  Future<void> uploadInvoice({
    required String transactionId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('${StockApi.base}/invoice');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(await StockApi.authHeaders())
      ..fields['workspaceId'] = workspaceId
      ..fields['txId'] = transactionId
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      final msg = _errText(body) ?? 'Fatura yükleme hatası (${streamed.statusCode})';
      throw StateError(msg);
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    await _transactions.doc(transactionId).update({
      'invoiceUrl': data['ref'] as String, // "vps:<id>"
      'invoiceName': (data['name'] as String?) ?? fileName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// `invoiceUrl` bir `vps:<id>` referansıysa, kısa süreli imzalı bir görüntüleme
  /// URL'si döndürür. Eski Cloudinary `https://` URL'leri olduğu gibi döner.
  Future<String?> resolveInvoiceUrl(String invoiceUrl) async {
    if (!invoiceUrl.startsWith('vps:')) return invoiceUrl;
    final res = await http.get(
      Uri.parse('${StockApi.base}/invoice?ref=${Uri.encodeComponent(invoiceUrl)}'),
      headers: await StockApi.authHeaders(),
    );
    if (res.statusCode != 200) return null;
    return (jsonDecode(res.body) as Map<String, dynamic>)['url'] as String?;
  }

  static String? _errText(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map && m['error'] is String) return m['error'] as String;
    } catch (_) {}
    return null;
  }

  Future<String> addTransfer({
    required String fromAccountId,
    required String toAccountId,
    required num amount,
    required String description,
    required String userId,
    DateTime? date,
  }) => _db.runTransaction((tx) async {
    if (amount <= 0) throw ArgumentError('Tutar sıfırdan büyük olmalı');
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Kaynak ve hedef hesap aynı olamaz');
    }
    final fromRef = _accounts.doc(fromAccountId);
    final toRef = _accounts.doc(toAccountId);
    final fromDoc = await tx.get(fromRef);
    final toDoc = await tx.get(toRef);
    if (!fromDoc.exists || !toDoc.exists) {
      throw StateError('Seçilen hesaplardan biri bulunamadı');
    }

    final entry = _transactions.doc();
    tx.update(fromRef, {
      'balance': FieldValue.increment(-amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    tx.update(toRef, {
      'balance': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    tx.set(entry, {
      'transactionId': entry.id,
      'type': FinanceType.transfer.name,
      'amount': amount,
      'description': description.trim().isEmpty
          ? 'Hesaplar Arası Virman / Transfer'
          : description.trim(),
      'accountId': fromAccountId,
      'targetAccountId': toAccountId,
      'category': 'Transfer / Virman',
      'status': 'ACTIVE',
      'createdBy': userId,
      'date': date != null
          ? Timestamp.fromDate(date)
          : FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return entry.id;
  });

  Future<void> deleteTransaction(FinanceTransaction txItem) =>
      _db.runTransaction((tx) async {
        final txDoc = _transactions.doc(txItem.id);
        final snap = await tx.get(txDoc);
        if (!snap.exists) return;

        if (txItem.type == FinanceType.transfer) {
          final targetAccountId = snap.data()?['targetAccountId'];
          final fromRef = _accounts.doc(txItem.accountId);
          tx.update(fromRef, {
            'balance': FieldValue.increment(txItem.amount),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (targetAccountId != null &&
              targetAccountId is String &&
              targetAccountId.isNotEmpty) {
            final toRef =
                _accounts.doc(targetAccountId);
            tx.update(toRef, {
              'balance': FieldValue.increment(-txItem.amount),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } else {
          final accountRef =
              _accounts.doc(txItem.accountId);
          final delta = txItem.type == FinanceType.income
              ? -txItem.amount
              : txItem.amount;
          tx.update(accountRef, {
            'balance': FieldValue.increment(delta),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        tx.update(txDoc, {
          'status': 'CANCELLED',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
}
