import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/session_provider.dart';
import '../../core/services/pos_extended_service.dart';

class OperationsScreen extends ConsumerStatefulWidget {
  const OperationsScreen({super.key});
  @override State<OperationsScreen> createState()=>_OperationsScreenState();
}

class _OperationsScreenState extends ConsumerState<OperationsScreen> {
  final _service=PosExtendedService();
  bool _loading=true; String? _error;
  List<Map<String,dynamic>> _customers=[],_promotions=[],_lowStock=[],_payments=[]; Map<String,dynamic> _sales={};
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    setState(()=>_loading=true); try {
      final staff=await ref.read(currentStaffProvider.future); if(staff==null)throw Exception('Staff belum aktif.');
      final now=DateTime.now().toUtc(), from=DateTime(now.year,now.month,now.day).toUtc();
      final results=await Future.wait([
        _service.customers(staff.storeId),_service.activePromotions(staff.storeId),_service.lowStock(staff.storeId),
        _service.salesSummary(storeId:staff.storeId,from:from,to:now),_service.paymentSummary(storeId:staff.storeId,from:from,to:now)
      ]);
      if(mounted)setState((){_customers=List<Map<String,dynamic>>.from(results[0] as List);_promotions=List<Map<String,dynamic>>.from(results[1] as List);_lowStock=List<Map<String,dynamic>>.from(results[2] as List);_sales=Map<String,dynamic>.from(results[3] as Map);_payments=List<Map<String,dynamic>>.from(results[4] as List);});
    }catch(e){if(mounted)setState(()=>_error=e.toString());}finally{if(mounted)setState(()=>_loading=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Operasional POS')),body:_loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
    if(_error!=null)Card(child:Padding(padding:const EdgeInsets.all(12),child:Text(_error!))),
    _section('Penjualan Hari Ini',Icons.point_of_sale,[_kv('Total transaksi','${_sales['transaction_count']??0}'),_kv('Omzet','Rp ${_sales['net_sales']??0}'),_kv('Diskon','Rp ${_sales['discount_total']??0}')]),
    _section('Pembayaran',Icons.payments,_payments.map((p)=>_kv('${p['method']??'-'}','Rp ${p['total_amount']??0}')).toList()),
    _section('Stok Menipis',Icons.warning,_lowStock.take(10).map((p)=>_kv('${p['name']??'-'}','Stok ${p['stock']??0}')).toList()),
    _section('Pelanggan',Icons.people,[_kv('Pelanggan aktif','${_customers.length}')]),
    _section('Promo Aktif',Icons.local_offer,[_kv('Promo berjalan','${_promotions.length}')]),
  ])));
  Widget _section(String title,IconData icon,List<Widget> children)=>Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon),const SizedBox(width:8),Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w700))]),const SizedBox(height:8),if(children.isEmpty)const Text('Tidak ada data') else ...children])));
  Widget _kv(String k,String v)=>ListTile(contentPadding:EdgeInsets.zero,dense:true,title:Text(k),trailing:Text(v,style:const TextStyle(fontWeight:FontWeight.w700)));
}
