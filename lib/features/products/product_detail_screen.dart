import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.product});
  final Product product;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late Product _product;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  @override
  Widget build(BuildContext context) {
    // Anlık veri için stream izle
    final movementsAsync = ref.watch(movementsByProductProvider(_product.id));
    final warehouses = ref.watch(warehousesProvider);
    final warehouseName = warehouses.whenOrNull(
      data: (ws) {
        if (_product.warehouseId == null) return null;
        try {
          return ws.firstWhere((w) => w.id == _product.warehouseId).name;
        } catch (_) {
          return null;
        }
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12151E),
        foregroundColor: Colors.white,
        title: Text(
          _product.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Ürünü sil',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            onPressed: _deleteProduct,
          ),
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              final updated = await Navigator.push<Product>(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductFormScreen(product: _product),
                ),
              );
              if (updated != null && mounted) {
                setState(() => _product = updated);
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          return SingleChildScrollView(
            padding: EdgeInsets.all(isWide ? 24 : 16),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                // Sol panel: Ürün bilgileri
                SizedBox(
                  width: isWide
                      ? (constraints.maxWidth - 24) * .6
                      : constraints.maxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StockStatusBanner(product: _product),
                      const SizedBox(height: 20),
                      _InfoCard(
                        title: 'Temel Bilgiler',
                        icon: Icons.info_outline_rounded,
                        children: [
                          _InfoRow('Ürün Adı', _product.name),
                          _InfoRow('SKU', _product.sku),
                          _InfoRow('Barkod', _product.barcode ?? '—'),
                          _InfoRow('Kategori', _product.category ?? '—'),
                          _InfoRow('Marka', _product.brand ?? '—'),
                          _InfoRow('Birim', _product.unit),
                          _InfoRow('Açıklama', _product.description ?? '—'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoCard(
                        title: 'Stok & Depo',
                        icon: Icons.inventory_2_outlined,
                        children: [
                          _InfoRow(
                            'Mevcut Stok',
                            '${_product.stock} ${_product.unit}',
                            highlight: true,
                          ),
                          _InfoRow(
                            'Minimum Stok',
                            '${_product.minimumStock} ${_product.unit}',
                          ),
                          _InfoRow(
                            'Kritik Stok',
                            '${_product.criticalStock} ${_product.unit}',
                          ),
                          _InfoRow('Depo', warehouseName ?? '—'),
                          _InfoRow(
                            'Raf / Lokasyon',
                            _product.locationLabel ?? '—',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoCard(
                        title: 'Fiyat & Maliyet',
                        icon: Icons.attach_money_rounded,
                        children: [
                          _InfoRow(
                            'Alış Fiyatı',
                            _product.purchasePrice != null
                                ? '${_product.purchasePrice!.toStringAsFixed(2)} ₺'
                                : '—',
                          ),
                          _InfoRow(
                            'Ortalama Maliyet',
                            _product.averageCost != null
                                ? '${_product.averageCost!.toStringAsFixed(2)} ₺'
                                : '—',
                          ),
                          _InfoRow(
                            'Satış Fiyatı',
                            _product.salePrice != null
                                ? '${_product.salePrice!.toStringAsFixed(2)} ₺'
                                : '—',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Hızlı stok işlemi
                      _QuickAdjustPanel(product: _product),
                    ],
                  ),
                ),
                SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 16),
                // Sağ panel: QR, hareket geçmişi
                SizedBox(
                  width: isWide
                      ? (constraints.maxWidth - 24) * .4
                      : constraints.maxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // QR Kodu
                      _InfoCard(
                        title: 'QR Kod & Barkod',
                        icon: Icons.qr_code_2_rounded,
                        children: [
                          Center(
                            child: QrImageView(
                              data: _product.sku.isNotEmpty
                                  ? _product.sku
                                  : _product.id,
                              version: QrVersions.auto,
                              size: 160,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              _product.sku.isNotEmpty
                                  ? _product.sku
                                  : _product.id,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: _product.sku.isNotEmpty
                                      ? _product.sku
                                      : _product.id,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('SKU panoya kopyalandı.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('SKU Kopyala'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF262C3D)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Son Hareketler
                      _InfoCard(
                        title: 'Son Stok Hareketleri',
                        icon: Icons.history_rounded,
                        children: [
                          movementsAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFF58220),
                              ),
                            ),
                            error: (e, _) => Text(
                              '$e',
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                            data: (movements) {
                              if (movements.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Henüz hareket yok.',
                                    style: TextStyle(color: Color(0xFF64748B)),
                                  ),
                                );
                              }
                              return Column(
                                children: movements
                                    .take(10)
                                    .map((m) => _MovementRow(movement: m))
                                    .toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ürünü sil?'),
        content: Text(
          '${_product.name} ürününü silmek istediğine emin misin? Stok hareketleri silinmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ürünü Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(stockRepositoryProvider)!.deleteProduct(_product.id);
      if (mounted) {
        Navigator.pop(context);
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
}

// ─── Sub Widgets ──────────────────────────────────────────────────────────────

class _StockStatusBanner extends StatelessWidget {
  const _StockStatusBanner({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (product.isOutOfStock) {
      statusColor = const Color(0xFF64748B);
      statusLabel = 'TÜKENDİ';
      statusIcon = Icons.remove_shopping_cart_rounded;
    } else if (product.isCritical) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'KRİTİK STOK';
      statusIcon = Icons.warning_amber_rounded;
    } else if (product.isLow) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'DÜŞÜK STOK';
      statusIcon = Icons.arrow_downward_rounded;
    } else {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'STOK NORMAL';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                'Mevcut Stok: ${product.stock} ${product.unit}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2333)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFFF58220)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF1E2333), height: 1),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.highlight = false});
  final String label, value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MediaQuery.sizeOf(context).width < 500 ? 96 : 140,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: highlight ? const Color(0xFFF58220) : Colors.white,
                fontSize: 13,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});
  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final isPositive = movement.quantity > 0;
    final color = isPositive
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${isPositive ? '+' : ''}${movement.quantity}',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.type.displayLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  '${movement.timestamp.day.toString().padLeft(2, '0')}.${movement.timestamp.month.toString().padLeft(2, '0')}.${movement.timestamp.year} ${movement.timestamp.hour.toString().padLeft(2, '0')}:${movement.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${movement.previousStock} → ${movement.newStock}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _QuickAdjustPanel extends ConsumerStatefulWidget {
  const _QuickAdjustPanel({required this.product});
  final Product product;

  @override
  ConsumerState<_QuickAdjustPanel> createState() => _QuickAdjustPanelState();
}

class _QuickAdjustPanelState extends ConsumerState<_QuickAdjustPanel> {
  bool _isBusy = false;

  Future<void> _adjust(num delta) async {
    setState(() => _isBusy = true);
    final user = FirebaseAuth.instance.currentUser;
    try {
      await ref.read(stockRepositoryProvider)!.adjustStock(
        product: widget.product,
        quantity: delta,
        type: delta > 0 ? MovementType.stockIn : MovementType.stockOut,
        userId: user?.uid ?? 'unknown',
        userName: user?.email,
        reason: 'Ürün detay hızlı işlem',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.product.name}: ${delta > 0 ? '+' : ''}$delta adet işlendi.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2333)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFFF58220)),
              SizedBox(width: 8),
              Text(
                'Hızlı Stok İşlemi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in [1, 5, 10, 50])
                _AdjBtn(
                  '+$n',
                  const Color(0xFF10B981),
                  _isBusy,
                  () => _adjust(n),
                ),
              for (final n in [1, 5, 10, 50])
                _AdjBtn(
                  '-$n',
                  const Color(0xFFEF4444),
                  _isBusy,
                  () => _adjust(-n),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdjBtn extends StatelessWidget {
  const _AdjBtn(this.label, this.color, this.isBusy, this.onPressed);
  final String label;
  final Color color;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: isBusy ? null : onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: color.withValues(alpha: 0.15),
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
    ),
  );
}
