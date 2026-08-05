import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';

class WorkerAccountScreen extends StatefulWidget {
  final String workerId;
  final String workerName;

  const WorkerAccountScreen({
    super.key,
    required this.workerId,
    required this.workerName,
  });

  @override
  State<WorkerAccountScreen> createState() => _WorkerAccountScreenState();
}

class _WorkerAccountScreenState extends State<WorkerAccountScreen> {
  // بيانات العامل
  Map<String, dynamic>? _workerData;
  double _dailySalary = 0;
  double _dailyExpense = 0;

  // الشهر والسنة المحددين
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  // أيام الشهر مع بياناتها
  List<_DayData> _days = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;

    // 1. جلب بيانات العامل
    final workers = await db.query(
      'workers',
      where: 'id = ?',
      whereArgs: [widget.workerId],
    );
    if (workers.isNotEmpty) {
      _workerData = workers.first;
      _dailySalary = (_workerData?['daily_salary'] as num?)?.toDouble() ??
          (_workerData?['salary'] as num?)?.toDouble() ??
          0;
      _dailyExpense =
          (_workerData?['daily_expense'] as num?)?.toDouble() ?? 0;
    }

    // 2. بناء أيام الشهر
    final daysInMonth =
        DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    _days = [];

    for (int day = 1; day <= daysInMonth; day++) {
      final date =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

      // 2a. النشاط والمصروف من المعرض
      bool isActive = false;
      double showroomExpense = 0;
      double showroomAdvance = 0;

      // جدول showroom_worker_daily يربط العامل بالتاريخ في المعرض
      final showroomEntries = await db.query(
        'showroom_worker_daily',
        where: 'worker_id = ? AND business_date = ?',
        whereArgs: [widget.workerId, date],
      );
      if (showroomEntries.isNotEmpty) {
        final entry = showroomEntries.first;
        isActive = entry['is_active'] == 1;
        showroomExpense =
            (entry['daily_expense'] as num?)?.toDouble() ?? _dailyExpense;
        showroomAdvance =
            (entry['advance_amount'] as num?)?.toDouble() ?? 0;
      }

      // 2b. الإضافات والملحقات المسجلة لهذا اليوم
      final extras = await db.query(
        'worker_daily_extras',
        where: 'worker_id = ? AND entry_date = ?',
        whereArgs: [widget.workerId, date],
      );

      _days.add(_DayData(
        date: date,
        dayNumber: day,
        isActive: isActive,
        dailyExpense: showroomExpense,
        advanceAmount: showroomAdvance,
        extras: extras
            .map((e) => _ExtraEntry(
                  id: e['id']?.toString(),
                  amount:
                      (e['amount'] as num?)?.toDouble() ?? 0,
                  details: e['details'] ?? '',
                ))
            .toList(),
      ));
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveDay(_DayData day) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();

    // حفظ أو تحديث showroom_worker_daily
    final existing = await db.query(
      'showroom_worker_daily',
      where: 'worker_id = ? AND business_date = ?',
      whereArgs: [widget.workerId, day.date],
    );

    if (existing.isEmpty) {
      await db.insert('showroom_worker_daily', {
        'id': const Uuid().v4(),
        'worker_id': widget.workerId,
        'business_date': day.date,
        'is_active': day.isActive ? 1 : 0,
        'daily_expense': day.isActive ? _dailyExpense : 0,
        'advance_amount': day.advanceAmount,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        'showroom_worker_daily',
        {
          'is_active': day.isActive ? 1 : 0,
          'daily_expense': day.isActive ? _dailyExpense : 0,
          'advance_amount': day.advanceAmount,
          'updated_at': now,
        },
        where: 'worker_id = ? AND business_date = ?',
        whereArgs: [widget.workerId, day.date],
      );
    }

    // حفظ الإضافات والملحقات
    await db.delete(
      'worker_daily_extras',
      where: 'worker_id = ? AND entry_date = ?',
      whereArgs: [widget.workerId, day.date],
    );
    for (var extra in day.extras) {
      await db.insert('worker_daily_extras', {
        'id': extra.id ?? const Uuid().v4(),
        'worker_id': widget.workerId,
        'entry_date': day.date,
        'amount': extra.amount,
        'details': extra.details,
        'created_at': now,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ بيانات اليوم'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  void _addExtra(_DayData day) {
    setState(() {
      day.extras.add(_ExtraEntry(amount: 0, details: ''));
    });
  }

  void _removeExtra(_DayData day, int index) {
    setState(() {
      day.extras.removeAt(index);
    });
  }

  // ============ الحسابات ============
  int get _totalActiveDays =>
      _days.where((d) => d.isActive).length;
  double get _totalSalary =>
      _totalActiveDays * _dailySalary;
  double get _totalExpenses =>
      _days.where((d) => d.isActive).fold(0, (sum, d) => sum + d.dailyExpense);
  double get _totalAdvances =>
      _days.fold(0, (sum, d) => sum + d.advanceAmount);
  double get _totalExtras =>
      _days.fold(0, (sum, d) => sum + d.extras.fold(0, (s, e) => s + e.amount));
  double get _netSalary =>
      _totalSalary - _totalExpenses - _totalAdvances - _totalExtras;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب: ${widget.workerName}'),
        actions: [
          // اختيار الشهر والسنة
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(_selectedYear, _selectedMonth),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                helpText: 'اختر الشهر',
              );
              if (picked != null) {
                setState(() {
                  _selectedYear = picked.year;
                  _selectedMonth = picked.month;
                });
                _loadAllData();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // معلومات العامل
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _infoItem('الأجر اليومي', '$_dailySalary'),
                          _infoItem('المصروف اليومي', '$_dailyExpense'),
                          _infoItem('أيام النشاط', '$_totalActiveDays'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // عنوان الشهر
                  Center(
                    child: Text(
                      '${_selectedMonth}/${_selectedYear}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // جدول الأيام
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('اليوم')),
                        DataColumn(label: Text('نشط')),
                        DataColumn(label: Text('المصروف')),
                        DataColumn(label: Text('البرانيات')),
                        DataColumn(label: Text('ملحقات')),
                        DataColumn(label: Text('حفظ')),
                      ],
                      rows: _days.map((day) {
                        return DataRow(cells: [
                          DataCell(Text('${day.dayNumber}')),
                          DataCell(
                            Checkbox(
                              value: day.isActive,
                              onChanged: (v) {
                                setState(() => day.isActive = v ?? false);
                                if (day.isActive) {
                                  day.dailyExpense = _dailyExpense;
                                } else {
                                  day.dailyExpense = 0;
                                }
                              },
                            ),
                          ),
                          DataCell(Text('${day.dailyExpense}')),
                          DataCell(SizedBox(
                            width: 80,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(
                                  text: '${day.advanceAmount}'),
                              onChanged: (v) {
                                day.advanceAmount =
                                    double.tryParse(v) ?? 0;
                              },
                            ),
                          )),
                          DataCell(
                            Column(
                              children: [
                                ...day.extras.asMap().entries.map((e) {
                                  final i = e.key;
                                  final extra = e.value;
                                  return Row(
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        child: TextField(
                                          keyboardType:
                                              TextInputType.number,
                                          controller:
                                              TextEditingController(
                                                  text:
                                                      '${extra.amount}'),
                                          onChanged: (v) {
                                            extra.amount =
                                                double.tryParse(v) ??
                                                    0;
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            size: 16,
                                            color: AppTheme.errorColor),
                                        onPressed: () =>
                                            _removeExtra(day, i),
                                      ),
                                    ],
                                  );
                                }),
                                TextButton.icon(
                                  onPressed: () => _addExtra(day),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('إضافة',
                                      style:
                                          TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.save,
                                  color: AppTheme.primaryColor),
                              onPressed: () => _saveDay(day),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ملخص الحساب الشهري
                  Card(
                    color: AppTheme.primaryColor.withAlpha(15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _summaryRow(
                              'إجمالي أيام النشاط', '$_totalActiveDays يوم'),
                          _summaryRow(
                              'إجمالي الراتب', '$_totalSalary'),
                          _summaryRow(
                              'إجمالي المصاريف', '- $_totalExpenses'),
                          _summaryRow(
                              'إجمالي البرانيات', '- $_totalAdvances'),
                          _summaryRow(
                              'إجمالي الملحقات', '- $_totalExtras'),
                          const Divider(),
                          _summaryRow(
                            '💰 صافي حساب العامل',
                            '$_netSalary',
                            isBold: true,
                            color: _netSalary >= 0
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _summaryRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: isBold ? 18 : 14,
                  color: color)),
        ],
      ),
    );
  }
}

// ============ كائنات مساعدة ============
class _DayData {
  final String date;
  final int dayNumber;
  bool isActive;
  double dailyExpense;
  double advanceAmount;
  final List<_ExtraEntry> extras;

  _DayData({
    required this.date,
    required this.dayNumber,
    this.isActive = false,
    this.dailyExpense = 0,
    this.advanceAmount = 0,
    List<_ExtraEntry>? extras,
  }) : extras = extras ?? [];
}

class _ExtraEntry {
  String? id;
  double amount;
  String details;

  _ExtraEntry({
    this.id,
    this.amount = 0,
    this.details = '',
  });
}
