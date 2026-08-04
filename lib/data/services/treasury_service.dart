import '../models/treasury.dart';
import '../repositories/treasury_repository.dart';

class TreasuryService {
  final TreasuryRepository _repository = TreasuryRepository();

  Future<List<Treasury>> getAllTransactions({String? dateFilter}) async {
    return await _repository.getAll(dateFilter: dateFilter);
  }

  Future<String> addReceipt({
    required double amount,
    String? sourceModule,
    String? sourceId,
    String? note,
    String? createdBy,
    dynamic txn,
  }) async {
    return await _repository.addReceipt(
      amount: amount,
      sourceModule: sourceModule,
      sourceId: sourceId,
      note: note,
      createdBy: createdBy,
      txn: txn,
    );
  }

  Future<String> addPayment({
    required double amount,
    String? sourceModule,
    String? sourceId,
    String? note,
    String? createdBy,
    dynamic txn,
  }) async {
    return await _repository.addPayment(
      amount: amount,
      sourceModule: sourceModule,
      sourceId: sourceId,
      note: note,
      createdBy: createdBy,
      txn: txn,
    );
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
