import '../models/production_batch.dart';
import '../repositories/production_repository.dart';

class ProductionService {
  final ProductionRepository _repository = ProductionRepository();

  Future<List<ProductionBatch>> getAllBatches({String? search}) async {
    return await _repository.getAllBatches(search: search);
  }

  Future<String> createBatch(ProductionBatch batch) async {
    return await _repository.createBatch(batch);
  }

  Future<void> deleteBatch(String batchId) async {
    await _repository.deleteBatch(batchId);
  }
}
