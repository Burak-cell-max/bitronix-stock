import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models.dart';
import '../../core/pdf_export_service.dart';
import '../../core/providers.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _filterType = 'all';
  final _searchCtrl = TextEditingController();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );
  static final NumberFormat _numFormat = NumberFormat('#,##0.##', 'tr_TR');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF262C3D)),
        ),
        title: const Text(
          'Ürünü sil?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${product.name} ürününü silmek istediğine emin misin? Stok hareket geçmişi korunur.',
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
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
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ürünü Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(stockRepositoryProvider)!.deleteProduct(product.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ürün silindi.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ürün silinemedi. Yetkinizi kontrol edin.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: productsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFF58220)),
        ),
        error: (err, _) => Center(
          child: Text(
            'Hata: $err',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        data: (products) {
          final filtered = _applyFilters(products);
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700) {
                return _buildMobile(context, products, filtered);
              }
              return _buildDesktop(context, products, filtered);
            },
          );
        },
      ),
    );
  }

  List<Product> _applyFilters(List<Product> products) {
    final query =
        (_searchCtrl.text.isNotEmpty ? _searchCtrl.text : widget.searchQuery)
            .toLowerCase();
    var filtered = products.where((p) {
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query) ||
          (p.barcode ?? '').toLowerCase().contains(query) ||
          (p.category ?? '').toLowerCase().contains(query);
    }).toList();

    if (_filterType == 'critical') {
      filtered = filtered.where((p) => p.isCritical).toList();
    } else if (_filterType == 'low') {
      filtered = filtered.where((p) => p.isLow).toList();
    } else if (_filterType == 'out') {
      filtered = filtered.where((p) => p.isOutOfStock).toList();
    }
    return filtered;
  }

  Widget _buildMobile(
    BuildContext context,
    List<Product> products,
    List<Product> filtered,
  ) {
    final totalValue = filtered.fold<double>(0, (sum, p) {
      final price = p.averageCost ?? p.purchasePrice ?? 0;
      return sum + (p.stock * price).toDouble();
    });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ürün, SKU veya barkod ara...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF12151E),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1E2333)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1E2333)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFF58220),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Stok Raporu İndir (PDF)',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF10B981,
                  ).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFF10B981)),
                  ),
                ),
                onPressed: () => PdfExportService.exportStockReportPdf(filtered),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductFormScreen()),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF58220),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Total Value Indicator on Mobile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF12151E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2333)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} Ürün Listeleniyor',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Toplam Değer: ${_currencyFormat.format(totalValue)}',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tümü (${products.length})',
                  isSelected: _filterType == 'all',
                  onTap: () => setState(() => _filterType = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label:
                      'Kritik (${products.where((x) => x.isCritical).length})',
                  isSelected: _filterType == 'critical',
                  accentColor: const Color(0xFFEF4444),
                  onTap: () => setState(() => _filterType = 'critical'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Düşük (${products.where((x) => x.isLow).length})',
                  isSelected: _filterType == 'low',
                  accentColor: const Color(0xFFF59E0B),
                  onTap: () => setState(() => _filterType = 'low'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label:
                      'Tükendi (${products.where((x) => x.isOutOfStock).length})',
                  isSelected: _filterType == 'out',
                  accentColor: const Color(0xFF64748B),
                  onTap: () => setState(() => _filterType = 'out'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Ürün bulunamadı.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      return _MobileProductCard(
                        product: p,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: p),
                          ),
                        ),
                        onEdit: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductFormScreen(product: p),
                          ),
                        ),
                        onDelete: () => _confirmDelete(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(
    BuildContext context,
    List<Product> products,
    List<Product> filtered,
  ) {
    final totalQuantity = filtered.fold<num>(0, (sum, p) => sum + p.stock);
    final totalInventoryValue = filtered.fold<double>(0, (sum, p) {
      final price = p.averageCost ?? p.purchasePrice ?? 0;
      return sum + (p.stock * price).toDouble();
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Summary KPI Cards + Filter + Export
          Row(
            children: [
              _FilterChip(
                label: 'Tümü (${products.length})',
                isSelected: _filterType == 'all',
                onTap: () => setState(() => _filterType = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Kritik (${products.where((x) => x.isCritical).length})',
                isSelected: _filterType == 'critical',
                accentColor: const Color(0xFFEF4444),
                onTap: () => setState(() => _filterType = 'critical'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Düşük (${products.where((x) => x.isLow).length})',
                isSelected: _filterType == 'low',
                accentColor: const Color(0xFFF59E0B),
                onTap: () => setState(() => _filterType = 'low'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label:
                    'Tükendi (${products.where((x) => x.isOutOfStock).length})',
                isSelected: _filterType == 'out',
                accentColor: const Color(0xFF64748B),
                onTap: () => setState(() => _filterType = 'out'),
              ),
              const Spacer(),

              // Stock Summary Badges
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E2333)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF94A3B8),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Stok: ${_numFormat.format(totalQuantity)} adet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.payments_outlined,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Envanter Değeri: ${_currencyFormat.format(totalInventoryValue)}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Single-click PDF Export
              ElevatedButton.icon(
                onPressed: () => PdfExportService.exportStockReportPdf(filtered),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('Rapor İndir (PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
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
              const SizedBox(width: 10),

              // New Product Button
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductFormScreen()),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni Ürün'),
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
            ],
          ),
          const SizedBox(height: 16),

          // Table header
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF12151E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: const Color(0xFF1E2333)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: const Row(
              children: [
                SizedBox(width: 44),
                SizedBox(width: 16),
                Expanded(flex: 3, child: _TableHeader('Ürün Adı / SKU')),
                Expanded(flex: 2, child: _TableHeader('Barkod')),
                Expanded(flex: 2, child: _TableHeader('Stok Miktarı')),
                Expanded(flex: 2, child: _TableHeader('Birim Fiyat (Alış)')),
                Expanded(flex: 2, child: _TableHeader('Toplam Tutar')),
                Expanded(flex: 2, child: _TableHeader('Depo / Lokasyon')),
                SizedBox(width: 110),
              ],
            ),
          ),

          // Table body
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF12151E),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(
                  left: const BorderSide(color: Color(0xFF1E2333)),
                  right: const BorderSide(color: Color(0xFF1E2333)),
                  bottom: const BorderSide(color: Color(0xFF1E2333)),
                ),
              ),
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Filtre kriterlerine uygun ürün bulunamadı.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, index) =>
                          const Divider(color: Color(0xFF1E2333), height: 1),
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        return _ProductRow(
                          product: p,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(product: p),
                            ),
                          ),
                          onEdit: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductFormScreen(product: p),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Table Row ────────────────────────────────────────────────────────────────

class _ProductRow extends ConsumerWidget {
  const _ProductRow({
    required this.product,
    required this.onTap,
    required this.onEdit,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouses = ref.watch(warehousesProvider);
    final warehouseName = warehouses.whenOrNull(
      data: (ws) {
        if (product.warehouseId == null) return null;
        try {
          return ws.firstWhere((w) => w.id == product.warehouseId).name;
        } catch (_) {
          return null;
        }
      },
    );

    final isCritical = product.isCritical;
    final isLow = product.isLow;
    final isOut = product.isOutOfStock;
    final Color stockColor = isOut
        ? const Color(0xFF64748B)
        : isCritical
        ? const Color(0xFFEF4444)
        : isLow
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
    final String? statusLabel = isOut
        ? 'TÜKENDİ'
        : isCritical
        ? 'KRİTİK'
        : isLow
        ? 'DÜŞÜK'
        : null;

    final unitPrice =
        product.averageCost ??
        product.purchasePrice ??
        product.salePrice ??
        0;
    final totalValue = product.stock * unitPrice;

    return InkWell(
      onTap: onTap,
      hoverColor: const Color(0xFF1A1E2A),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Status indicator dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: stockColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF181C28),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF262C3D)),
              ),
              child: const Icon(
                Icons.widgets_outlined,
                color: Color(0xFF64748B),
                size: 18,
              ),
            ),
            const SizedBox(width: 14),

            // Name & SKU
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.sku.isNotEmpty ? product.sku : 'SKU yok',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            // Barcode
            Expanded(
              flex: 2,
              child: Text(
                product.barcode ?? '—',
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // Stock + Status
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Text(
                    '${product.stock} ${product.unit}',
                    style: TextStyle(
                      color: stockColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (statusLabel != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: stockColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: stockColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Unit Price
            Expanded(
              flex: 2,
              child: Text(
                unitPrice > 0 ? _currencyFormat.format(unitPrice) : '—',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Total Value
            Expanded(
              flex: 2,
              child: Text(
                totalValue > 0 ? _currencyFormat.format(totalValue) : '—',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Warehouse / location
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warehouseName ?? '—',
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                    ),
                  ),
                  if (product.locationLabel != null)
                    Text(
                      product.locationLabel!,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ),

            // Actions
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Düzenle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF58220),
                side: const BorderSide(color: Color(0xFF262C3D)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF64748B),
      fontSize: 11,
      fontWeight: FontWeight.bold,
    ),
  );
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

// ─── Mobile Product Card ──────────────────────────────────────────────────────

class _MobileProductCard extends ConsumerWidget {
  const _MobileProductCard({
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouses = ref.watch(warehousesProvider);
    final warehouseName = warehouses.whenOrNull(
      data: (ws) {
        if (product.warehouseId == null) return null;
        try {
          return ws.firstWhere((w) => w.id == product.warehouseId).name;
        } catch (_) {
          return null;
        }
      },
    );

    final isOut = product.isOutOfStock;
    final isCritical = product.isCritical;
    final isLow = product.isLow;
    final Color stockColor = isOut
        ? const Color(0xFF64748B)
        : isCritical
        ? const Color(0xFFEF4444)
        : isLow
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
    final String? statusLabel = isOut
        ? 'TÜKENDİ'
        : isCritical
        ? 'KRİTİK'
        : isLow
        ? 'DÜŞÜK'
        : null;

    final unitPrice =
        product.averageCost ??
        product.purchasePrice ??
        product.salePrice ??
        0;
    final totalValue = product.stock * unitPrice;

    final subtitle = [
      if (product.sku.isNotEmpty) 'SKU: ${product.sku}',
      ?warehouseName,
    ].join(' • ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF12151E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E2333)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: stockColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.widgets_outlined,
                    color: stockColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle.isEmpty ? 'SKU yok' : subtitle,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${product.stock} ${product.unit}',
                          style: TextStyle(
                            color: stockColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (statusLabel != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: stockColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: stockColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Color(0xFF1E2333), height: 1),
            const SizedBox(height: 8),

            // Price Breakdown & Actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Birim: ${unitPrice > 0 ? _currencyFormat.format(unitPrice) : '—'}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Toplam: ${totalValue > 0 ? _currencyFormat.format(totalValue) : '—'}',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Color(0xFFF58220),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
