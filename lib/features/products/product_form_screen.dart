import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final Product? product;

  bool get isEditing => product != null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isBusy = false;

  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  late final TextEditingController _brand;
  late final TextEditingController _description;
  late final TextEditingController _unit;
  late final TextEditingController _minimumStock;
  late final TextEditingController _initialStock;
  late final TextEditingController _currentStock;
  late final TextEditingController _criticalStock;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _salePrice;
  late final TextEditingController _locationLabel;

  String? _selectedWarehouseId;

  static const _units = [
    'adet',
    'kg',
    'gram',
    'litre',
    'ml',
    'm',
    'cm',
    'paket',
    'kutu',
    'rulo',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _unit = TextEditingController(text: p?.unit ?? 'adet');
    _minimumStock = TextEditingController(
      text: p?.minimumStock.toString() ?? '0',
    );
    _initialStock = TextEditingController(text: p?.stock.toString() ?? '0');
    _currentStock = TextEditingController(text: p?.stock.toString() ?? '0');
    _criticalStock = TextEditingController(
      text: p?.criticalStock.toString() ?? '0',
    );
    _purchasePrice = TextEditingController(
      text: p?.purchasePrice?.toString() ?? '',
    );
    _salePrice = TextEditingController(text: p?.salePrice?.toString() ?? '');
    _locationLabel = TextEditingController(text: p?.locationLabel ?? '');
    _selectedWarehouseId = p?.warehouseId;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _sku,
      _barcode,
      _category,
      _brand,
      _description,
      _unit,
      _minimumStock,
      _initialStock,
      _currentStock,
      _criticalStock,
      _purchasePrice,
      _salePrice,
      _locationLabel,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isBusy = true);

    final repo = ref.read(stockRepositoryProvider)!;
    final data = {
      'name': _name.text.trim(),
      'sku': _sku.text.trim(),
      'barcode': _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      'category': _category.text.trim().isEmpty ? null : _category.text.trim(),
      'brand': _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      'description': _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      'unit': _unit.text.trim().isEmpty ? 'adet' : _unit.text.trim(),
      'minimumStock': num.tryParse(_minimumStock.text) ?? 0,
      if (!widget.isEditing)
        'initialStock': num.tryParse(_initialStock.text) ?? 0,
      'criticalStock': num.tryParse(_criticalStock.text) ?? 0,
      'purchasePrice': _purchasePrice.text.trim().isEmpty
          ? null
          : num.tryParse(_purchasePrice.text),
      'salePrice': _salePrice.text.trim().isEmpty
          ? null
          : num.tryParse(_salePrice.text),
      'warehouseId': _selectedWarehouseId,
      'locationLabel': _locationLabel.text.trim().isEmpty
          ? null
          : _locationLabel.text.trim(),
    };

    try {
      if (widget.isEditing) {
        await repo.updateProduct(widget.product!.id, data);
        final targetStock =
            num.tryParse(_currentStock.text) ?? widget.product!.stock;
        final delta = targetStock - widget.product!.stock;
        if (delta != 0) {
          final user = FirebaseAuth.instance.currentUser;
          await repo.adjustStock(
            product: widget.product!,
            quantity: delta,
            type: MovementType.manualAdjustment,
            userId: user?.uid ?? 'unknown',
            userName: user?.email,
            reason: 'Ürün düzenleme ekranından stok düzeltmesi',
          );
        }
        if (mounted) {
          Navigator.pop(
            context,
            widget.product!.copyWith(
              name: data['name'] as String,
              sku: data['sku'] as String,
              barcode: data['barcode'] as String?,
              category: data['category'] as String?,
              brand: data['brand'] as String?,
              description: data['description'] as String?,
              unit: data['unit'] as String,
              minimumStock: data['minimumStock'] as num,
              stock: targetStock,
              criticalStock: data['criticalStock'] as num,
              purchasePrice: data['purchasePrice'] as num?,
              salePrice: data['salePrice'] as num?,
              warehouseId: data['warehouseId'] as String?,
              locationLabel: data['locationLabel'] as String?,
            ),
          );
        }
      } else {
        final user = FirebaseAuth.instance.currentUser;
        await repo.addProduct(
          data,
          userId: user?.uid ?? 'unknown',
          userName: user?.email,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ürün başarıyla eklendi.')),
          );
          Navigator.pop(context);
        }
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

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _BarcodeCaptureScreen()),
    );
    if (code != null && mounted) setState(() => _barcode.text = code);
  }

  @override
  Widget build(BuildContext context) {
    final warehousesAsync = ref.watch(warehousesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12151E),
        foregroundColor: Colors.white,
        title: Text(
          widget.isEditing ? 'Ürün Düzenle' : 'Yeni Ürün Ekle',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isBusy)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Kaydet'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF58220),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFF58220),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;

            final leftColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Temel Bilgiler'),
                _FormCard(
                  children: [
                    _Field(_name, 'Ürün Adı *', required: true),
                    _Field(
                      _sku,
                      'SKU (Stok Kodu) *',
                      required: true,
                      hint: 'BTX-ESP32-001',
                    ),
                    if (isWide)
                      _Field(_barcode, 'Barkod', hint: '1234567890')
                    else
                      _MobileBarcodeField(
                        barcode: _barcode.text,
                        onScan: _scanBarcode,
                      ),
                    _Field(_category, 'Kategori', hint: 'Mikroişlemci'),
                    _Field(_brand, 'Marka', hint: 'Espressif'),
                    _Field(_description, 'Açıklama', maxLines: 3),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionHeader('Stok & Depo'),
                _FormCard(
                  children: [
                    // Birim seçimi
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String>(
                        initialValue: _units.contains(_unit.text)
                            ? _unit.text
                            : 'adet',
                        decoration: _inputDecoration('Birim'),
                        dropdownColor: const Color(0xFF161922),
                        style: const TextStyle(color: Colors.white),
                        items: _units
                            .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
                            )
                            .toList(),
                        onChanged: (v) => _unit.text = v ?? 'adet',
                      ),
                    ),
                    _Field(
                      _minimumStock,
                      'Minimum Stok',
                      keyboardType: TextInputType.number,
                    ),
                    if (!widget.isEditing)
                      _Field(
                        _initialStock,
                        'Başlangıç Stoku',
                        hint: 'Örn. 10',
                        keyboardType: TextInputType.number,
                      ),
                    if (widget.isEditing)
                      _Field(
                        _currentStock,
                        'Mevcut Stok',
                        hint: 'Örn. 10',
                        keyboardType: TextInputType.number,
                      ),
                    _Field(
                      _criticalStock,
                      'Kritik Stok',
                      keyboardType: TextInputType.number,
                    ),
                    // Depo seçimi
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: warehousesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => const Text(
                          'Depolar yüklenemedi',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        data: (warehouses) => DropdownButtonFormField<String>(
                          initialValue: _selectedWarehouseId,
                          decoration: _inputDecoration('Depo'),
                          dropdownColor: const Color(0xFF161922),
                          style: const TextStyle(color: Colors.white),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Depo seçin...'),
                            ),
                            ...warehouses.map(
                              (w) => DropdownMenuItem(
                                value: w.id,
                                child: Text(w.name),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedWarehouseId = v),
                        ),
                      ),
                    ),
                    _Field(_locationLabel, 'Raf / Lokasyon', hint: 'A-04-12'),
                  ],
                ),
              ],
            );

            final rightColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Fiyat & Maliyet'),
                _FormCard(
                  children: [
                    _Field(
                      _purchasePrice,
                      'Alış Fiyatı (₺)',
                      keyboardType: TextInputType.number,
                      hint: '0.00',
                    ),
                    _Field(
                      _salePrice,
                      'Satış Fiyatı (₺)',
                      keyboardType: TextInputType.number,
                      hint: '0.00',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _save,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(
                      widget.isEditing ? 'Değişiklikleri Kaydet' : 'Ürün Ekle',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF58220),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            );

            return SingleChildScrollView(
              padding: EdgeInsets.all(isWide ? 24 : 16),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: leftColumn),
                        const SizedBox(width: 24),
                        SizedBox(width: 340, child: rightColumn),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftColumn,
                        const SizedBox(height: 20),
                        rightColumn,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: Color(0xFF64748B)),
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
    borderSide: const BorderSide(color: Color(0xFFF58220)),
  ),
);

