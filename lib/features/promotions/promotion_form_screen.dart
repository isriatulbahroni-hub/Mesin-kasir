import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'providers/promotions_provider.dart';

class PromotionFormScreen extends ConsumerStatefulWidget {
  const PromotionFormScreen({super.key});

  @override
  ConsumerState<PromotionFormScreen> createState() => _PromotionFormScreenState();
}

class _PromotionFormScreenState extends ConsumerState<PromotionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _minPurchaseCtrl = TextEditingController(text: '0');
  final _maxDiscountCtrl = TextEditingController();
  final _usageLimitCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String _type = 'percentage';
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime.now().add(const Duration(days: 30));
  bool _submitting = false;

  // Dynamic pricing (jadwal berulang) - opsional, buat happy hour/harga weekend dll.
  bool _useSchedule = false;
  final Set<int> _selectedDays = {}; // 0=Minggu..6=Sabtu
  TimeOfDay? _timeStart;
  TimeOfDay? _timeEnd;
  bool _autoApply = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _valueCtrl, _minPurchaseCtrl, _maxDiscountCtrl, _usageLimitCtrl, _codeCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startsAt : _endsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = picked;
      } else {
        _endsAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endsAt.isBefore(_startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanggal berakhir harus setelah tanggal mulai.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(promotionControllerProvider).create(
            name: _nameCtrl.text,
            promotionType: _type,
            value: int.tryParse(_valueCtrl.text.trim()) ?? 0,
            minimumPurchase: int.tryParse(_minPurchaseCtrl.text.trim()) ?? 0,
            maximumDiscount: _maxDiscountCtrl.text.trim().isEmpty ? null : int.tryParse(_maxDiscountCtrl.text.trim()),
            usageLimit: _usageLimitCtrl.text.trim().isEmpty ? null : int.tryParse(_usageLimitCtrl.text.trim()),
            code: _type == 'voucher' ? _codeCtrl.text : null,
            startsAt: _startsAt,
            endsAt: _endsAt,
            activeDays: (_useSchedule && _selectedDays.isNotEmpty) ? _selectedDays.toList() : null,
            activeTimeStart: (_useSchedule && _timeStart != null)
                ? '${_timeStart!.hour.toString().padLeft(2, '0')}:${_timeStart!.minute.toString().padLeft(2, '0')}:00'
                : null,
            activeTimeEnd: (_useSchedule && _timeEnd != null)
                ? '${_timeEnd!.hour.toString().padLeft(2, '0')}:${_timeEnd!.minute.toString().padLeft(2, '0')}:00'
                : null,
            autoApply: _useSchedule && _autoApply,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _dayShortLabel(int i) => const ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'][i];

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy', 'id_ID');
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Promo/Voucher')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Promo'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Jenis'),
                items: const [
                  DropdownMenuItem(value: 'percentage', child: Text('Diskon Persen (%)')),
                  DropdownMenuItem(value: 'fixed', child: Text('Diskon Nominal (Rp) — otomatis di keranjang')),
                  DropdownMenuItem(value: 'voucher', child: Text('Voucher Kode (Rp) — kasir input kode')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'percentage'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valueCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: _type == 'percentage' ? 'Nilai (%)' : 'Nilai (Rp)'),
                validator: (v) => int.tryParse(v ?? '') == null ? 'Angka valid' : null,
              ),
              if (_type == 'voucher') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Kode Voucher', hintText: 'mis. HEMAT10'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi untuk voucher' : null,
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _minPurchaseCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min. Belanja', prefixText: 'Rp '),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _maxDiscountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Maks. Diskon (opsional)', prefixText: 'Rp '),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usageLimitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Batas Pemakaian (opsional, kosongkan = tanpa batas)'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text('Mulai: ${df.format(_startsAt)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: Text('Selesai: ${df.format(_endsAt)}'),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Jadwal Berulang (Dynamic Pricing)'),
                subtitle: const Text('Batasi promo ke hari/jam tertentu, mis. happy hour atau harga weekend'),
                value: _useSchedule,
                onChanged: (v) => setState(() => _useSchedule = v),
              ),
              if (_useSchedule) ...[
                const SizedBox(height: 8),
                const Text('Hari aktif (kosongkan = semua hari)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (int i = 0; i < 7; i++)
                      FilterChip(
                        label: Text(_dayShortLabel(i)),
                        selected: _selectedDays.contains(i),
                        onSelected: (sel) => setState(() {
                          if (sel) { _selectedDays.add(i); } else { _selectedDays.remove(i); }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: _timeStart ?? const TimeOfDay(hour: 0, minute: 0));
                        if (picked != null) setState(() => _timeStart = picked);
                      },
                      child: Text(_timeStart == null ? 'Jam Mulai (opsional)' : 'Mulai: ${_timeStart!.format(context)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: _timeEnd ?? const TimeOfDay(hour: 23, minute: 59));
                        if (picked != null) setState(() => _timeEnd = picked);
                      },
                      child: Text(_timeEnd == null ? 'Jam Selesai (opsional)' : 'Selesai: ${_timeEnd!.format(context)}'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Otomatis aktif tanpa kode'),
                  subtitle: const Text('Kasir langsung lihat promo ini aktif kalau jadwalnya cocok, gak perlu input kode'),
                  value: _autoApply,
                  onChanged: (v) => setState(() => _autoApply = v),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
