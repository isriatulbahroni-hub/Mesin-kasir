import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../inventory/providers/inventory_provider.dart';
import '../pos/providers/pos_provider.dart';
import 'barcode_scanner_screen.dart';
import 'providers/products_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});
  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController(text: '5');
  final _reorderQtyCtrl = TextEditingController();
  String? _categoryId;
  String? _defaultSupplierId;
  bool _tracksStock = true, _loaded = false, _submitting = false;
  bool get isEditing => widget.productId != null;

  @override
  void dispose() { for (final c in [_nameCtrl,_skuCtrl,_priceCtrl,_costCtrl,_stockCtrl,_thresholdCtrl,_reorderQtyCtrl]) { c.dispose(); } super.dispose(); }

  void _hydrate(dynamic p) {
    if (_loaded || p == null) return;
    _loaded = true; _nameCtrl.text=p.name; _skuCtrl.text=p.sku??''; _priceCtrl.text=p.sellingPrice.toString(); _costCtrl.text=p.costPrice.toString();
    _tracksStock=p.stock!=null; if(p.stock!=null) _stockCtrl.text=p.stock.toString(); _thresholdCtrl.text=p.lowStockThreshold.toString(); _categoryId=p.categoryId;
    _defaultSupplierId=p.defaultSupplierId; if(p.reorderQuantity!=null) _reorderQtyCtrl.text=p.reorderQuantity.toString();
  }

  Future<void> _scanSku() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
    if (!mounted || code == null || code.isEmpty) return;
    setState(() => _skuCtrl.text = code);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Barcode $code dimasukkan sebagai SKU.')));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync=ref.watch(categoriesProvider);
    final productAsync=isEditing?ref.watch(productByIdProvider(widget.productId!)):const AsyncValue.data(null);
    if(isEditing) productAsync.whenData(_hydrate);
    return Scaffold(
      appBar: AppBar(title: Text(isEditing?'Edit Produk':'Tambah Produk')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(key:_formKey, child: Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        TextFormField(controller:_nameCtrl,decoration:const InputDecoration(labelText:'Nama Produk'),validator:(v)=>(v==null||v.trim().isEmpty)?'Wajib diisi':null),
        const SizedBox(height:12),
        Row(children:[Expanded(child:TextFormField(controller:_skuCtrl,decoration:const InputDecoration(labelText:'SKU / Barcode'))),const SizedBox(width:8),IconButton.filled(onPressed:_scanSku,tooltip:'Scan barcode',icon:const Icon(Icons.qr_code_scanner))]),
        const SizedBox(height:12),
        categoriesAsync.when(data:(cs)=>DropdownButtonFormField<String>(initialValue:_categoryId,decoration:const InputDecoration(labelText:'Kategori'),items:[const DropdownMenuItem(value:null,child:Text('Tanpa kategori')),for(final c in cs) DropdownMenuItem(value:c.id,child:Text(c.name))],onChanged:(v)=>setState(()=>_categoryId=v)),loading:()=>const LinearProgressIndicator(),error:(_,__)=>const SizedBox.shrink()),
        const SizedBox(height:12),
        Row(children:[Expanded(child:TextFormField(controller:_priceCtrl,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Harga Jual',prefixText:'Rp '),validator:(v)=>int.tryParse(v??'')==null?'Angka valid':null)),const SizedBox(width:12),Expanded(child:TextFormField(controller:_costCtrl,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Harga Modal',prefixText:'Rp '),validator:(v)=>int.tryParse(v??'')==null?'Angka valid':null))]),
        const SizedBox(height:12),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Lacak stok produk ini'),subtitle:const Text('Matikan untuk produk jasa / tanpa stok fisik'),value:_tracksStock,onChanged:(v)=>setState(()=>_tracksStock=v),activeThumbColor:AppColors.emerald600),
        if(_tracksStock) Row(children:[Expanded(child:TextFormField(controller:_stockCtrl,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Stok'))),const SizedBox(width:12),Expanded(child:TextFormField(controller:_thresholdCtrl,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Ambang stok menipis')))]),
        if(_tracksStock) const SizedBox(height:16),
        if(_tracksStock) const Text('Reorder Point (opsional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        if(_tracksStock) const SizedBox(height:4),
        if(_tracksStock) const Text(
          'Kalau diisi, sistem otomatis bikin draft Purchase Order ke supplier ini '
          'begitu stok tembus ambang minimum - tinggal direview & konfirmasi, gak perlu mulai dari nol.',
          style: TextStyle(fontSize: 11.5, color: AppColors.charcoal500),
        ),
        if(_tracksStock) const SizedBox(height:10),
        if(_tracksStock) Consumer(builder: (context, ref, _) {
          final suppliersAsync = ref.watch(suppliersProvider);
          return suppliersAsync.when(
            data: (suppliers) => DropdownButtonFormField<String>(
              initialValue: _defaultSupplierId,
              decoration: const InputDecoration(labelText: 'Supplier Default'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tidak ada (matikan auto-reorder)')),
                for (final s in suppliers) DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _defaultSupplierId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          );
        }),
        if(_tracksStock && _defaultSupplierId != null) const SizedBox(height:12),
        if(_tracksStock && _defaultSupplierId != null) TextFormField(
          controller: _reorderQtyCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Qty Restock (opsional)',
            helperText: 'Kosongkan buat pakai default: 2x ambang stok menipis',
          ),
        ),
        const SizedBox(height:16),
        ElevatedButton(onPressed:_submitting?null:_submit,style:ElevatedButton.styleFrom(minimumSize:const Size.fromHeight(50)),child:_submitting?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Text('Simpan Produk')),
      ]))),
    );
  }

  Future<void> _submit() async {
    if(!_formKey.currentState!.validate()) return; setState(()=>_submitting=true);
    final error=await ref.read(productFormControllerProvider.notifier).save(id:widget.productId,name:_nameCtrl.text.trim(),sku:_skuCtrl.text.trim().isEmpty?null:_skuCtrl.text.trim(),categoryId:_categoryId,sellingPrice:int.parse(_priceCtrl.text.trim()),costPrice:int.parse(_costCtrl.text.trim()),stock:_tracksStock?(int.tryParse(_stockCtrl.text.trim())??0):null,lowStockThreshold:int.tryParse(_thresholdCtrl.text.trim())??5,defaultSupplierId:_tracksStock?_defaultSupplierId:null,reorderQuantity:_tracksStock?int.tryParse(_reorderQtyCtrl.text.trim()):null);
    if(!mounted)return; setState(()=>_submitting=false);
    if(error!=null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error))); } else { Navigator.pop(context); }
  }
}
