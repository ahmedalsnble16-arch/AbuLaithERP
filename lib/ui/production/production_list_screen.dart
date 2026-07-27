import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/production_batch.dart';
import '../../data/repositories/production_repository.dart';

class ProductionListScreen extends StatefulWidget {
  const ProductionListScreen({super.key});

  @override
  State<ProductionListScreen> createState() => _ProductionListScreenState();
}

class _ProductionListScreenState extends State<ProductionListScreen> {
  final ProductionRepository _repo = ProductionRepository();
  List<ProductionBatch> _batches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      final batches = await _repo.getAllBatches();
      setState(() {
        _batches = batches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الإنتاج')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _batches.isEmpty
              ? const Center(child: Text('لا توجد دفعات إنتاج'))
              : ListView.builder(
                  itemCount: _batches.length,
                  itemBuilder: (context, index) {
                    final batch = _batches[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.deepOrange,
                          child: Icon(Icons.factory, color: Colors.white),
                        ),
                        title: Text(batch.productionNumber),
                        subtitle: Text('صالح: ${batch.goodPieces} | تالف: ${batch.damagedPieces}'),
                        trailing: Text(batch.status),
                      ),
                    );
                  },
                ),
    );
  }
}
