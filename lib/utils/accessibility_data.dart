import 'dart:convert';

List<String> parseAccessibilityFeatures(Object? value) {
  if (value is! String) return const [];
  final normalized = value.trim();
  if (normalized.isEmpty || _isAccessibilityPlaceholder(normalized)) {
    return const [];
  }

  try {
    final decoded = jsonDecode(normalized);
    if (decoded is Map<String, dynamic>) {
      final accessibility = decoded['accessibility'];
      if (accessibility is Map<String, dynamic>) {
        return _accessibilityLabels.entries
            .where((entry) => accessibility[entry.key] is bool)
            .map((entry) {
              final available = accessibility[entry.key] as bool;
              return available
                  ? entry.value
                  : '${entry.value} — não disponível';
            })
            .toList();
      }
    }
  } on FormatException {
    // Existing records may use a plain-text list instead of JSON.
  }

  return normalized
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

const _accessibilityLabels = {
  'elevator': 'Elevador',
  'ramp': 'Rampa',
  'tactileFloor': 'Piso tátil',
  'braille': 'Sinalização em braille',
  'accessibleRestroom': 'Banheiro acessível',
  'visualAnnouncements': 'Avisos visuais',
  'audioAnnouncements': 'Avisos sonoros',
  'wheelchairAccess': 'Acesso para cadeira de rodas',
  'sensoryRoom': 'Sala sensorial',
};

String accessibilitySummary(Object? value) {
  final features = parseAccessibilityFeatures(value);
  return features.isEmpty
      ? 'Ainda sem informações cadastradas.'
      : features.join(', ');
}

bool _isAccessibilityPlaceholder(String value) => const {
  'consultar',
  'a consultar',
  'não informado',
  'nao informado',
  'não cadastrada',
  'não cadastrado',
  'sem informação',
  'sem informacao',
  'n/a',
  '-',
}.contains(value.toLowerCase());
