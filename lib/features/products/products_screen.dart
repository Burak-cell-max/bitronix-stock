import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
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
          child: Text('Hata: $err',
              style: const TextStyle(color: Colors.redAccent)),
        ),
        data: (products) {
          var filtered = products.where((p) {
            final query = widget.searchQuery.toLowerCase();
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

          return Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: filters + new product button
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
                      label: 'Tükendi (${products.where((x) => x.isOutOfStock).length})',
                      isSelected: _filterType == 'out',
                      accentColor: const Color(0xFF64748B),
                      onTap: () => setState(() => _filterType = 'out'),
                    ),
                    const Spacer(),
                    Text('${filtered.length} ürün',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 13)),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProductFormScreen()),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Yeni Ürün'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF58220),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: const Row(
                    children: [
                      SizedBox(width: 44),
                      SizedBox(width: 16),
                      Expanded(
                          flex: 3,
                          child: _TableHeader('Ürün Adı / SKU')),
                      Expanded(flex: 2, child: _TableHeader('Barkod')),
                      Expanded(flex: 2, child: _TableHeader('Stok')),
                      Expanded(
                          flex: 2, child: _TableHeader('Depo / Lokasyon')),
                      SizedBox(width: 140),
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
                        left:
                            const BorderSide(color: Color(0xFF1E2333)),
                        right:
                            const BorderSide(color: Color(0xFF1E2333)),
                        bottom:
                            const BorderSide(color: Color(0xFF1E2333)),
                      ),
                    ),
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Filtre kriterlerine uygun ürün bulunamadı.',
                              style: TextStyle(
                                  color: Color(0xFF64748B), fontSize: 14),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, index) => const Divider(
                              color: Color(0xFF1E2333),
                              height: 1,
                            ),
                            itemBuilder: (context, i) {
                              final p = filtered[i];
                              return _ProductRow(
                                product: p,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProductDetailScreen(product: p),
                                  ),
                                ),
                                onEdit: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProductFormScreen(product: p),
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
        },
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
              child: const Icon(Icons.widgets_outlined,
                  color: Color(0xFF64748B), size: 18),
            ),
            const SizedBox(width: 14),
            // Name & SKU
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    product.sku.isNotEmpty ? product.sku : 'SKU yok',
                    style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontFamily: 'monospace'),
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
                    fontFamily: 'monospace'),
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
                        fontSize: 13),
                  ),
                  if (statusLabel != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: stockColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              color: stockColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
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
                        color: Color(0xFFCBD5E1), fontSize: 12),
                  ),
                  if (product.locationLabel != null)
                    Text(
                      product.locationLabel!,
                      style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontFamily: 'monospace'),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
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
            fontWeight: FontWeight.bold),
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
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
