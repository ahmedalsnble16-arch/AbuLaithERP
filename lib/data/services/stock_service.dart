import '../repositories/stock_repository.dart';

class StockService {
  final StockRepository _repository = StockRepository();

  Future<List<Map<String, dynamic>>> getStockWithProductName({String? search}) async {
    return await _repository.getStockWithProductName(search: search);
  }
}
