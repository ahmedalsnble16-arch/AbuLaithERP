import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/sale.dart';

class SaleRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<String> createSale({
    required String? customerId,
    required String? customerName,
    required List<Map<String, dynamic>> items,
    required double discount,
    required String paymentType,
    String? createdBy,
    String? deviceId,
  }) async {
    final db = await _dbHelper.database;
    final saleId = _uuid.v4();
    final now = DatabaseHelper.now;
    final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';

    double total = 0;
    for (var item in items) {
      total += (item['quantity'] as int) * (item['unitPrice'] as double);
    }
    double grandTotal = total - discount;
    if (grandTotal < 0) grandTotal = 0;

    await db.insert(DBConstants.tableSales, {
      'id': saleId,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'total': total,
      'discount': discount,
      'grand_total': grandTotal,
      'payment_type': paymentType,
      'payment_status': paymentType == 'نقدي' ? 'مدفوعة' : 'غير مدفوعة',
      'sale_date': DateTime.now().toIso8601String().substring(0, 10),
      'status': 'معتمدة',
      'created_at': now,
      'updated_at': now,
      'created_by': createdBy,
      'device_id': deviceId,
      'sync_status': 'Pending',
      'deleted': 0,
    });

    for (var item in items) {
      final productId = item['productId'] as String;
      final quantity = item['quantity'] as int;
      final unitPrice = (item['unitPrice'] as double);
      final itemTotal = quantity * unitPrice;

      await db.insert(DBConstants.tableSaleItems, {
        'id': _uuid.v4(),
        'sale_id': saleId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total': itemTotal,
        'created_at': now,
      });

      final showroomStock = await db.query(
        DBConstants.tableShowroomStock,
        where: 'product_id = ?',
        whereArgs: [productId],
      );

      if (showroomStock.isNotEmpty) {
        final currentQty = showroomStock.first['quantity'] as int? ?? 0;
        final newQty = currentQty - quantity;
        await db.update(
          DBConstants.tableShowroomStock,
          {'quantity': newQty < 0 ? 0 : newQty, 'updated_at': now},
          where: 'product_id = ?',
          whereArgs: [productId],
        );
      }
    }

    if (paymentType == 'نقدي') {
      await db.insert(DBConstants.tableTreasury, {
        'id': _uuid.v4(),
        'transaction_number': 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        'transaction_type': 'قبض',
        'amount': grandTotal,
        'source_module': 'معرض',
        'source_id': saleId,
        'note': 'فاتورة $invoiceNumber',
        'transaction_date': DateTime.now().toIso8601String().substring(0, 10),
        'status': 'معتمدة',
        'created_at': now,
        'updated_at': now,
        'created_by': createdBy,
        'device_id': deviceId,
        'sync_status': 'Pending',
      });
    }

    return saleId;
  }

  Future<List<Sale>> getTodaySales() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final maps = await db.query(
      DBConstants.tableSales,
      where: 'sale_date = ? AND deleted = 0',
      whereArgs: [today],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Sale.fromMap(map)).toList();
  }
}
