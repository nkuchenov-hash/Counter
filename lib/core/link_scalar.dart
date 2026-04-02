/// Unwrap link / belongsTo payloads to a single id value (API-agnostic).
dynamic normalizeLinkScalar(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    final m = Map<String, dynamic>.from(raw);
    final v = m['id'] ?? m['Id'] ?? m['ID'] ?? m['category_id'];
    if (v != null) return v;
    return raw;
  }
  if (raw is List && raw.isNotEmpty) {
    final first = raw.first;
    if (first is Map) {
      return normalizeLinkScalar(first);
    }
    return first;
  }
  return raw;
}
