import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  String? _storeId;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _journals = [];
  Map<String, Map<String, num>> _plByType = {}; // account_type -> {debit, credit}

  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Silakan login terlebih dahulu.');
      final staff = await _supabase.from('staff').select('store_id').eq('user_id', user.id).eq('is_active', true).maybeSingle();
      final storeId = staff?['store_id'] as String?;
      if (storeId == null) throw Exception('Staff aktif belum terhubung ke toko.');
      _storeId = storeId;

      final accounts = await _supabase.from('accounting_accounts').select('id,code,name,account_type,is_active').eq('store_id', storeId).order('code');
      final journals = await _supabase.from('accounting_journals').select('id,journal_no,journal_date,source_type,description').eq('store_id', storeId).order('journal_date', ascending: false).limit(50);

      final plRows = await _supabase.rpc('profit_and_loss_report', params: {
        'p_store_id': storeId,
        'p_from': _from.toIso8601String().split('T').first,
        'p_to': _to.toIso8601String().split('T').first,
      });
      final plMap = <String, Map<String, num>>{};
      for (final row in (plRows as List)) {
        plMap[row['account_type'] as String] = {
          'debit': (row['total_debit'] as num?) ?? 0,
          'credit': (row['total_credit'] as num?) ?? 0,
        };
      }

      if (mounted) {
        setState(() {
          _accounts = List<Map<String, dynamic>>.from(accounts);
          _journals = List<Map<String, dynamic>>.from(journals);
          _plByType = plMap;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Konvensi akuntansi standar: revenue bertambah lewat kredit, cogs/expense
  // bertambah lewat debit. Jadi:
  num get _revenue => (_plByType['revenue']?['credit'] ?? 0) - (_plByType['revenue']?['debit'] ?? 0);
  num get _cogs => (_plByType['cogs']?['debit'] ?? 0) - (_plByType['cogs']?['credit'] ?? 0);
  num get _expense => (_plByType['expense']?['debit'] ?? 0) - (_plByType['expense']?['credit'] ?? 0);
  num get _grossProfit => _revenue - _cogs;
  num get _netProfit => _grossProfit - _expense;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Accounting'),
      bottom: TabBar(
        controller: _tabController,
        tabs: const [Tab(text: 'Ringkasan'), Tab(text: 'Akun'), Tab(text: 'Jurnal')],
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _storeId == null ? null : () => _showManualJournalDialog(context),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Jurnal Manual'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.emerald600))
        : TabBarView(
            controller: _tabController,
            children: [
              _buildSummaryTab(),
              _buildAccountsTab(),
              _buildJournalsTab(),
            ],
          ),
  );

  Widget _buildSummaryTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!))),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text('${Formatters.date(_from)} — ${Formatters.date(_to)}')),
                  TextButton(onPressed: _pickDateRange, child: const Text('Ubah Periode')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Laporan Laba-Rugi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 16),
                  _plRow('Pendapatan', _revenue),
                  _plRow('HPP (Harga Pokok Penjualan)', -_cogs),
                  const Divider(height: 24),
                  _plRow('Laba Kotor', _grossProfit, bold: true),
                  _plRow('Beban Operasional', -_expense),
                  const Divider(height: 24),
                  _plRow('Laba Bersih', _netProfit, bold: true, highlight: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Angka di atas dihitung dari jurnal accounting (posting otomatis dari '
            'penjualan + jurnal manual). Kalau ada transaksi yang belum ke-posting, '
            'laporan ini bisa belum lengkap.',
            style: TextStyle(fontSize: 11.5, color: AppColors.charcoal500),
          ),
        ],
      ),
    );
  }

  Widget _plRow(String label, num value, {bool bold = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(
            Formatters.rupiah(value),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 14,
              color: highlight
                  ? (value >= 0 ? AppColors.emerald700 : AppColors.danger)
                  : AppColors.charcoal900,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range != null) {
      setState(() { _from = range.start; _to = range.end; });
      _load();
    }
  }

  Widget _buildAccountsTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_accounts.isEmpty)
            const Card(child: ListTile(title: Text('Belum ada akun accounting')))
          else
            ..._accounts.map((a) => Card(
                  child: ListTile(
                    leading: Text('${a['code']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    title: Text('${a['name']}'),
                    subtitle: Text('${a['account_type']}'),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildJournalsTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_journals.isEmpty)
            const Card(child: ListTile(title: Text('Belum ada jurnal')))
          else
            ..._journals.map((j) => Card(
                  child: ListTile(
                    title: Text('${j['journal_no']}'),
                    subtitle: Text('${j['journal_date']} • ${j['description'] ?? '-'}'),
                    trailing: Text('${j['source_type']}', style: const TextStyle(fontSize: 11)),
                  ),
                )),
        ],
      ),
    );
  }

  void _showManualJournalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _ManualJournalDialog(storeId: _storeId!, accounts: _accounts, onSaved: _load),
    );
  }
}

