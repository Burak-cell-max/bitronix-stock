import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/warehouse_repository.dart';

class WarehousesScreen extends ConsumerStatefulWidget {
  const WarehousesScreen({super.key});

  @override
  ConsumerState<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends ConsumerState<WarehousesScreen> {
  @override
  Widget build(BuildContext context) {
    final warehousesAsync = ref.watch(warehousesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showWarehouseDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Yeni Depo'),
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
            Expanded(
              child: warehousesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF58220)),
                ),
                error: (e, _) => Center(
                  child: Text('Hata: $e',
                      style: const TextStyle(color: Colors.redAccent)),
                ),
                data: (warehouses) {
                  if (warehouses.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warehouse_outlined,
                              size: 64, color: Color(0xFF262C3D)),
                          SizedBox(height: 16),
                          Text('Henüz depo eklenmedi.',
                              style: TextStyle(
                                  color: Color(0xFF64748B), fontSize: 14)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: warehouses.length,
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _WarehouseCard(warehouse: warehouses[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWarehouseDialog(BuildContext context, {Warehouse? existing}) {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final descCtrl =
        TextEditingController(text: existing?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF262C3D)),
        ),
        title: Text(
          existing == null ? 'Yeni Depo Ekle' : 'Depoyu Düzenle',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Depo Adı *',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Color(0xFF0B0D12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Color(0xFF0B0D12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF58220),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final repo =
                  WarehouseRepository(FirebaseFirestore.instance);
              if (existing == null) {
                await repo.add(Warehouse(
                  id: '',
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                ));
              } else {
                await repo.update(existing.id, {
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Ekle' : 'Kaydet'),
          ),
        ],
      ),
    );
  }
}

class _WarehouseCard extends ConsumerWidget {
  const _WarehouseCard({required this.warehouse});
  final Warehouse warehouse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final productCount = productsAsync.whenOrNull(
      data: (products) =>
          products.where((p) => p.warehouseId == warehouse.id).length,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2333)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warehouse_outlined,
                color: Color(0xFF3B82F6), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(warehouse.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                if (warehouse.description != null) ...[
                  const SizedBox(height: 2),
                  Text(warehouse.description!,
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 13)),
                ],
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF181C28),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF262C3D)),
            ),
            child: Text(
              '${productCount ?? '...'} ürün',
              style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
