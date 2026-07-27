import '../models/sale.dart';
import '../repositories/sale_repository.dart';

class SaleService {
  final SaleRepository _repository = SaleRepository();

  Future<String> createSale({
    required String? customerId,
    required String? customerName,
    required List<Map<String, dynamic>> items,
    required double discount,
    required String paymentType,
    String? createdBy,
    String? deviceId,
  }) async {
    return await _repository.createSale(
      customerId: customerId,
      customerName: customerName,
      items: items,
      discount: discount,
      paymentType: paymentType,
      createdBy: createdBy,
      deviceId: deviceId,
    );
  }

  Future<List<Sale>> getTodaySales() async {
    return await _repository.getTodaySales();
  }
}
