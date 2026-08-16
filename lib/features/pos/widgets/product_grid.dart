import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/product.dart';
import '../barcode_lookup.dart';
import '../providers/cart_provider.dart';
import '../providers/pos_provider.dart';
import '../barcode_scanner_screen.dart';

class ProductGrid extends ConsumerWidget {
  const ProductGrid({super.key});

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => BarcodeScannerScreen(
        continuous: true,
        onCode: (code) => handleScannedCode(context, ref, code),
      ),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final query = ref.watch(productSearchQueryProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16,12,16,8), child: Row(children: [
        Expanded(child: TextField(decoration: const InputDecoration(hintText:'Cari produk atau SKU...', prefixIcon:Icon(Icons.search_rounded)), onChanged:(v)=>ref.read(productSearchQueryProvider.notifier).state=v)),
        const SizedBox(width:8),
        IconButton.filled(onPressed:()=>_scan(context,ref), tooltip:'Scan barcode', icon:const Icon(Icons.qr_code_scanner)),
      ])),
      categoriesAsync.when(data:(categories){ if(categories.isEmpty)return const SizedBox.shrink(); return SizedBox(height:44,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:16),children:[_CategoryChip(label:'Semua',selected:selectedCategory==null,onTap:()=>ref.read(selectedCategoryProvider.notifier).state=null),for(final c in categories)_CategoryChip(label:c.name,selected:selectedCategory==c.id,onTap:()=>ref.read(selectedCategoryProvider.notifier).state=c.id)]));},loading:()=>const SizedBox(height:44),error:(_,__)=>const SizedBox.shrink()),
      const SizedBox(height:8),
      Expanded(child:productsAsync.when(loading:()=>const Center(child:CircularProgressIndicator(color:AppColors.emerald600)),error:(e,_)=>Center(child:Text('Gagal memuat produk: $e')),data:(products){
        var filtered=products;
        if(selectedCategory!=null)filtered=filtered.where((p)=>p.categoryId==selectedCategory).toList();
        if(query.trim().isNotEmpty){final q=query.toLowerCase();filtered=filtered.where((p)=>p.name.toLowerCase().contains(q)||(p.sku?.toLowerCase().contains(q)??false)).toList();}
        if(filtered.isEmpty)return const Center(child:Text('Produk tidak ditemukan'));
        return GridView.builder(padding:const EdgeInsets.fromLTRB(16,0,16,16),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,mainAxisSpacing:12,crossAxisSpacing:12,childAspectRatio:.82),itemCount:filtered.length,itemBuilder:(context,i)=>_ProductCard(product:filtered[i]));
      }))
    ]);
  }
}

class _CategoryChip extends StatelessWidget { final String label; final bool selected; final VoidCallback onTap; const _CategoryChip({required this.label,required this.selected,required this.onTap}); @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(label),selected:selected,onSelected:(_)=>onTap())); }

class _ProductCard extends ConsumerWidget { final Product product; const _ProductCard({required this.product}); @override Widget build(BuildContext context,WidgetRef ref){final out=product.isOutOfStock;return Material(color:AppColors.surface,borderRadius:BorderRadius.circular(16),child:InkWell(borderRadius:BorderRadius.circular(16),onTap:out?null:()=>ref.read(cartProvider.notifier).addProduct(product),child:Container(decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),border:Border.all(color:AppColors.sand200)),padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Container(width:double.infinity,decoration:BoxDecoration(color:AppColors.sand100,borderRadius:BorderRadius.circular(12)),clipBehavior:Clip.antiAlias,child:product.photoUrl!=null?Image.network(product.photoUrl!,fit:BoxFit.cover):const Center(child:Icon(Icons.inventory_2_outlined,color:AppColors.charcoal300,size:32)))),const SizedBox(height:8),Text(product.name,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:13)),const SizedBox(height:2),Text(Formatters.rupiah(product.sellingPrice),style:const TextStyle(color:AppColors.emerald700,fontWeight:FontWeight.w700,fontSize:13)),if(product.tracksStock)Text(out?'Stok habis':'Stok: ${product.stock}',style:TextStyle(fontSize:11,color:out?AppColors.danger:product.isLowStock?AppColors.warning:AppColors.charcoal500))]))));}}
