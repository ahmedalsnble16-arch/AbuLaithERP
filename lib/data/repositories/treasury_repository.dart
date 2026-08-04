Future<String> addTransaction(Treasury transaction,
    {DatabaseExecutor? txn}) async {
  final db = txn ?? await _dbHelper.database;
  final id = transaction.id.isNotEmpty ? transaction.id : _uuid.v4();
  final transactionNumber =
      'TXN-${DateTime.now().millisecondsSinceEpoch}-${id.substring(0, 4)}';

  if (transaction.amount <= 0) {
    throw Exception('المبلغ يجب أن يكون أكبر من صفر');
  }

  await db.insert(DBConstants.tableTreasury, {
    ...transaction.toMap(),
    'id': id,
    'transaction_number': transactionNumber,
  });

  // ✅ أضف سجل التدقيق
  await db.insert(DBConstants.tableAuditLogs, {
    'id': _uuid.v4(),
    'user_id': transaction.createdBy,
    'module': 'الخزنة',
    'action': transaction.transactionType == 'قبض' ? 'سند قبض' : 'سند صرف',
    'old_data': null,
    'new_data':
        '${transaction.transactionType == 'قبض' ? 'قبض' : 'صرف'} ${transaction.amount} - ${transaction.note ?? ''}',
    'device_id': transaction.deviceId,
    'created_at': DateTime.now().toIso8601String(),
  });

  return id;
}
