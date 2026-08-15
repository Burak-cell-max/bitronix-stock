import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

class BarcodesScreen extends ConsumerStatefulWidget {
  const BarcodesScreen({super.key});

  @override
  ConsumerState<BarcodesScreen> createState() => _BarcodesScreenState();
}

class _BarcodesScreenState extends ConsumerState<BarcodesScreen> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  String _labelSize = '50x30';

  static const _labelSizes = ['40x30', '50x30', '60x40'];

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top controls
            Row(
              children: [
                // Search
                SizedBox(
                  width: 280,
                  height: 40,
                  child: TextField(
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ürün ara...',
                      hintStyle:
                          const TextStyle(color: Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Color(0xFF64748B), size: 18),
                      filled: true,
                      fillColor: const Color(0xFF12151E),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF1E2333)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF1E2333)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Label size selector
                const Text('Etiket Boyutu:',
                    style: TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12)),
                const SizedBox(width: 8),
                SegmentedButton<String>(
                  segments: _labelSizes
                      .map((s) => ButtonSegment(value: s, label: Text(s)))
                      .toList(),
                  selected: {_labelSize},
                  onSelectionChanged: (s) =>
                      setState(() => _labelSize = s.first),
                  style: SegmentedButton.styleFrom(
                    backgroundColor: const Color(0xFF12151E),
                    foregroundColor: const Color(0xFF94A3B8),
                    selectedBackgroundColor:
                        const Color(0xFFF58220).withValues(alpha: 0.2),
                    selectedForegroundColor: const Color(0xFFF58220),
                    side: const BorderSide(color: Color(0xFF1E2333)),
                  ),
                ),

                const Spacer(),
                if (_selectedIds.isNotEmpty) ...[
                  Text('${_selectedIds.length} ürün seçili',
                      style: const TextStyle(
                          color: Color(0xFFF58220), fontSize: 12)),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _selectedIds.clear()),
                    icon: const Icon(Icons.deselect_rounded, size: 16),
                    label: const Text('Seçimi Temizle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFF262C3D)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showBulkBarcodes(context),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Toplu QR Görüntüle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF58220),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Grid
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFF58220)),
                ),
                error: (e, _) => Center(
                  child: Text('Hata: $e',
                      style:
                          const TextStyle(color: Colors.redAccent)),
                ),
                data: (products) {
                  final filtered = products
                      .where((p) =>
                          _searchQuery.isEmpty ||
                          p.name.toLowerCase().contains(_searchQuery) ||
                          p.sku.toLowerCase().contains(_searchQuery))
                      .toList();

                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      mainAxisExtent: 280,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      final isSelected = _selectedIds.contains(p.id);
                      return _BarcodeCard(
                        product: p,
                        isSelected: isSelected,
                        labelSize: _labelSize,
                        onSelect: () => setState(() {
                          if (isSelected) {
                            _selectedIds.remove(p.id);
                          } else {
                            _selectedIds.add(p.id);
                          }
                        }),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkBarcodes(BuildContext context) {
    final productsAsync = ref.read(productsProvider);
    final products = productsAsync.asData?.value
        .where((p) => _selectedIds.contains(p.id))
        .toList();
    if (products == null || products.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF12151E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF262C3D)),
        ),
        child: SizedBox(
          width: 800,
          height: 600,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Toplu QR Etiketleri',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisExtent: 220,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, i) => _PrintCard(
                      product: products[i],
                      labelSize: _labelSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarcodeCard extends StatelessWidget {
  const _BarcodeCard({
    required this.product,
    required this.isSelected,
    required this.labelSize,
    required this.onSelect,
  });

  final Product product;
  final bool isSelected;
  final String labelSize;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFF58220)
              : const Color(0xFF1E2333),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection check + label size
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF58220)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF58220)
                            : const Color(0xFF262C3D),
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181C28),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: const Color(0xFF262C3D)),
                    ),
                    child: Text(labelSize,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // QR
              Center(
                child: QrImageView(
                  data: product.sku.isNotEmpty ? product.sku : product.id,
                  version: QrVersions.auto,
                  size: 120,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Product name
              Text(
                product.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                product.sku.isNotEmpty ? product.sku : '—',
                style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontFamily: 'monospace'),
              ),

              const Spacer(),

              // Copy SKU
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                        text: product.sku.isNotEmpty
                            ? product.sku
                            : product.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('SKU kopyalandı.')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('SKU Kopyala'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side:
                        const BorderSide(color: Color(0xFF262C3D)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 6),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrintCard extends StatelessWidget {
  const _PrintCard({required this.product, required this.labelSize});
  final Product product;
  final String labelSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          QrImageView(
            data: product.sku.isNotEmpty ? product.sku : product.id,
            version: QrVersions.auto,
            size: 120,
          ),
          const SizedBox(height: 6),
          Text(
            product.name,
            style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            product.sku,
            style: const TextStyle(
                color: Colors.black54,
                fontSize: 9,
                fontFamily: 'monospace'),
          ),
          Text(
            labelSize,
            style: const TextStyle(color: Colors.black38, fontSize: 8),
          ),
        ],
      ),
    );
  }
}
