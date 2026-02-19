/// A single observation from the quantitation table.
/// Maps one peptide measurement in one sample.
class QuantitationData {
  /// Normalized log-transformed abundance value.
  final double y;

  /// Row index -- identifies the peptide.
  final int ri;

  /// Column index -- identifies the sample.
  final int ci;

  /// Batch label (e.g., "a", "b").
  final String batch;

  const QuantitationData({
    required this.y,
    required this.ri,
    required this.ci,
    required this.batch,
  });
}
