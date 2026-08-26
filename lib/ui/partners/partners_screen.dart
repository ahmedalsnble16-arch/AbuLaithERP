import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/partner.dart';
import '../../data/repositories/partner_repository.dart';
import 'partner_account_screen.dart';

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  final PartnerRepository _repo = PartnerRepository();
  List<Partner> _partners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    setState(() => _isLoading = true);
    final partners = await _repo.getAll();
    setState(() {
      _partners = partners;
      _isLoading = false;
    });
  }

  Future<void> _addPartner() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final salaryCtrl = TextEditingController(text: '0');
    final ownershipCtrl = TextEditingController(text: '0');
    final dueDayCtrl = TextEditingController(text: '1');
    final limitCtrl = TextEditingController(text: '0');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة شريك'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الشريك *')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
              TextField(controller: salaryCtrl, decoration: const InputDecoration(labelText: 'الراتب الشهري'), keyboardType: TextInputType.number),
              TextField(controller: ownershipCtrl, decoration: const InputDecoration(labelText: 'نسبة الملكية %'), keyboardType: TextInputType.number),
              TextField(controller: dueDayCtrl, decoration: const InputDecoration(labelText: 'يوم استحقاق الراتب'), keyboardType: TextInputType.number),
              TextField(controller: limitCtrl, decoration: const InputDecoration(labelText: 'الحد الشهري للسحبيات'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final now = DatabaseHelper.now;
              final partner = Partner(
                id: const Uuid().v4(),
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                monthlySalary: double.tryParse(salaryCtrl.text) ?? 0,
                ownershipPercent: double.tryParse(ownershipCtrl.text) ?? 0,
                salaryDueDay: int.tryParse(dueDayCtrl.text) ?? 1,
                maxWithdrawalLimit: double.tryParse(limitCtrl.text) ?? 0,
                createdAt: now,
                updatedAt: now,
              );
              await _repo.add(partner);
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result == true) _loadPartners();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الشركاء المالكين')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _partners.isEmpty
              ? const Center(child: Text('لا يوجد شركاء'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _partners.length,
                  itemBuilder: (context, index) {
                    final partner = _partners[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(partner.name.substring(0, 1), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(partner.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('نسبة الملكية: ${partner.ownershipPercent}% | الراتب: ${partner.monthlySalary}'),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PartnerAccountScreen(partner: partner),
                            ),
                          );
                          _loadPartners();
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPartner,
        child: const Icon(Icons.add),
      ),
    );
  }
}
