import '../models/distributor.dart';
import '../repositories/distributor_repository.dart';

class DistributorService {
  final DistributorRepository _repository = DistributorRepository();

  Future<List<Distributor>> getAllDistributors() async {
    return await _repository.getAll();
  }

  Future<String> addDistributor(Distributor distributor) async {
    return await _repository.addDistributor(distributor);
  }

  Future<void> updateDistributor(Distributor distributor) async {
    await _repository.updateDistributor(distributor);
  }

  Future<void> deleteDistributor(String id) async {
    await _repository.deleteDistributor(id);
  }

  Future<String> createLoad({
    required String distributorId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    return await _repository.createLoad(
      distributorId: distributorId,
      items: items,
      notes: notes,
    );
  }

  Future<String> settleDistributor({
    required String distributorId,
    required String loadId,
    required List<Map<String, dynamic>> items,
    required double collectedCash,
  }) async {
    return await _repository.settleDistributor(
      distributorId: distributorId,
      loadId: loadId,
      items: items,
      collectedCash: collectedCash,
    );
  }
}
