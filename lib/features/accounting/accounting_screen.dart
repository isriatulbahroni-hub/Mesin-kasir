import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _journals = [];

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Silakan login terlebih dahulu.');
      final staff = await _supabase.from('staff').select('store_id').eq('user_id', user.id).eq('is_active', true).maybeSingle();
      final storeId = staff?['store_id'];
      if (storeId == null) throw Exception('Staff aktif belum terhubung ke toko.');
      final accounts = await _supabase.from('accounting_accounts').select('id,code,name,account_type,is_active').eq('store_id', storeId).order('code');
      final journals = await _supabase.from('accounting_journals').select('id,journal_no,journal_date,source_type,description').eq('store_id', storeId).order('journal_date', ascending: false).limit(50);
      if (mounted) setState(() { _accounts = List<Map<String,dynamic>>.from(accounts); _journals = List<Map<String,dynamic>>.from(journals); });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Accounting')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!))),
        Text('Chart of Accounts', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_accounts.isEmpty) const Card(child: ListTile(title: Text('Belum ada akun accounting')))
        else ..._accounts.map((a) => ListTile(leading: Text('${a['code']}'), title: Text('${a['name']}'), subtitle: Text('${a['account_type']}'))),
        const SizedBox(height: 24),
        Text('Journal', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_journals.isEmpty) const Card(child: ListTile(title: Text('Belum ada jurnal')))
        else ..._journals.map((j) => ListTile(title: Text('${j['journal_no']}'), subtitle: Text('${j['journal_date']} • ${j['description']}'), trailing: Text('${j['source_type']}'))),
      ]),
    ),
  );
}
