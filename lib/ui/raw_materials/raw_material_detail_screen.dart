import 'package:flutter/material.dart';
import '../../data/models/raw_material.dart';

class RawMaterialDetailScreen extends StatelessWidget {
  final RawMaterial material;
  const RawMaterialDetailScreen({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(material.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(title: const Text('الاسم'), subtitle: Text(material.name)),
            ListTile(title: const Text('الوحدة'), subtitle: Text(material.unit)),
            ListTile(title: const Text('سعر الشراء'), subtitle: Text('${material.purchasePrice}')),
            ListTile(title: const Text('الحد الأدنى'), subtitle: Text('${material.minimumQty}')),
          ],
        ),
      ),
    );
  }
}
