import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/repositories/stock_repository.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final StockRepository _stockRepo = StockRepository();
  List<Map<String, dynamic>> _stockList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    setState(() => _isLoading = true);
    try {
      final stock = await _stockRepo.getStockWithProductName();
      setState(() {
        _stockList = stock;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مخزن الإنتاج')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stockList.isEmpty
              ? const Center(child: Text('المخزن فارغ'))
              : ListView.builder(
                  itemCount: _stockList.length,
                  itemBuilder: (context, index) {
                    final item = _stockList[index];
                    final qtyPieces = item['quantity_pieces'] as int? ?? 0;
                    final boxSize = item['pieces_per_box'] as int? ?? 1;
                    final boxes = boxSize > 0 ? qtyPieces ~/ boxSize : 0;
                    final remaining = boxSize > 0 ? qtyPieces % boxSize : 0;

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.primaryColor,
                          child: Icon(Icons.inventory, color: Colors.white),
                        ),
                        title: Text(item['product_name'] ?? ''),
                        subtitle: Text('$qtyPieces قطعة ($boxes سلة + $remaining قطعة)'),
                        trailing: Text(
                          'متاح',
                          style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
