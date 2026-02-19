/// Column metadata for one sample.
class SampleMetadata {
  /// Biological condition (e.g., "Control", "T1", "T2", "T3").
  final String testCondition;

  /// Instrument run / batch identifier (e.g., "a", "b").
  final String run;

  /// Sample barcode identifier.
  final String barcode;

  const SampleMetadata({
    required this.testCondition,
    required this.run,
    required this.barcode,
  });

  /// Display-friendly sample name.
  String get displayName => '$testCondition ($barcode)';
}
