import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/finance_repository.dart';
import '../../core/providers.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  String _filterType = 'all'; // all, income, expense, transfer
  String _searchQuery = '';

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

  @override
  Widget build(BuildContext context) {
    final membership = ref
        .watch(currentMembershipProvider)
        .whenOrNull(data: (value) => value);

    if (membership != null && !membership.canViewFinancials) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0D12),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 12),
              const Text(
                'Yetkisiz Erişim',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Finans verilerini yalnızca Yönetici (Admin) ve Müdür (Manager) görebilir.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final accountsAsync = ref.watch(financeAccountsProvider);
    final transactionsAsync = ref.watch(financeTransactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      // Mobilde ayrı bir sayfa olarak açılıyor; geri butonu ve başlık için
      // AppBar gerekiyor. Masaüstünde kabuğun içine gömülü olduğundan AppBar yok.
      appBar: isMobile
          ? AppBar(
              backgroundColor: const Color(0xFF0D1017),
              elevation: 0,
              foregroundColor: Colors.white,
              title: const Text(
                'Finans Yönetimi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: accountsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFF58220)),
        ),
        error: (e, _) => Center(
          child: Text(
            'Hata: $e',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        data: (accounts) {
          final totalBalance = accounts.fold<num>(
            0,
            (val, a) => val + a.balance,
          );

          return transactionsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFFF58220)),
            ),
            error: (e, _) => Center(
              child: Text(
                'Hata: $e',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
            data: (transactions) {
              final totalIncome = transactions
                  .where((t) => t.type == FinanceType.income)
                  .fold<num>(0, (val, t) => val + t.amount);

              final totalExpense = transactions
                  .where((t) => t.type == FinanceType.expense)
                  .fold<num>(0, (val, t) => val + t.amount);

              var filteredTransactions = transactions.where((t) {
                if (_filterType == 'income') {
                  return t.type == FinanceType.income;
                }
                if (_filterType == 'expense') {
                  return t.type == FinanceType.expense;
                }
                if (_filterType == 'transfer') {
                  return t.type == FinanceType.transfer;
                }
                return true;
              }).where((t) {
                if (_searchQuery.isEmpty) return true;
                final q = _searchQuery.toLowerCase();
                return t.description.toLowerCase().contains(q) ||
                    (t.category ?? '').toLowerCase().contains(q);
              }).toList();

              final headerTitle = const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finans Yönetimi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Kasa, banka hesapları ve gelir/gider hareketleri',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              );
              final headerButtons = [
                OutlinedButton.icon(
                  onPressed: () => _openAccountDialog(context),
                  icon: const Icon(
                    Icons.account_balance_outlined,
                    size: 16,
                  ),
                  label: const Text('Yeni Hesap / Kasa'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFCBD5E1),
                    side: const BorderSide(color: Color(0xFF262C3D)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _openTransactionDialog(context, accounts),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('İşlem Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF58220),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ];

              return SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header & Action buttons
                    if (isMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Kasa, banka hesapları ve gelir/gider hareketleri',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          headerButtons[1],
                          const SizedBox(height: 10),
                          headerButtons[0],
                        ],
                      )
                    else
                      Row(
                        children: [
                          headerTitle,
                          const Spacer(),
                          headerButtons[0],
                          const SizedBox(width: 10),
                          headerButtons[1],
                        ],
                      ),
                    const SizedBox(height: 20),

                    // Metric Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Mobilde 2 sütun, masaüstünde sabit 220px kartlar.
                        final cardWidth = isMobile
                            ? (constraints.maxWidth - 14) / 2
                            : 220.0;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _FinanceStatCard(
                              width: cardWidth,
                              label: 'Toplam Bakiye',
                              value: _currencyFormat.format(totalBalance),
                              icon: Icons.account_balance_wallet_rounded,
                              color: const Color(0xFFF58220),
                            ),
                            _FinanceStatCard(
                              width: cardWidth,
                              label: 'Toplam Gelir',
                              value: _currencyFormat.format(totalIncome),
                              icon: Icons.arrow_downward_rounded,
                              color: const Color(0xFF10B981),
                            ),
                            _FinanceStatCard(
                              width: cardWidth,
                              label: 'Toplam Gider',
                              value: _currencyFormat.format(totalExpense),
                              icon: Icons.arrow_upward_rounded,
                              color: const Color(0xFFEF4444),
                            ),
                            _FinanceStatCard(
                              width: cardWidth,
                              label: 'Aktif Hesap Sayısı',
                              value: '${accounts.length}',
                              icon: Icons.account_balance_rounded,
                              color: const Color(0xFF3B82F6),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // Accounts Section
                    const Text(
                      'Kasa ve Banka Hesapları',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (accounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF12151E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1E2333)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Tanımlı kasa veya banka hesabı bulunmuyor. "Yeni Hesap / Kasa" butonuna tıklayarak ilk hesabınızı açın.',
                                style: TextStyle(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _openAccountDialog(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF58220),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Hesap Aç'),
                            ),
                          ],
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 320,
                              mainAxisExtent: 94,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: accounts.length,
                        itemBuilder: (context, i) {
                          final acc = accounts[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF12151E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF1E2333),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF58220,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_rounded,
                                    color: Color(0xFFF58220),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        acc.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        acc.kind,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _currencyFormat.format(acc.balance),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    iconSize: 15,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Color(0xFF64748B),
                                    ),
                                    tooltip: 'Hesabı Sil',
                                    onPressed: () => _confirmDeleteAccount(acc),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 32),

                    // Transactions Filter & List
                    Builder(
                      builder: (context) {
                        final title = const Text(
                          'Finansal Hareketler',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                        final searchField = SizedBox(
                          width: isMobile ? double.infinity : 220,
                          height: 36,
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Açıklama / Kategori ara...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF64748B),
                                size: 16,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF12151E),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF1E2333),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF1E2333),
                                ),
                              ),
                            ),
                          ),
                        );
                        if (isMobile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              title,
                              const SizedBox(height: 10),
                              searchField,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            title,
                            const Spacer(),
                            searchField,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips
                    Wrap(
                      spacing: 8,
                      children: [
                        _FilterChip(
                          label: 'Tümü (${transactions.length})',
                          isSelected: _filterType == 'all',
                          onTap: () => setState(() => _filterType = 'all'),
                        ),
                        _FilterChip(
                          label:
                              'Gelirler (${transactions.where((t) => t.type == FinanceType.income).length})',
                          isSelected: _filterType == 'income',
                          accentColor: const Color(0xFF10B981),
                          onTap: () => setState(() => _filterType = 'income'),
                        ),
                        _FilterChip(
                          label:
                              'Giderler (${transactions.where((t) => t.type == FinanceType.expense).length})',
                          isSelected: _filterType == 'expense',
                          accentColor: const Color(0xFFEF4444),
                          onTap: () => setState(() => _filterType = 'expense'),
                        ),
                        _FilterChip(
                          label:
                              'Transferler (${transactions.where((t) => t.type == FinanceType.transfer).length})',
                          isSelected: _filterType == 'transfer',
                          accentColor: const Color(0xFF3B82F6),
                          onTap: () => setState(() => _filterType = 'transfer'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Transactions Table / List
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF12151E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E2333)),
                      ),
                      child: filteredTransactions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(28),
                              child: Center(
                                child: Text(
                                  'Kayıtlı finans hareketi bulunamadı.',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredTransactions.length,
                              separatorBuilder: (_, _) => const Divider(
                                color: Color(0xFF1E2333),
                                height: 1,
                              ),
                              itemBuilder: (context, i) {
                                final tx = filteredTransactions[i];
                                final isIncome = tx.type == FinanceType.income;
                                final isTransfer =
                                    tx.type == FinanceType.transfer;
                                final color = isIncome
                                    ? const Color(0xFF10B981)
                                    : isTransfer
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFFEF4444);

                                final icon = isIncome
                                    ? Icons.arrow_downward_rounded
                                    : isTransfer
                                    ? Icons.swap_horiz_rounded
                                    : Icons.arrow_upward_rounded;

                                final accountName = accounts
                                    .cast<FinanceAccount?>()
                                    .firstWhere(
                                      (a) => a?.id == tx.accountId,
                                      orElse: () => null,
                                    )
                                    ?.name;

                                final amountText = Text(
                                  '${isIncome ? '+' : isTransfer ? '' : '-'}${_currencyFormat.format(tx.amount)}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                );
                                final subtitleParts = <String>[
                                  _dateFormat.format(tx.date),
                                  ?accountName,
                                  ?tx.category,
                                ];

                                if (isMobile) {
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: color.withValues(
                                        alpha: 0.15,
                                      ),
                                      child: Icon(icon, color: color, size: 16),
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            tx.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (tx.hasInvoice) ...[
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.attach_file_rounded,
                                            size: 13,
                                            color: Color(0xFFF58220),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(
                                      subtitleParts.join(' • '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        amountText,
                                        PopupMenuButton<String>(
                                          icon: const Icon(
                                            Icons.more_vert_rounded,
                                            size: 18,
                                            color: Color(0xFF64748B),
                                          ),
                                          color: const Color(0xFF161922),
                                          onSelected: (v) {
                                            if (v == 'invoice') {
                                              tx.hasInvoice
                                                  ? _openInvoice(tx)
                                                  : _pickAndUploadInvoice(tx);
                                            } else if (v == 'delete') {
                                              _confirmDeleteTx(tx);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            PopupMenuItem(
                                              value: 'invoice',
                                              child: Text(
                                                tx.hasInvoice
                                                    ? 'Faturayı Görüntüle'
                                                    : 'Fatura Yükle',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text(
                                                'İşlemi İptal Et / Sil',
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: color.withValues(
                                      alpha: 0.15,
                                    ),
                                    child: Icon(icon, color: color, size: 16),
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          tx.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      if (tx.hasInvoice) ...[
                                        const SizedBox(width: 8),
                                        Tooltip(
                                          message: tx.invoiceName ?? 'Fatura',
                                          child: const Icon(
                                            Icons.attach_file_rounded,
                                            size: 14,
                                            color: Color(0xFFF58220),
                                          ),
                                        ),
                                      ],
                                      if (tx.category != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E2333),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            tx.category!,
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${_dateFormat.format(tx.date)}${accountName != null ? ' • $accountName' : ''}',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      amountText,
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: Icon(
                                          tx.hasInvoice
                                              ? Icons.visibility_outlined
                                              : Icons.upload_file_rounded,
                                          size: 16,
                                          color: tx.hasInvoice
                                              ? const Color(0xFFF58220)
                                              : const Color(0xFF64748B),
                                        ),
                                        tooltip: tx.hasInvoice
                                            ? 'Faturayı Görüntüle'
                                            : 'Fatura Yükle',
                                        onPressed: () => tx.hasInvoice
                                            ? _openInvoice(tx)
                                            : _pickAndUploadInvoice(tx),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 16,
                                          color: Color(0xFF64748B),
                                        ),
                                        tooltip: 'İşlemi İptal Et / Sil',
                                        onPressed: () => _confirmDeleteTx(tx),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openAccountDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    String kind = 'Nakit';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161922),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF262C3D)),
          ),
          title: const Text(
            'Yeni Kasa / Banka Hesabı',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Hesap Adı (örn: Ana Kasa, Ziraat Bankası)',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Color(0xFF0B0D12),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(
                  labelText: 'Hesap Türü',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Color(0xFF0B0D12),
                ),
                dropdownColor: const Color(0xFF161922),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'Nakit', child: Text('Nakit Kasa')),
                  DropdownMenuItem(
                    value: 'Banka',
                    child: Text('Banka Hesabı'),
                  ),
                  DropdownMenuItem(value: 'POS', child: Text('POS Hesabı')),
                  DropdownMenuItem(
                    value: 'Kredi Kartı',
                    child: Text('Şirket Kredi Kartı'),
                  ),
                ],
                onChanged: (v) => setDialogState(() => kind = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Başlangıç Bakiyesi (₺)',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Color(0xFF0B0D12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'İptal',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF58220),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final initBal = num.tryParse(balanceCtrl.text) ?? 0;
                if (name.isEmpty) return;

                await ref
                    .read(financeRepositoryProvider)!
                    .createAccount(
                      name: name,
                      kind: kind,
                      initialBalance: initBal,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Hesap Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  void _openTransactionDialog(
    BuildContext context,
    List<FinanceAccount> accounts,
  ) {
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İşlem eklemek için önce bir hesap oluşturmalısınız.'),
        ),
      );
      return;
    }

    FinanceType type = FinanceType.expense;
    String? accountId = accounts.first.id;
    String? targetAccountId = accounts.length > 1 ? accounts[1].id : null;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? category = 'Genel';
    PlatformFile? invoiceFile;
    bool saving = false;

    const incomeCategories = [
      'Satış Geliri',
      'Müşteri Tahsilatı',
      'Hizmet Geliri',
      'Faiz / Ek Gelir',
      'Diğer Gelir',
    ];
    const expenseCategories = [
      'Hammadde / Tedarikçi',
      'Maaş / Personel',
      'Kira',
      'Fatura (Elektrik/Su/İnternet)',
      'Lojistik / Kargo',
      'Vergi / Harç',
      'Yemek / Mutfak',
      'Genel Gider',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161922),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF262C3D)),
          ),
          title: const Text(
            'Finansal İşlem Ekle',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: SizedBox(
            width: math.min(420.0, MediaQuery.sizeOf(ctx).width - 64),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<FinanceType>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'İşlem Türü',
                    labelStyle: TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: Color(0xFF0B0D12),
                  ),
                  dropdownColor: const Color(0xFF161922),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: FinanceType.income,
                      child: Text('Gelir Girişi (+)'),
                    ),
                    DropdownMenuItem(
                      value: FinanceType.expense,
                      child: Text('Gider Çıkışı (-)'),
                    ),
                    DropdownMenuItem(
                      value: FinanceType.transfer,
                      child: Text('Hesaplar Arası Virman / Transfer'),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() {
                    type = v!;
                    category = type == FinanceType.income
                        ? incomeCategories.first
                        : type == FinanceType.expense
                        ? expenseCategories.first
                        : 'Transfer';
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: accountId,
                  decoration: InputDecoration(
                    labelText: type == FinanceType.transfer
                        ? 'Kaynak Hesap (Çıkış)'
                        : 'Hesap',
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFF0B0D12),
                  ),
                  dropdownColor: const Color(0xFF161922),
                  style: const TextStyle(color: Colors.white),
                  items: accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.name} (${a.kind})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => accountId = v),
                ),
                if (type == FinanceType.transfer) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: targetAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Hedef Hesap (Giriş)',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: Color(0xFF0B0D12),
                    ),
                    dropdownColor: const Color(0xFF161922),
                    style: const TextStyle(color: Colors.white),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.name} (${a.kind})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => targetAccountId = v),
                  ),
                ],
                if (type != FinanceType.transfer) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: Color(0xFF0B0D12),
                    ),
                    dropdownColor: const Color(0xFF161922),
                    style: const TextStyle(color: Colors.white),
                    items: (type == FinanceType.income
                            ? incomeCategories
                            : expenseCategories)
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => category = v),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Tutar (₺)',
                    labelStyle: TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: Color(0xFF0B0D12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    labelStyle: TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: Color(0xFF0B0D12),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await FilePicker.pickFile(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
                    );
                    if (picked != null) {
                      setDialogState(() => invoiceFile = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0D12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF262C3D)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          invoiceFile != null
                              ? Icons.check_circle_rounded
                              : Icons.attach_file_rounded,
                          size: 16,
                          color: invoiceFile != null
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            invoiceFile?.name ??
                                'Fatura / Fiş Ekle (opsiyonel, PDF/görsel)',
                            style: TextStyle(
                              color: invoiceFile != null
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'İptal',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF58220),
                foregroundColor: Colors.white,
              ),
              onPressed: saving
                  ? null
                  : () async {
                final amount = num.tryParse(amountCtrl.text) ?? 0;
                final desc = descCtrl.text.trim();
                final user = FirebaseAuth.instance.currentUser;
                if (amount <= 0 || accountId == null) return;

                setDialogState(() => saving = true);
                String? newTransactionId;

                if (type == FinanceType.transfer) {
                  if (targetAccountId == null ||
                      accountId == targetAccountId) {
                    setDialogState(() => saving = false);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Kaynak ve hedef hesap farklı olmalı.'),
                      ),
                    );
                    return;
                  }
                  newTransactionId = await ref
                      .read(financeRepositoryProvider)!
                      .addTransfer(
                        fromAccountId: accountId!,
                        toAccountId: targetAccountId!,
                        amount: amount,
                        description: desc,
                        userId: user?.uid ?? 'unknown',
                      );
                } else {
                  newTransactionId = await ref
                      .read(financeRepositoryProvider)!
                      .addTransaction(
                        type: type,
                        amount: amount,
                        description: desc.isNotEmpty ? desc : (category ?? ''),
                        accountId: accountId!,
                        category: category,
                        userId: user?.uid ?? 'unknown',
                      );
                }

                if (invoiceFile != null) {
                  try {
                    await ref.read(financeRepositoryProvider)!.uploadInvoice(
                          transactionId: newTransactionId,
                          bytes: await invoiceFile!.readAsBytes(),
                          fileName: invoiceFile!.name,
                        );
                  } catch (_) {
                    // İşlem zaten kaydedildi; fatura daha sonra listeden tekrar yüklenebilir.
                  }
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTx(FinanceTransaction tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF262C3D)),
        ),
        title: const Text(
          'İşlemi İptal Et?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bu işlem silinecek ve ilgili hesabın bakiyesi otomatik olarak düzeltilecektir.\n\nTutar: ${_currencyFormat.format(tx.amount)}',
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('İşlemi İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(financeRepositoryProvider)!.deleteTransaction(tx);
    }
  }

  void _confirmDeleteAccount(FinanceAccount acc) async {
    final hasBalance = acc.balance != 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF262C3D)),
        ),
        title: const Text(
          'Hesabı Sil?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"${acc.name}" hesabı listeden kaldırılacak. Geçmiş hareketler '
          'silinmez.'
          '${hasBalance ? '\n\nDikkat: Hesap bakiyesi ${_currencyFormat.format(acc.balance)}. Silmeden önce bakiyeyi sıfırlamanız (virman/işlem) önerilir.' : ''}',
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(financeRepositoryProvider)!.deleteAccount(acc.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${acc.name}" hesabı silindi.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hesap silinemedi: $e')),
          );
        }
      }
    }
  }

  Future<void> _openInvoice(FinanceTransaction tx) async {
    final invoiceRef = tx.invoiceUrl;
    if (invoiceRef == null) return;
    final repo = ref.read(financeRepositoryProvider);
    String? url;
    try {
      url = repo != null ? await repo.resolveInvoiceUrl(invoiceRef) : invoiceRef;
    } catch (e) {
      url = null;
    }
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fatura açılamadı.')),
        );
      }
    }
  }

  Future<void> _pickAndUploadInvoice(FinanceTransaction tx) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (file == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fatura yükleniyor...')),
      );
    }
    try {
      await ref.read(financeRepositoryProvider)!.uploadInvoice(
            transactionId: tx.id,
            bytes: await file.readAsBytes(),
            fileName: file.name,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fatura yüklendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fatura yüklenemedi: $e')),
        );
      }
    }
  }
}

class _FinanceStatCard extends StatelessWidget {
  const _FinanceStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.width = 220,
  });

  final String label, value;
  final IconData icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final activeColor = accentColor ?? const Color(0xFFF58220);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : const Color(0xFF12151E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.6)
                : const Color(0xFF1E2333),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
