import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/constants/db_constants.dart';

class ShowroomScreen extends StatefulWidget {
  const ShowroomScreen({super.key});

  @override
  State<ShowroomScreen> createState() => _ShowroomScreenState();
}

class _ShowroomScreenState extends State<ShowroomScreen> {
  List<Map<String, dynamic>> _stock = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final data = await db.rawQuery('''
        SELECT s.*, p.name as product_name, p.retail_price
        FROM ${DBConstants.tableShowroomStock} s
        INNER JOIN ${DBConstants.tableProducts} p ON s.product_id = p.id
        WHERE p.deleted = 0
        ORDER BY p.name ASC
      ''');
      setState(() {
        _stock = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المعرض')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stock.isEmpty
              ? const Center(child: Text('المعرض فارغ'))
              : ListView.builder(
                  itemCount: _stock.length,
                  itemBuilder: (context, index) {
                    final item = _stock[index];
                    final qty = item['quantity'] as int? ?? 0;
                    final price = (item['retail_price'] as num?)?.toDouble() ?? 0;
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.store, color: Colors.white),
                        ),
                        title: Text(item['product_name'] ?? ''),
                        subtitle: Text('الكمية: $qty | السعر: $price'),
                        trailing: Text('${qty * price} ر.ي'),
                      ),
                    );
                  },
                ),
    );
  }
}
