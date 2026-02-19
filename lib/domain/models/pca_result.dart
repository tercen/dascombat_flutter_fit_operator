/// One point in a PCA scatter plot, representing one sample.
class PcaPoint {
  /// PC1 score for this sample.
  final double pc1;

  /// PC2 score for this sample.
  final double pc2;

  /// Column index -- identifies the sample.
  final int ci;

  /// Batch label (e.g., "a", "b").
  final String batch;

  /// Display-friendly sample name for the tooltip.
  final String sampleName;

  const PcaPoint({
    required this.pc1,
    required this.pc2,
    required this.ci,
    required this.batch,
    required this.sampleName,
  });
}

/// Complete PCA result for one scatter plot (before or after correction).
class PcaResult {
  /// All sample points in PC1/PC2 space.
  final List<PcaPoint> points;

  /// Percentage of variance explained by PC1.
  final double varianceExplainedPc1;

  /// Percentage of variance explained by PC2.
  final double varianceExplainedPc2;

  const PcaResult({
    required this.points,
    required this.varianceExplainedPc1,
    required this.varianceExplainedPc2,
  });
}

/// Contains both before and after PCA results for display,
/// plus the corrected matrix data needed for saving back to Tercen.
class CorrectionResult {
  /// PCA of the uncorrected data.
  final PcaResult before;

  /// PCA of the corrected data.
  final PcaResult after;

  /// Distinct batch labels found in the data.
  final List<String> batchLabels;

  /// Corrected data matrix (peptides x samples) for saving to Tercen.
  final List<List<double>>? correctedMatrix;

  /// Ordered list of .ci values (sample indices) matching matrix columns.
  final List<int>? ciOrder;

  /// Ordered list of .ri values (peptide indices) matching matrix rows.
  final List<int>? riOrder;

  /// Serialized ComBat model parameters (JSON string) for model save.
  final String? modelJson;

  const CorrectionResult({
    required this.before,
    required this.after,
    required this.batchLabels,
    this.correctedMatrix,
    this.ciOrder,
    this.riOrder,
    this.modelJson,
  });
}
