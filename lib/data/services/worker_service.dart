import '../models/worker.dart';
import '../repositories/worker_repository.dart';
import '../repositories/worker_account_repository.dart';

class WorkerService {
  final WorkerRepository _repository = WorkerRepository();

  Future<List<Worker>> getAllWorkers() async {
    return await _repository.getAll();
  }

  Future<void> addWorker(Worker worker) async {
    await _repository.add(worker);
  }

  Future<void> updateWorker(Worker worker) async {
    await _repository.update(worker);
  }

  Future<void> deleteWorker(String id) async {
    await _repository.delete(id);
  }

  Future<List<Map<String, dynamic>>> getWorkerTransactions(String workerId) async {
    final workerAccountRepo = WorkerAccountRepository();
    return await workerAccountRepo.getByWorkerId(workerId);
  }

  Future<void> addWorkerTransaction({
    required String workerId,
    required String type,
    required double amount,
    String? description,
  }) async {
    final workerAccountRepo = WorkerAccountRepository();
    await workerAccountRepo.add({
      'worker_id': workerId,
      'transaction_type': type,
      'amount': amount,
      'description': description,
      'transaction_date': DateTime.now().toIso8601String().substring(0, 10),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