class _Field extends StatelessWidget {
  const _Field(
    this.controller,
    this.label, {
    this.required = false,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? '$label zorunludur.' : null
          : null,
      decoration: _inputDecoration(label).copyWith(hintText: hint),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    ),
  );
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF12151E),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF1E2333)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _MobileBarcodeField extends StatelessWidget {
  const _MobileBarcodeField({required this.barcode, required this.onScan});
  final String barcode;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: OutlinedButton.icon(
      onPressed: onScan,
      icon: const Icon(Icons.qr_code_scanner_rounded),
      label: Text(barcode.isEmpty ? 'Barkod okut' : 'Okutuldu: $barcode'),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: const Color(0xFFF58220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        side: const BorderSide(color: Color(0xFFF58220)),
      ),
    ),
  );
}

class _BarcodeCaptureScreen extends StatefulWidget {
  const _BarcodeCaptureScreen();
  @override
  State<_BarcodeCaptureScreen> createState() => _BarcodeCaptureScreenState();
}

class _BarcodeCaptureScreenState extends State<_BarcodeCaptureScreen> {
  bool _captured = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Barkod okut')),
    body: MobileScanner(
      onDetect: (capture) {
        final code = capture.barcodes.firstOrNull?.rawValue;
        if (!_captured && code != null) {
          _captured = true;
          Navigator.pop(context, code);
        }
      },
    ),
  );
}
