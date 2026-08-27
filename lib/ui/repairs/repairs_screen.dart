import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final TextEditingController _searchController = TextEditingController();
  
  List<Repair> _repairs = [];
  List<Repair> _filteredRepairs = [];
  List<String> _repairTypes = [];
  
  double _todayTotal = 0;
  double _monthTotal = 0;
  double _yearTotal = 0;
  double _allTotal = 0;
  int _count = 0;
  
  bool _isLoading = true;
  String? _selectedTypeFilter;
  String? _selectedDateFilter;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _repairs = await _repo.getAll();
      _filteredRepairs = List.from(_repairs);
      _repairTypes = await _repo.getRepairTypes();
      _todayTotal = await _repo.getTodayTotal();
      _monthTotal = await _repo.getMonthTotal();
      _yearTotal = await _repo.getYearTotal();
      _allTotal = await _repo.getTotalAll();
      _count = await _repo.getCount();
    } catch (e) {
      _showError('خطأ في تحميل البيانات: $e');
    }
    setState(() => _isLoading = false);
  }

  void _applyFilters() {
    setState(() {
      _filteredRepairs = _repairs.where((repair) {
        bool matchesSearch = true;
        bool matchesType = true;
        bool matchesDate = true;

        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          matchesSearch = repair.description.toLowerCase().contains(query) ||
              repair.repairType.toLowerCase().contains(query) ||
              repair.id.toLowerCase().contains(query);
        }

        if (_selectedTypeFilter != null && _selectedTypeFilter!.isNotEmpty) {
          matchesType = repair.repairType == _selectedTypeFilter;
        }

        if (_fromDate != null && _toDate != null) {
          final repairDate = DateTime.tryParse(repair.repairDate);
          if (repairDate != null) {
            matchesDate = repairDate.isAfter(_fromDate!.subtract(const Duration(days: 1))) &&
                repairDate.isBefore(_toDate!.add(const Duration(days: 1)));
          }
        } else if (_selectedDateFilter != null && _selectedDateFilter!.isNotEmpty) {
          matchesDate = repair.repairDate == _selectedDateFilter;
        }

        return matchesSearch && matchesType && matchesDate;
      }).toList();
    });
  }

  Future<void> _addRepair() async {
    final typeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    String? selectedType;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('إضافة إصلاح', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'نوع الإصلاح *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  value: selectedType,
                  items: _repairTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setStateDialog(() => selectedType = v),
                  validator: (v) => v == null ? 'اختر النوع' : null,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل الإصلاح *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'القيمة (ريال) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.money),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'التاريخ',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      dateCtrl.text = picked.toIso8601String().substring(0, 10);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('حفظ الإصلاح'),
              onPressed: () async {
                if (selectedType == null) {
                  _showError('يرجى اختيار نوع الإصلاح');
                  return;
                }
                if (descCtrl.text.trim().isEmpty) {
                  _showError('يرجى إدخال تفاصيل الإصلاح');
                  return;
                }
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) {
                  _showError('يرجى إدخال قيمة صحيحة');
                  return;
                }

                try {
                  await _repo.addRepair(
                    repairType: selectedType!,
                    description: descCtrl.text.trim(),
                    amount: amount,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    repairDate: dateCtrl.text,
                    createdBy: 'admin',
                  );
                  Navigator.pop(ctx, true);
                  _showSuccess('تم حفظ الإصلاح بنجاح');
                } catch (e) {
                  _showError('فشل الحفظ: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _editRepair(Repair repair) async {
    final typeCtrl = TextEditingController(text: repair.repairType);
    final descCtrl = TextEditingController(text: repair.description);
    final amountCtrl = TextEditingController(text: repair.amount.toString());
    final notesCtrl = TextEditingController(text: repair.notes ?? '');
    String? selectedType = repair.repairType;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('تعديل إصلاح', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'نوع الإصلاح *',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedType,
                  items: _repairTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setStateDialog(() => selectedType = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل الإصلاح *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'القيمة (ريال) *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('حفظ التعديل'),
              onPressed: () async {
                if (selectedType == null || descCtrl.text.trim().isEmpty) {
                  _showError('يرجى إكمال البيانات المطلوبة');
                  return;
                }
                final newAmount = double.tryParse(amountCtrl.text);
                if (newAmount == null || newAmount <= 0) {
                  _showError('يرجى إدخال قيمة صحيحة');
                  return;
                }

                try {
                  await _repo.updateRepair(
                    repairId: repair.id,
                    repairType: selectedType!,
                    description: descCtrl.text.trim(),
                    newAmount: newAmount,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  Navigator.pop(ctx, true);
                  _showSuccess('تم تعديل الإصلاح بنجاح');
                } catch (e) {
                  _showError('فشل التعديل: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _cancelRepair(Repair repair) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الإصلاح'),
        content: Text('هل أنت متأكد من إلغاء هذا الإصلاح؟\n\nسيتم عكس حركة الخزنة المرتبطة به.\n\nالمبلغ: ${repair.amount} ريال'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.cancelRepair(repair.id);
        _showSuccess('تم إلغاء الإصلاح وعكس حركة الخزنة');
        _loadData();
      } catch (e) {
        _showError('فشل الإلغاء: $e');
      }
    }
  }

  void _showRepairDetails(Repair repair) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.build, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('تفاصيل الإصلاح'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('رقم الإصلاح', repair.id),
              _detailRow('النوع', repair.repairType),
              _detailRow('التفاصيل', repair.description),
              _detailRow('القيمة', '${repair.amount.toStringAsFixed(0)} ريال'),
              _detailRow('التاريخ', repair.repairDate),
              _detailRow('الوقت', repair.repairTime ?? '-'),
              _detailRow('المستخدم', repair.createdBy ?? '-'),
              _detailRow('رقم حركة الخزنة', repair.treasuryTransactionId ?? '-'),
              _detailRow('الحالة', repair.status),
              if (repair.notes != null && repair.notes!.isNotEmpty)
                _detailRow('ملاحظات', repair.notes!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMonthlyReport() async {
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('الجرد الشهري للإصلاحات'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'الشهر'),
                        value: selectedMonth,
                        items: List.generate(12, (i) => i + 1).map((m) {
                          return DropdownMenuItem(value: m, child: Text('شهر $m'));
                        }).toList(),
                        onChanged: (v) => setStateDialog(() => selectedMonth = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'السنة'),
                        value: selectedYear,
                        items: List.generate(5, (i) => DateTime.now().year - i).map((y) {
                          return DropdownMenuItem(value: y, child: Text('$y'));
                        }).toList(),
                        onChanged: (v) => setStateDialog(() => selectedYear = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder(
                  future: _repo.getMonthlyReport(month: selectedMonth, year: selectedYear),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('لا توجد إصلاحات في هذا الشهر'));
                    }
                    final data = snapshot.data!;
                    double total = 0;
                    return Column(
                      children: [
                        Table(
                          border: TableBorder.all(color: Colors.grey.shade300),
                          columnWidths: const {
                            0: FlexColumnWidth(0.5),
                            1: FlexColumnWidth(1.5),
                            2: FlexColumnWidth(1.5),
                            3: FlexColumnWidth(2),
                            4: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: AppTheme.primaryColor.withAlpha(20)),
                              children: const [
                                Padding(padding: EdgeInsets.all(8), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(8), child: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(8), child: Text('النوع', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(8), child: Text('التفاصيل', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(8), child: Text('القيمة', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            ...data.asMap().entries.map((entry) {
                              final index = entry.key + 1;
                              final row = entry.value;
                              total += (row['amount'] as num?)?.toDouble() ?? 0;
                              return TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(8), child: Text('$index')),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(row['repair_date']?.toString() ?? '')),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(row['repair_type']?.toString() ?? '')),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(row['description']?.toString() ?? '')),
                                  Padding(padding: const EdgeInsets.all(8), child: Text('${((row['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}')),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('إجمالي الشهر:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('${total.toStringAsFixed(0)} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.errorColor)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showYearlyReport() async {
    int selectedYear = DateTime.now().year;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('الجرد السنوي للإصلاحات'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'السنة'),
                  value: selectedYear,
                  items: List.generate(5, (i) => DateTime.now().year - i).map((y) {
                    return DropdownMenuItem(value: y, child: Text('$y'));
                  }).toList(),
                  onChanged: (v) => setStateDialog(() => selectedYear = v!),
                ),
                const SizedBox(height: 16),
                FutureBuilder(
                  future: _repo.getYearlyReport(year: selectedYear),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('لا توجد إصلاحات في هذه السنة'));
                    }
                    final data = snapshot.data!;
                    final monthNames = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
                    double totalAll = 0;
                    return Column(
                      children: [
                        Table(
                          border: TableBorder.all(color: Colors.grey.shade300),
                          columnWidths: const {
                            0: FlexColumnWidth(1.5),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1.5),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: AppTheme.primaryColor.withAlpha(20)),
                              children: const [
                                Padding(padding: EdgeInsets.all(8), child: Text('الشهر', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(8), child: Text('عدد الإصلاحات', style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(8), child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            ...data.map((row) {
                              final month = int.tryParse(row['month']?.toString() ?? '') ?? 0;
                              final count = (row['count'] as num?)?.toInt() ?? 0;
                              final total = (row['total'] as num?)?.toDouble() ?? 0;
                              totalAll += total;
                              return TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(8), child: Text(month > 0 && month <= 12 ? monthNames[month - 1] : '-')),
                                  Padding(padding: const EdgeInsets.all(8), child: Text('$count')),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(total.toStringAsFixed(0))),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('إجمالي السنة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('${totalAll.toStringAsFixed(0)} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.errorColor)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('تصفية الإصلاحات'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String?>(
                decoration: const InputDecoration(labelText: 'نوع الإصلاح'),
                value: _selectedTypeFilter,
                items: [
                  const DropdownMenuItem(value: null, child: Text('الكل')),
                  ..._repairTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                ],
                onChanged: (v) => setStateDialog(() => _selectedTypeFilter = v),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('من تاريخ'),
                subtitle: Text(_fromDate != null ? _fromDate!.toIso8601String().substring(0, 10) : 'اختر التاريخ'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: _fromDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setStateDialog(() => _fromDate = picked);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('إلى تاريخ'),
                subtitle: Text(_toDate != null ? _toDate!.toIso8601String().substring(0, 10) : 'اختر التاريخ'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: _toDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setStateDialog(() => _toDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedTypeFilter = null;
                  _fromDate = null;
                  _toDate = null;
                  _applyFilters();
                });
                Navigator.pop(ctx);
              },
              child: const Text('مسح التصفية'),
            ),
            ElevatedButton(
              onPressed: () {
                _applyFilters();
                Navigator.pop(ctx);
              },
              child: const Text('تطبيق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإصلاحات والتطويرات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'تصفية',
          ),
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
                          _statCard('إصلاحات اليوم', _todayTotal, Colors.orange),
                          const SizedBox(width: 8),
                          _statCard('إصلاحات الشهر', _monthTotal, AppTheme.primaryColor),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _statCard('إصلاحات السنة', _yearTotal, Colors.purple),
                          const SizedBox(width: 8),
                          _statCard('عدد الإصلاحات', _count.toDouble(), Colors.teal),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _statCard('إجمالي الإصلاحات الكلي', _allTotal, Colors.red),
                    ],
                  ),
                ),

                // الأزرار الرئيسية
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _addRepair,
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة إصلاح'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showMonthlyReport,
                              icon: const Icon(Icons.calendar_month),
                              label: const Text('الجرد الشهري'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showYearlyReport,
                              icon: const Icon(Icons.calendar_year),
                              label: const Text('الجرد السنوي'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // البحث
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _applyFilters(),
                    decoration: InputDecoration(
                      hintText: 'بحث في التفاصيل أو النوع أو الرقم...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // كشف الإصلاحات
                Expanded(
                  child: _filteredRepairs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.build, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد إصلاحات مسجلة',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredRepairs.length,
                          itemBuilder: (context, index) {
                            final repair = _filteredRepairs[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor.withAlpha(20),
                                  child: Icon(Icons.build, color: AppTheme.primaryColor),
                                ),
                                title: Text(
                                  repair.description,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${repair.repairType}'),
                                    Text(
                                      '${repair.repairDate} ${repair.repairTime ?? ''}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${repair.amount.toStringAsFixed(0)} ريال',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'details':
                                            _showRepairDetails(repair);
                                            break;
                                          case 'edit':
                                            _editRepair(repair);
                                            break;
                                          case 'cancel':
                                            _cancelRepair(repair);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'details', child: Row(children: [Icon(Icons.visibility, size: 18), SizedBox(width: 8), Text('التفاصيل')])),
                                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('تعديل')])),
                                        const PopupMenuItem(value: 'cancel', child: Row(children: [Icon(Icons.cancel, size: 18), SizedBox(width: 8), Text('إلغاء')])),
                                      ],
                                    ),
                                  ],
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
        elevation: 2,
        color: color.withAlpha(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                amount.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
