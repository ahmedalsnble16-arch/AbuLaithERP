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
    if (items.isEmpty) {
      throw Exception('لا يمكن حفظ فاتورة بدون أصناف');
    }

    final db = await _dbHelper.database;
    final saleId = _uuid.v4();
    final now = DatabaseHelper.now;
    final shortId = saleId.substring(0, 4);
    final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}-$shortId';

    double total = 0;
    for (var item in items) {
      final q = item['quantity'] as int;
      final p = item['unitPrice'] as double;
      if (q <= 0) throw Exception('الكمية يجب أن تكون أكبر من صفر');
      if (p < 0) throw Exception('السعر غير صالح');
      total += q * p;
    }
    if (discount < 0) throw Exception('الخصم غير صالح');
    double grandTotal = total - discount;
    if (grandTotal < 0) grandTotal = 0;

    // كل العمليات داخل معاملة واحدة: أي خطأ = تراجع كامل (rollback)
    await db.transaction((txn) async {
      // 1) تحقّق من توفّر المخزون لكل صنف قبل أي كتابة
      for (var item in items) {
        final productId = item['productId'] as String;
        final quantity = item['quantity'] as int;

        final showroomStock = await txn.query(
          DBConstants.tableShowroomStock,
          where: 'product_id = ?',
          whereArgs: [productId],
        );
        final available =
            showroomStock.isEmpty ? 0 : (showroomStock.first['quantity'] as int? ?? 0);
        if (quantity > available) {
          throw Exception(
              'الكمية المطلوبة ($quantity) أكبر من المتاح في المعرض ($available) للمنتج $productId');
        }
      }

      // 2) رأس الفاتورة
      await txn.insert(DBConstants.tableSales, {
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

      // 3) الأصناف + خصم المخزون + حركة مخزون
      for (var item in items) {
        final productId = item['productId'] as String;
        final quantity = item['quantity'] as int;
        final unitPrice = item['unitPrice'] as double;
        final itemTotal = quantity * unitPrice;

        await txn.insert(DBConstants.tableSaleItems, {
          'id': _uuid.v4(),
          'sale_id': saleId,
          'product_id': productId,
          'quantity': quantity,
          'unit_price': unitPrice,
          'total': itemTotal,
          'created_at': now,
        });

        final showroomStock = await txn.query(
          DBConstants.tableShowroomStock,
          where: 'product_id = ?',
          whereArgs: [productId],
        );
        final currentQty = showroomStock.first['quantity'] as int? ?? 0;
        await txn.update(
          DBConstants.tableShowroomStock,
          {'quantity': currentQty - quantity, 'updated_at': now},
          where: 'product_id = ?',
          whereArgs: [productId],
        );

        await txn.insert(DBConstants.tableStockMovements, {
          'id': _uuid.v4(),
          'product_id': productId,
          'movement_type': 'بيع',
          'quantity': -quantity,
          'reference_id': saleId,
          'reference_type': 'sale',
          'notes': 'بيع فاتورة $invoiceNumber',
          'created_at': now,
          'created_by': createdBy,
          'device_id': deviceId,
          'sync_status': 'Pending',
        });
      }

      // 4) الخزنة (نقدي فقط)
      if (paymentType == 'نقدي') {
        await txn.insert(DBConstants.tableTreasury, {
          'id': _uuid.v4(),
          'transaction_number':
              'TXN-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4().substring(0, 4)}',
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

      // 5) سجل التدقيق
      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': createdBy,
        'module': 'مبيعات المعرض',
        'action': 'إنشاء فاتورة',
        'old_data': null,
        'new_data':
            'فاتورة $invoiceNumber بقيمة $grandTotal ($paymentType) - عدد الأصناف ${items.length}',
        'device_id': deviceId,
        'created_at': now,
      });
    });

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
