import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/repair.dart';
import '../../data/repositories/repair_repository.dart';

class RepairsScreen extends StatefulWidget {
  const RepairsScreen({super.key});

  @override
  State<RepairsScreen> createState() => _RepairsScreenState();
}

class _RepairsScreenState extends State<RepairsScreen> {
  final RepairRepository _repo = RepairRepository();
  List<Repair> _repairs = [];
  List<String> _repairTypes = [];
  double _todayTotal = 0;
  double _monthTotal = 0;
  double _yearTotal = 0;
  double _allTotal = 0;
  int _count = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _repairs = await _repo.getAll();
    _repairTypes = await _repo.getRepairTypes();
    _todayTotal = await _repo.getTodayTotal();
    _monthTotal = await _repo.getMonthTotal();
    _yearTotal = await _repo.getYearTotal();
    _allTotal = await _repo.getTotalAll();
    _count = await _repo.getCount();
    setState(() => _isLoading = false);
  }

  Future<void> _addRepair() async {
    final typeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? selectedType;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('إضافة إصلاح'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(labelText: 'نوع الإصلاح *'),
                  value: selectedType,
                  items: _repairTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setStateDialog(() => selectedType = v),
                ),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'تفاصيل الإصلاح *')),
                const SizedBox(height: 12),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'القيمة *'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (selectedType == null || descCtrl.text.trim().isEmpty) return;
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) return;

                await _repo.addRepair(
                  repairType: selectedType!,
                  description: descCtrl.text.trim(),
                  amount: amount,
                  notes: notesCtrl.text.trim(),
                  createdBy: 'admin',
                );
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ الإصلاح'),
            ),
          ],
        ),
      ),
    );
    if (result == true) _loadData();
  }

  void _showRepairDetails(Repair repair) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفاصيل الإصلاح'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('النوع', repair.repairType),
            _detailRow('التفاصيل', repair.description),
            _detailRow('القيمة', '${repair.amount}'),
            _detailRow('التاريخ', repair.repairDate),
            _detailRow('الوقت', repair.repairTime ?? '-'),
            _detailRow('رقم حركة الخزنة', repair.treasuryTransactionId ?? '-'),
            if (repair.notes != null) _detailRow('ملاحظات', repair.notes!),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإصلاحات'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // البطاقات الإحصائية
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _statCard('إصلاحات اليوم', _todayTotal, AppTheme.successColor),
                          _statCard('إصلاحات الشهر', _monthTotal, AppTheme.primaryColor),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _statCard('إصلاحات السنة', _yearTotal, AppTheme.warningColor),
                          _statCard('عدد الإصلاحات', _count.toDouble(), AppTheme.textPrimaryColor),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _statCard('إجمالي الإصلاحات الكلي', _allTotal, AppTheme.errorColor),
                    ],
                  ),
                ),

                // الأزرار
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addRepair,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة إصلاح'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // كشف الإصلاحات
                Expanded(
                  child: _repairs.isEmpty
                      ? const Center(child: Text('لا توجد إصلاحات مسجلة'))
                      : ListView.builder(
                          itemCount: _repairs.length,
                          itemBuilder: (context, index) {
                            final repair = _repairs[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.warningColor.withAlpha(20),
                                  child: const Icon(Icons.build, color: AppTheme.warningColor),
                                ),
                                title: Text(repair.description),
                                subtitle: Text('${repair.repairType} | ${repair.repairDate} ${repair.repairTime ?? ''}'),
                                trailing: Text(
                                  '${repair.amount}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor),
                                ),
                                onTap: () => _showRepairDetails(repair),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statCard(String title, double amount, Color color) {
    return Expanded(
      child: Card(
        color: color.withAlpha(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 4),
              Text(amount.toStringAsFixed(0), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