class _JournalLineInput {
  String? accountId;
  final amountCtrl = TextEditingController();
  bool isDebit = true;
}

class _ManualJournalDialog extends StatefulWidget {
  final String storeId;
  final List<Map<String, dynamic>> accounts;
  final VoidCallback onSaved;
  const _ManualJournalDialog({required this.storeId, required this.accounts, required this.onSaved});

  @override
  State<_ManualJournalDialog> createState() => _ManualJournalDialogState();
}

class _ManualJournalDialogState extends State<_ManualJournalDialog> {
  final _descCtrl = TextEditingController();
  final List<_JournalLineInput> _lines = [_JournalLineInput(), _JournalLineInput()];
  bool _submitting = false;
  String? _error;

  num get _totalDebit => _lines.where((l) => l.isDebit).fold<num>(0, (s, l) => s + (num.tryParse(l.amountCtrl.text) ?? 0));
  num get _totalCredit => _lines.where((l) => !l.isDebit).fold<num>(0, (s, l) => s + (num.tryParse(l.amountCtrl.text) ?? 0));

  @override
  Widget build(BuildContext context) {
    final balanced = _totalDebit > 0 && _totalDebit == _totalCredit;

    return AlertDialog(
      title: const Text('Jurnal Manual'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
              TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi')),
              const SizedBox(height: 12),
              const Text('Baris Jurnal (total debit harus = total kredit)',
                  style: TextStyle(fontSize: 12, color: AppColors.charcoal500)),
              for (int i = 0; i < _lines.length; i++) _buildLineRow(i),
              TextButton.icon(
                onPressed: () => setState(() => _lines.add(_JournalLineInput())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Tambah Baris'),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Debit: ${Formatters.rupiah(_totalDebit)}', style: const TextStyle(fontSize: 12)),
                  Text('Kredit: ${Formatters.rupiah(_totalCredit)}', style: const TextStyle(fontSize: 12)),
                ],
              ),
              if (!balanced)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Belum balance.', style: TextStyle(fontSize: 11, color: AppColors.warning)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: (!balanced || _submitting) ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _buildLineRow(int i) {
    final line = _lines[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: line.accountId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Akun', isDense: true),
              items: [
                for (final a in widget.accounts)
                  DropdownMenuItem(value: a['id'] as String, child: Text('${a['code']} ${a['name']}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => line.accountId = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: line.amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nominal', isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          ToggleButtons(
            isSelected: [line.isDebit, !line.isDebit],
            onPressed: (idx) => setState(() => line.isDebit = idx == 0),
            constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
            children: const [Text('D'), Text('K')],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: _lines.length > 2 ? () => setState(() => _lines.removeAt(i)) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      final lines = _lines
          .where((l) => l.accountId != null && (num.tryParse(l.amountCtrl.text) ?? 0) > 0)
          .map((l) => {
                'account_id': l.accountId,
                'debit': l.isDebit ? num.parse(l.amountCtrl.text) : 0,
                'credit': !l.isDebit ? num.parse(l.amountCtrl.text) : 0,
              })
          .toList();

      await Supabase.instance.client.rpc('create_balanced_journal', params: {
        'p_store_id': widget.storeId,
        'p_source_type': 'manual',
        'p_source_id': null,
        'p_description': _descCtrl.text.trim().isEmpty ? 'Jurnal manual' : _descCtrl.text.trim(),
        'p_lines': lines,
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
