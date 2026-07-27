import '../models/purchase.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/purchase_item_repository.dart';

class PurchaseService {
  final PurchaseRepository _repository = PurchaseRepository();

  Future<List<Purchase>> getAllPurchases() async {
    return await _repository.getAll();
  }

  Future<void> addPurchase(Purchase purchase) async {
    await _repository.add(purchase);
  }

  Future<void> updatePurchase(Purchase purchase) async {
    await _repository.update(purchase);
  }

  Future<void> deletePurchase(String id) async {
    await _repository.delete(id);
  }

  Future<List<Map<String, dynamic>>> getPurchaseItems(String purchaseId) async {
    final purchaseItemRepo = PurchaseItemRepository();
    return await purchaseItemRepo.getByPurchaseId(purchaseId);
  }

  Future<void> addPurchaseItem(Map<String, dynamic> item) async {
    final purchaseItemRepo = PurchaseItemRepository();
    await purchaseItemRepo.add(item);
  }
}
