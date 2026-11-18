const _unaccentedCharacters = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
};

String normalizeStationSearch(String value) {
  final normalized = value
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
  return normalized
      .split('')
      .map((character) => _unaccentedCharacters[character] ?? character)
      .join();
}

List<Map<String, dynamic>> filterStations(
  Iterable<Map<String, dynamic>> stations,
  String query,
) {
  final normalizedQuery = normalizeStationSearch(query);
  if (normalizedQuery.isEmpty) return stations.toList();

  return stations.where((station) {
    final name = normalizeStationSearch(station['name'] as String? ?? '');
    final line = normalizeStationSearch(station['line'] as String? ?? '');
    return name.contains(normalizedQuery) || line.contains(normalizedQuery);
  }).toList();
}
