import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final movementsAsync = ref.watch(recentMovementsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric Cards
          productsAsync.when(
            loading: () =>
                const _MetricCardsPlaceholder(),
            error: (e, _) =>
                Center(child: Text('$e', style: const TextStyle(color: Colors.redAccent))),
            data: (products) {
              final totalStock = products.fold<num>(0, (a, p) => a + p.stock);
              final critical = products.where((p) => p.isCritical).length;
              final outOfStock = products.where((p) => p.isOutOfStock).length;
              final totalValue = products.fold<double>(0, (a, p) {
                final cost = p.averageCost ?? p.purchasePrice ?? 0;
                return a + (p.stock * cost).toDouble();
              });

              return LayoutBuilder(
                builder: (_, c) {
                  final cols = c.maxWidth < 800 ? 2 : 5;
                  return GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.0,
                    ),
                    children: [
                      _MetricCard(
                        label: 'Toplam Ürün',
                        value: '${products.length}',
                        icon: Icons.widgets_outlined,
                        color: const Color(0xFF3B82F6),
                      ),
                      _MetricCard(
                        label: 'Toplam Stok',
                        value: NumberFormat('#,###').format(totalStock),
                        icon: Icons.inventory_2_outlined,
                        color: const Color(0xFF10B981),
                      ),
                      _MetricCard(
                        label: 'Kritik Stok',
                        value: '$critical',
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFEF4444),
                        highlight: critical > 0,
                      ),
                      _MetricCard(
                        label: 'Tükenen Ürün',
                        value: '$outOfStock',
                        icon: Icons.remove_shopping_cart_rounded,
                        color: const Color(0xFF64748B),
                        highlight: outOfStock > 0,
                      ),
                      _MetricCard(
                        label: 'Stok Değeri',
                        value: totalValue > 0
                            ? '${NumberFormat('#,###').format(totalValue)} ₺'
                            : '—',
                        icon: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          // Bottom Two Columns
          LayoutBuilder(builder: (_, c) {
            final isWide = c.maxWidth > 900;
            return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 3,
                          child: _RecentMovements(movementsAsync: movementsAsync)),
                      const SizedBox(width: 16),
                      Expanded(
                          flex: 2,
                          child: _CriticalStockPanel(productsAsync: productsAsync)),
                    ],
                  )
                : Column(
                    children: [
                      _RecentMovements(movementsAsync: movementsAsync),
                      const SizedBox(height: 16),
                      _CriticalStockPanel(productsAsync: productsAsync),
                    ],
                  );
          }),
        ],
      ),
    );
  }
}

// ─── Metric Card ─────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  final String label, value;
  final IconData icon;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.1)
            : const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? color.withValues(alpha: 0.5)
              : const Color(0xFF1E2333),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: highlight ? color : Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCardsPlaceholder extends StatelessWidget {
  const _MetricCardsPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFF58220)),
        ),
      );
}

// ─── Recent Movements ────────────────────────────────────────────────────────

class _RecentMovements extends StatelessWidget {
  const _RecentMovements({required this.movementsAsync});
  final AsyncValue<List<StockMovement>> movementsAsync;

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
              Icon(Icons.history_rounded,
                  size: 18, color: Color(0xFFF58220)),
              SizedBox(width: 8),
              Text('Son Stok Hareketleri',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF1E2333), height: 1),
          const SizedBox(height: 8),
          movementsAsync.when(
            loading: () => const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFFF58220))),
            error: (e, _) => Text('$e',
                style: const TextStyle(color: Colors.redAccent)),
            data: (movements) {
              if (movements.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('Henüz stok hareketi yok.',
                        style: TextStyle(
                            color: Color(0xFF64748B), fontSize: 13)),
                  ),
                );
              }
              return Column(
                children: movements
                    .take(15)
                    .map((m) => _MovementTile(movement: m))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});
  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final isPositive = movement.quantity > 0;
    final color =
        isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final dateStr =
        DateFormat('dd.MM HH:mm').format(movement.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPositive
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.productName.isNotEmpty
                      ? movement.productName
                      : movement.productId,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
                Text(
                  '${movement.type.displayLabel}${movement.reason.isNotEmpty ? ' · ${movement.reason}' : ''}',
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}${movement.quantity}',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              Text(dateStr,
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Critical Stock Panel ─────────────────────────────────────────────────────

class _CriticalStockPanel extends StatelessWidget {
  const _CriticalStockPanel({required this.productsAsync});
  final AsyncValue<List<Product>> productsAsync;

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
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Kritik & Düşük Stok',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF1E2333), height: 1),
          const SizedBox(height: 8),
          productsAsync.when(
            loading: () => const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFFF58220))),
            error: (e, _) => Text('$e',
                style: const TextStyle(color: Colors.redAccent)),
            data: (products) {
              final alerts = products
                  .where((p) => p.isCritical || p.isLow || p.isOutOfStock)
                  .toList()
                ..sort((a, b) => a.stock.compareTo(b.stock));

              if (alerts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 40, color: Color(0xFF10B981)),
                        SizedBox(height: 8),
                        Text('Tüm stoklar normal seviyede.',
                            style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: alerts
                    .take(12)
                    .map((p) => _StockAlertTile(product: p))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StockAlertTile extends StatelessWidget {
  const _StockAlertTile({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String statusStr;

    if (product.isOutOfStock) {
      color = const Color(0xFF64748B);
      statusStr = 'TÜKENDİ';
    } else if (product.isCritical) {
      color = const Color(0xFFEF4444);
      statusStr = 'KRİTİK';
    } else {
      color = const Color(0xFFF59E0B);
      statusStr = 'DÜŞÜK';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                Text(product.sku,
                    style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.stock} ${product.unit}',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(statusStr,
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
