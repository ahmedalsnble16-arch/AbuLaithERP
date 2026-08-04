import '../models/treasury.dart';
import '../repositories/treasury_repository.dart';

class TreasuryService {
  final TreasuryRepository _repository = TreasuryRepository();

  Future<List<Treasury>> getAllTransactions({String? dateFilter}) async {
    return await _repository.getAll(dateFilter: dateFilter);
  }

  /// إضافة حركة مالية (مع دعم المعاملات الخارجية)
  Future<String> addTransaction(Treasury transaction, {dynamic txn}) async {
    return await _repository.addTransaction(transaction, txn: txn);
  }

  Future<String> addReceipt({
    required double amount,
    String? sourceModule,
    String? sourceId,
    String? note,
    String? createdBy,
    dynamic txn,
  }) async {
    final now = DateTime.now().toIso8601String();
    final transaction = Treasury(
      id: '',
      transactionNumber: '',
      transactionType: 'قبض',
      amount: amount,
      sourceModule: sourceModule,
      sourceId: sourceId,
      note: note,
      transactionDate: DateTime.now().toIso8601String().substring(0, 10),
      status: 'معتمدة',
      createdAt: now,
      updatedAt: now,
      createdBy: createdBy,
      deviceId: 'mobile',
    );
    return await _repository.addTransaction(transaction, txn: txn);
  }

  Future<String> addPayment({
    required double amount,
    String? sourceModule,
    String? sourceId,
    String? note,
    String? createdBy,
    dynamic txn,
  }) async {
    final now = DateTime.now().toIso8601String();
    final transaction = Treasury(
      id: '',
      transactionNumber: '',
      transactionType: 'صرف',
      amount: amount,
      sourceModule: sourceModule,
      sourceId: sourceId,
      note: note,
      transactionDate: DateTime.now().toIso8601String().substring(0, 10),
      status: 'معتمدة',
      createdAt: now,
      updatedAt: now,
      createdBy: createdBy,
      deviceId: 'mobile',
    );
    return await _repository.addTransaction(transaction, txn: txn);
  }

  Future<double> getCurrentBalance() async {
    return await _repository.getCurrentBalance();
  }

  Future<double> getTodayReceipts() async {
    return await _repository.getTodayReceipts();
  }

  Future<double> getTodayPayments() async {
    return await _repository.getTodayPayments();
  }
}
