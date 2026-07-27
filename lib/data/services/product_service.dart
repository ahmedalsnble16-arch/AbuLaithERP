import '../models/product.dart';
import '../repositories/product_repository.dart';

class ProductService {
  final ProductRepository _repository = ProductRepository();

  Future<List<Product>> getAllProducts({String? search}) async {
    return await _repository.getAll(search: search);
  }

  Future<String> addProduct(Product product) async {
    return await _repository.add(product);
  }

  Future<void> updateProduct(Product product) async {
    await _repository.update(product);
  }

  Future<void> deleteProduct(String id) async {
    await _repository.delete(id);
  }
}
