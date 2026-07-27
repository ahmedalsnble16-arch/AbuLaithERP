import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';

class RawMaterialMovementsScreen extends StatefulWidget {
  const RawMaterialMovementsScreen({super.key});

  @override
  State<RawMaterialMovementsScreen> createState() => _RawMaterialMovementsScreenState();
}

class _RawMaterialMovementsScreenState extends State<RawMaterialMovementsScreen> {
  List<Map<String, dynamic>> _movements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    final data = await db.query('raw_material_movements', orderBy: 'created_at DESC');
    setState(() { _movements = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حركة المواد الخام')),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _movements.length,
        itemBuilder: (context, index) {
          final m = _movements[index];
          return ListTile(title: Text('${m['quantity']} ${m['unit']}'), subtitle: Text(m['movement_type'] ?? ''));
        },
      ),
    );
  }
}
