import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key, this.initialProduct});
  final Product? initialProduct;

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  Product? _selectedProduct;
  String? _targetWarehouseId;
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _transfer() async {
    if (_selectedProduct == null || _targetWarehouseId == null) return;
    final qty = num.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;

    setState(() => _isBusy = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      await ref.read(stockRepositoryProvider)!.transferStock(
        product: _selectedProduct!,
        targetWarehouseId: _targetWarehouseId!,
        quantity: qty,
        userId: user?.uid ?? 'unknown',
        userName: user?.email,
        note: _noteCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedProduct!.name}: $qty adet transfer edildi.',
            ),
          ),
        );
        setState(() {
          _selectedProduct = null;
          _targetWarehouseId = null;
          _qtyCtrl.text = '1';
          _noteCtrl.clear();
        });
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
    final productsAsync = ref.watch(productsProvider);
    final warehousesAsync = ref.watch(warehousesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 700 ? 16 : 28,
          ),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 620),
              decoration: BoxDecoration(
                color: const Color(0xFF12151E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E2333)),
              ),
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 700 ? 18 : 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Depo Transferi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bir ürünü kaynak depodan hedef depoya aktarın.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // Product selection
                  const _Label('Ürün Seç *'),
                  const SizedBox(height: 6),
                  productsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(
                      '$e',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    data: (products) => DropdownButtonFormField<String>(
                      initialValue: _selectedProduct?.id,
                      dropdownColor: const Color(0xFF161922),
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('Ürün seçin...'),
                      items: products
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text('${p.name} (${p.stock} ${p.unit})'),
                            ),
                          )
                          .toList(),
                      onChanged: (id) => setState(() {
                        _selectedProduct = products.firstWhere(
                          (p) => p.id == id,
                        );
                      }),
                    ),
                  ),

                  if (_selectedProduct != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181C28),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF262C3D)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kaynak Depo: ',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _selectedProduct!.warehouseId ?? 'Belirtilmemiş',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Mevcut: ${_selectedProduct!.stock} ${_selectedProduct!.unit}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Target warehouse
                  const _Label('Hedef Depo *'),
                  const SizedBox(height: 6),
                  warehousesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(
                      '$e',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    data: (warehouses) => DropdownButtonFormField<String>(
                      initialValue: _targetWarehouseId,
                      dropdownColor: const Color(0xFF161922),
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('Hedef depo seçin...'),
                      items: warehouses
                          .where((w) => w.id != _selectedProduct?.warehouseId)
                          .map(
                            (w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(w.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _targetWarehouseId = v),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quantity
                  const _Label('Transfer Miktarı *'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec('Miktar'),
                  ),

                  const SizedBox(height: 16),

                  // Note
                  const _Label('Not (opsiyonel)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _noteCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: _dec('Transfer nedeni veya not ekleyin...'),
                  ),

                  const SizedBox(height: 24),

                  // Transfer button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_isBusy ||
                              _selectedProduct == null ||
                              _targetWarehouseId == null)
                          ? null
                          : _transfer,
                      icon: _isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text(
                        'Transferi Gerçekleştir',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _dec(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFF64748B)),
  filled: true,
  fillColor: const Color(0xFF0B0D12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFF262C3D)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFF262C3D)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
  ),
);

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFFCBD5E1),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );
}
