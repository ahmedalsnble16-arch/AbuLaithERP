import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/repositories/treasury_repository.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final TreasuryRepository _treasuryRepo = TreasuryRepository();
  bool _isSaving = false;

  Future<void> _deposit() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;
    setState(() => _isSaving = true);
    await _treasuryRepo.addReceipt(amount: amount, sourceModule: 'معرض', note: _noteController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التوريد')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('توريد للخزنة')),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: _amountController, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
        const SizedBox(height: 12), TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'ملاحظات')),
        const SizedBox(height: 24), ElevatedButton(onPressed: _isSaving ? null : _deposit, child: const Text('تأكيد التوريد')),
      ])),
    );
  }
}
