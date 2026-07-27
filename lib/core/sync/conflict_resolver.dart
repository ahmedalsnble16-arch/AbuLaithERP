class ConflictResolver {
  Map<String, dynamic> resolve(String table, Map<String, dynamic> local, Map<String, dynamic> remote) {
    final localTime = DateTime.tryParse(local['updated_at'] ?? '');
    final remoteTime = DateTime.tryParse(remote['updated_at'] ?? '');

    if (localTime == null && remoteTime == null) return local;
    if (localTime == null) return remote;
    if (remoteTime == null) return local;

    return localTime.isAfter(remoteTime) ? local : remote;
  }
}
