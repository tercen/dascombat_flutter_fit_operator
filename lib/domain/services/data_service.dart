import '../models/pca_result.dart';

/// Abstract data service interface for the DASCombat operator.
///
/// Phase 2: Mock implementation loads from CSV assets and computes mock PCA.
/// Phase 3: Real implementation queries Tercen API via sci_tercen_context.
abstract class DataService {
  /// Load raw data, compute batch correction, and return before/after PCA results.
  ///
  /// [modelType] is "L/S" (location + scale) or "L" (location only).
  /// [referenceBatch] is "None" or a batch label.
  /// [mode] is "Fit Model" or "Apply Model".
  Future<CorrectionResult> computeCorrection({
    required String modelType,
    required String referenceBatch,
    required String mode,
  });

  /// Load the distinct batch labels from the data.
  Future<List<String>> loadBatchLabels();

  /// Save corrected values back to Tercen.
  ///
  /// [correctedMatrix] is peptides x samples matrix of corrected values.
  /// [ciOrder] is the ordered list of .ci values (sample indices).
  /// [riOrder] is the ordered list of .ri values (peptide indices).
  Future<void> saveResults({
    required List<List<double>> correctedMatrix,
    required List<int> ciOrder,
    required List<int> riOrder,
  });

  /// Save corrected values and serialized model back to Tercen.
  ///
  /// Used in the 2-step workflow when "Save model for reuse" is enabled.
  /// [modelJson] is the serialized ComBat model parameters as JSON string.
  Future<void> saveResultsWithModel({
    required List<List<double>> correctedMatrix,
    required List<int> ciOrder,
    required List<int> riOrder,
    required String modelJson,
  });
}
