import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/raw_material.dart';
import '../../data/repositories/raw_material_repository.dart';
import 'material_form_screen.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final RawMaterialRepository _materialRepo = RawMaterialRepository();
  List<RawMaterial> _materials = [];
  List<RawMaterial> _filteredMaterials = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    try {
      final materials = await _materialRepo.getAll();
      setState(() {
        _materials = materials;
        _filteredMaterials = materials;
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

  void _filterMaterials(String query) {
    setState(() {
      _filteredMaterials = _materials
          .where((m) => m.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المواد الخام')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'بحث عن مادة...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.clear),
              ),
              onChanged: _filterMaterials,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMaterials.isEmpty
                    ? const Center(child: Text('لا توجد مواد خام'))
                    : ListView.builder(
                        itemCount: _filteredMaterials.length,
                        itemBuilder: (context, index) {
                          final material = _filteredMaterials[index];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.brown,
                                child: Icon(Icons.grain, color: Colors.white),
                              ),
                              title: Text(material.name),
                              subtitle: Text('الوحدة: ${material.unit} | السعر: ${material.purchasePrice}'),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                                ],
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MaterialFormScreen(material: material),
                                      ),
                                    ).then((_) => _loadMaterials());
                                  } else if (value == 'delete') {
                                    await _materialRepo.delete(material.id);
                                    _loadMaterials();
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MaterialFormScreen()),
        ).then((_) => _loadMaterials()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
