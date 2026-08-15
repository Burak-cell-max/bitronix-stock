import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

class MovementsScreen extends ConsumerStatefulWidget {
  const MovementsScreen({super.key});

  @override
  ConsumerState<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends ConsumerState<MovementsScreen> {
  MovementType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(recentMovementsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Tümü',
                    isSelected: _typeFilter == null,
                    onTap: () => setState(() => _typeFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ...MovementType.values.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: t.displayLabel,
                          isSelected: _typeFilter == t,
                          accentColor: _typeColor(t),
                          onTap: () => setState(() => _typeFilter = t),
                        ),
                      )),
                ],
              ),
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
                  SizedBox(width: 70, child: _TableHeader('Tarih')),
                  SizedBox(width: 16),
                  Expanded(flex: 2, child: _TableHeader('Ürün')),
                  SizedBox(
                      width: 100, child: _TableHeader('İşlem Tipi')),
                  SizedBox(width: 90, child: _TableHeader('Miktar')),
                  Expanded(
                      flex: 1,
                      child: _TableHeader('Stok Değişimi')),
                  Expanded(flex: 1, child: _TableHeader('Kullanıcı')),
                  Expanded(flex: 1, child: _TableHeader('Sebep')),
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
                child: movementsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFF58220)),
                  ),
                  error: (e, _) => Center(
                    child: Text('Hata: $e',
                        style:
                            const TextStyle(color: Colors.redAccent)),
                  ),
                  data: (movements) {
                    final filtered = _typeFilter == null
                        ? movements
                        : movements
                            .where((m) => m.type == _typeFilter)
                            .toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          'Hareket bulunamadı.',
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 14),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, index) => const Divider(
                        color: Color(0xFF1E2333),
                        height: 1,
                      ),
                      itemBuilder: (context, i) {
                        return _MovementRow(movement: filtered[i]);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _typeColor(MovementType t) => switch (t) {
      MovementType.stockIn ||
      MovementType.purchase ||
      MovementType.returnItem =>
        const Color(0xFF10B981),
      MovementType.stockOut ||
      MovementType.sale ||
      MovementType.damage =>
        const Color(0xFFEF4444),
      MovementType.transfer => const Color(0xFF3B82F6),
      MovementType.production ||
      MovementType.productionConsumption =>
        const Color(0xFF8B5CF6),
      MovementType.countAdjustment ||
      MovementType.manualAdjustment =>
        const Color(0xFFF59E0B),
    };

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});
  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final isPositive = movement.quantity > 0;
    final color = isPositive
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final typeColor = _typeColor(movement.type);
    final dateStr = DateFormat('dd.MM.yy').format(movement.timestamp);
    final timeStr = DateFormat('HH:mm').format(movement.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Date
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
                Text(timeStr,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Product name
          Expanded(
            flex: 2,
            child: Text(
              movement.productName.isNotEmpty
                  ? movement.productName
                  : movement.productId,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Type badge
          SizedBox(
            width: 100,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                movement.type.displayLabel,
                style: TextStyle(
                    color: typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Quantity
          SizedBox(
            width: 90,
            child: Text(
              '${isPositive ? '+' : ''}${movement.quantity}',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          // Stock change
          Expanded(
            flex: 1,
            child: Text(
              '${movement.previousStock} → ${movement.newStock}',
              style: const TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ),
          // User
          Expanded(
            flex: 1,
            child: Text(
              movement.userName ?? movement.userId,
              style: const TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Reason
          Expanded(
            flex: 1,
            child: Text(
              movement.reason.isNotEmpty ? movement.reason : '—',
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
            color:
                isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
