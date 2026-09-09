import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

class StockCountScreen extends ConsumerStatefulWidget {
  const StockCountScreen({super.key});

  @override
  ConsumerState<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends ConsumerState<StockCountScreen> {
  bool _countStarted = false;
  final List<StockCountItem> _items = [];
  final TextEditingController _barcodeCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isApplying = false;

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCount(List<Product> products) {
    setState(() {
      _countStarted = true;
      _items.clear();
      _items.addAll(products.map((p) => StockCountItem(product: p)));
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  Future<void> _scanBarcode(String code) async {
    if (code.trim().isEmpty) return;
    final repo = ref.read(stockRepositoryProvider)!;
    final product = await repo.findByCode(code.trim());
    _barcodeCtrl.clear();
    if (product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$code" barkodlu ürün bulunamadı.')),
        );
      }
      return;
    }
    setState(() {
      final existing = _items.firstWhere(
        (i) => i.product.id == product.id,
        orElse: () {
          final item = StockCountItem(product: product);
          _items.add(item);
          return item;
        },
      );
      existing.countedQuantity += 1;
    });
  }

  Future<void> _applyCount() async {
    final hasDiff = _items.any((i) => i.hasDifference);
    if (!hasDiff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiçbir stok farkı bulunamadı.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF262C3D)),
        ),
        title: const Text(
          'Sayımı Onayla',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${_items.where((i) => i.hasDifference).length} üründe stok farkı var. Bu değişiklikleri stoka işlemek istiyor musunuz?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Onayla & Stoka İşle'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isApplying = true);

    final user = FirebaseAuth.instance.currentUser;
    try {
      await ref.read(stockRepositoryProvider)!.applyStockCount(
        items: _items,
        userId: user?.uid ?? 'unknown',
        userName: user?.email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sayım tamamlandı. Stoklar güncellendi.'),
          ),
        );
        setState(() {
          _countStarted = false;
          _items.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: !_countStarted
            ? _buildStartScreen(productsAsync)
            : _buildCountScreen(context),
      ),
    );
  }

  Widget _buildStartScreen(AsyncValue<List<Product>> productsAsync) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: const Color(0xFF12151E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2333)),
        ),
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.fact_check_outlined,
                color: Color(0xFF8B5CF6),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Depo Sayımı',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sayım başlatıldığında tüm ürünler listeye alınır. Barkod okutarak veya manuel girerek sayım miktarlarını belirleyin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 28),
            productsAsync.when(
              loading: () =>
                  const CircularProgressIndicator(color: Color(0xFFF58220)),
              error: (e, _) =>
                  Text('$e', style: const TextStyle(color: Colors.redAccent)),
              data: (products) => ElevatedButton.icon(
                onPressed: () => _startCount(products),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text(
                  'Sayımı Başlat',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountScreen(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 700) {
      return _buildMobileCountScreen();
    }
    final diffItems = _items.where((i) => i.hasDifference).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top bar
        Row(
          children: [
            // Barcode Input
            SizedBox(
              width: 340,
              height: 44,
              child: TextField(
                controller: _barcodeCtrl,
                focusNode: _focusNode,
                autofocus: true,
                onSubmitted: _scanBarcode,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'Barkod okut veya SKU yaz, Enter\'a bas...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF12151E),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
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
                      color: Color(0xFF8B5CF6),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF12151E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E2333)),
              ),
              child: Text(
                '${_items.where((i) => i.countedQuantity > 0).length} / ${_items.length} ürün sayıldı  •  ${diffItems.length} farklı',
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _countStarted = false;
                _items.clear();
              }),
              child: const Text(
                'İptal',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isApplying ? null : _applyCount,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Sayımı Tamamla & Uygula'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
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
              Expanded(flex: 3, child: _TH('Ürün Adı')),
              Expanded(flex: 1, child: _TH('Sistem Stoku')),
              Expanded(flex: 1, child: _TH('Sayılan')),
              Expanded(flex: 1, child: _TH('Fark')),
              SizedBox(width: 120),
            ],
          ),
        ),
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
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, index) =>
                  const Divider(color: Color(0xFF1E2333), height: 1),
              itemBuilder: (context, i) => _CountRow(
                item: _items[i],
                onChanged: (val) =>
                    setState(() => _items[i].countedQuantity = val),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCountScreen() {
    final diffItems = _items.where((i) => i.hasDifference).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _barcodeCtrl,
          focusNode: _focusNode,
          autofocus: true,
          onSubmitted: _scanBarcode,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Barkod okut veya SKU yaz',
            prefixIcon: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Color(0xFF8B5CF6),
            ),
            filled: true,
            fillColor: const Color(0xFF12151E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${_items.where((i) => i.countedQuantity > 0).length} / ${_items.length} ürün sayıldı • $diffItems farklı',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _MobileCountCard(
              item: _items[index],
              onChanged: (value) =>
                  setState(() => _items[index].countedQuantity = value),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                _countStarted = false;
                _items.clear();
              }),
              child: const Text('İptal'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isApplying ? null : _applyCount,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Sayımı Uygula'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MobileCountCard extends StatelessWidget {
  const _MobileCountCard({required this.item, required this.onChanged});
  final StockCountItem item;
  final ValueChanged<num> onChanged;
  @override
  Widget build(BuildContext context) {
    final diff = item.difference;
    final color = diff == 0
        ? const Color(0xFF64748B)
        : diff > 0
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            item.product.sku,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sistem\n${item.product.stock} ${item.product.unit}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                onPressed: item.countedQuantity > 0
                    ? () => onChanged(item.countedQuantity - 1)
                    : null,
                icon: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: Color(0xFFEF4444),
                ),
              ),
              SizedBox(
                width: 52,
                child: TextFormField(
                  initialValue: item.countedQuantity.toString(),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => onChanged(num.tryParse(v) ?? 0),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onChanged(item.countedQuantity + 1),
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Color(0xFF10B981),
                ),
              ),
              Expanded(
                child: Text(
                  'Fark\n${diff == 0 ? '—' : '${diff > 0 ? '+' : ''}$diff'}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.item, required this.onChanged});
  final StockCountItem item;
  final ValueChanged<num> onChanged;

  @override
  Widget build(BuildContext context) {
    final diff = item.difference;
    final diffColor = diff == 0
        ? const Color(0xFF64748B)
        : diff > 0
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  item.product.sku,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.product.stock} ${item.product.unit}',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ),
          Expanded(
            flex: 1,
            child: SizedBox(
              width: 80,
              height: 36,
              child: TextFormField(
                initialValue: item.countedQuantity.toString(),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (v) => onChanged(num.tryParse(v) ?? 0),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0B0D12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF262C3D)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF262C3D)),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              diff == 0 ? '—' : '${diff > 0 ? '+' : ''}$diff',
              style: TextStyle(
                color: diffColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_rounded,
                  size: 18,
                  color: Color(0xFFEF4444),
                ),
                onPressed: item.countedQuantity > 0
                    ? () => onChanged(item.countedQuantity - 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Color(0xFF10B981),
                ),
                onPressed: () => onChanged(item.countedQuantity + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  const _TH(this.text);
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
