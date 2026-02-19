import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../domain/models/pca_result.dart';
import '../../domain/models/sample_metadata.dart';
import '../../domain/services/data_service.dart';

/// Mock implementation that loads CSV data from assets and computes
/// a simple PCA to demonstrate before/after batch correction.
class MockDataService implements DataService {
  List<List<dynamic>>? _qtRows;
  List<SampleMetadata>? _sampleMeta;
  List<String>? _peptideIds;

  /// Load and cache the raw CSV data.
  Future<void> _ensureLoaded() async {
    if (_qtRows != null) return;

    final qtCsv = await rootBundle.loadString('assets/data/qt.csv');
    final colCsv = await rootBundle.loadString('assets/data/column.csv');
    final rowCsv = await rootBundle.loadString('assets/data/row.csv');

    const converter = CsvToListConverter(eol: '\n');

    final qtParsed = converter.convert(qtCsv);
    _qtRows = qtParsed.skip(1).toList(); // skip header

    final colParsed = converter.convert(colCsv);
    _sampleMeta = colParsed.skip(1).map((row) {
      return SampleMetadata(
        testCondition: row[0].toString().replaceAll('"', ''),
        run: row[1].toString().replaceAll('"', ''),
        barcode: row[2].toString().replaceAll('"', ''),
      );
    }).toList();

    final rowParsed = converter.convert(rowCsv);
    _peptideIds = rowParsed.skip(1).map((row) {
      return row[0].toString().replaceAll('"', '');
    }).toList();
  }

  /// Build the data matrix: rows = peptides, columns = samples.
  /// Returns (matrix, sampleCiOrder, batchPerSample).
  Future<_MatrixData> _buildMatrix() async {
    await _ensureLoaded();

    // Determine dimensions from data
    final ciValues = _qtRows!.map((r) => (r[1] as num).toInt()).toSet().toList()..sort();
    final riValues = _qtRows!.map((r) => (r[6] as num).toInt()).toSet().toList()..sort();
    final numSamples = ciValues.length;
    final numPeptides = riValues.length;

    // Build ci -> column index mapping
    final ciToCol = <int, int>{};
    for (var i = 0; i < ciValues.length; i++) {
      ciToCol[ciValues[i]] = i;
    }

    // Build ri -> row index mapping
    final riToRow = <int, int>{};
    for (var i = 0; i < riValues.length; i++) {
      riToRow[riValues[i]] = i;
    }

    // Initialize matrix with zeros
    final matrix = List.generate(numPeptides, (_) => List.filled(numSamples, 0.0));

    // Build batch mapping per sample (ci)
    final batchPerSample = <int, String>{};

    for (final row in _qtRows!) {
      final ci = (row[1] as num).toInt();
      final y = (row[2] as num).toDouble();
      final ri = (row[6] as num).toInt();
      final batch = row[5].toString().replaceAll('"', '');

      final colIdx = ciToCol[ci]!;
      final rowIdx = riToRow[ri]!;
      matrix[rowIdx][colIdx] = y;
      batchPerSample[ci] = batch;
    }

    return _MatrixData(
      matrix: matrix,
      ciOrder: ciValues,
      batchPerSample: batchPerSample,
      numPeptides: numPeptides,
      numSamples: numSamples,
    );
  }

  /// Compute PCA on a samples-by-peptides data matrix.
  /// Uses power iteration to approximate the first 2 principal components.
  PcaResult _computePca(
    List<List<double>> matrix,
    List<int> ciOrder,
    Map<int, String> batchPerSample,
    int numPeptides,
    int numSamples,
  ) {
    // Transpose: we want samples as rows, peptides as columns for PCA on samples
    // matrix is peptides x samples, we need samples x peptides
    final samplesMatrix = List.generate(
      numSamples,
      (s) => List.generate(numPeptides, (p) => matrix[p][s]),
    );

    // Center each column (peptide) by subtracting mean across samples
    final means = List.filled(numPeptides, 0.0);
    for (var p = 0; p < numPeptides; p++) {
      double sum = 0;
      for (var s = 0; s < numSamples; s++) {
        sum += samplesMatrix[s][p];
      }
      means[p] = sum / numSamples;
    }

    final centered = List.generate(
      numSamples,
      (s) => List.generate(numPeptides, (p) => samplesMatrix[s][p] - means[p]),
    );

    // Compute Gram matrix G = X * X' (samples x samples).
    // Using Gram matrix (not covariance X*X'/(n-1)) so that scores
    // u * sqrt(eigenvalue) give correct PC scores matching R's prcomp().
    final cov = List.generate(numSamples, (_) => List.filled(numSamples, 0.0));
    for (var i = 0; i < numSamples; i++) {
      for (var j = i; j < numSamples; j++) {
        double dot = 0;
        for (var p = 0; p < numPeptides; p++) {
          dot += centered[i][p] * centered[j][p];
        }
        cov[i][j] = dot;
        cov[j][i] = dot;
      }
    }

    // Power iteration for first eigenvector
    final pc1Vec = _powerIteration(cov, numSamples, 100);
    final eigenvalue1 = _rayleighQuotient(cov, pc1Vec, numSamples);

    // Deflate
    final cov2 = List.generate(numSamples, (i) => List.generate(numSamples, (j) {
      return cov[i][j] - eigenvalue1 * pc1Vec[i] * pc1Vec[j];
    }));

    // Power iteration for second eigenvector
    final pc2Vec = _powerIteration(cov2, numSamples, 100);
    final eigenvalue2 = _rayleighQuotient(cov2, pc2Vec, numSamples);

    // Total variance = sum of diagonal of cov
    double totalVar = 0;
    for (var i = 0; i < numSamples; i++) {
      totalVar += cov[i][i];
    }

    final varExplained1 = (eigenvalue1 / totalVar * 100).clamp(0.0, 100.0);
    final varExplained2 = (eigenvalue2 / totalVar * 100).clamp(0.0, 100.0);

    // Project samples onto PC1 and PC2 (the eigenvectors ARE the projections
    // since we used the small covariance trick)
    final points = <PcaPoint>[];
    for (var s = 0; s < numSamples; s++) {
      final ci = ciOrder[s];
      final batch = batchPerSample[ci] ?? 'unknown';
      final sampleIdx = s < (_sampleMeta?.length ?? 0) ? s : 0;
      final meta = _sampleMeta != null && _sampleMeta!.isNotEmpty
          ? _sampleMeta![sampleIdx]
          : null;
      final sampleName = meta?.displayName ?? 'Sample $ci';

      points.add(PcaPoint(
        pc1: pc1Vec[s] * sqrt(eigenvalue1.abs()),
        pc2: pc2Vec[s] * sqrt(eigenvalue2.abs()),
        ci: ci,
        batch: batch,
        sampleName: sampleName,
      ));
    }

    return PcaResult(
      points: points,
      varianceExplainedPc1: varExplained1,
      varianceExplainedPc2: varExplained2,
    );
  }

  /// Power iteration to find dominant eigenvector.
  List<double> _powerIteration(List<List<double>> mat, int n, int maxIter) {
    final rng = Random(42);
    var vec = List.generate(n, (_) => rng.nextDouble() - 0.5);
    vec = _normalize(vec);

    for (var iter = 0; iter < maxIter; iter++) {
      final newVec = List.filled(n, 0.0);
      for (var i = 0; i < n; i++) {
        double sum = 0;
        for (var j = 0; j < n; j++) {
          sum += mat[i][j] * vec[j];
        }
        newVec[i] = sum;
      }
      vec = _normalize(newVec);
    }
    return vec;
  }

  /// Normalize a vector to unit length.
  List<double> _normalize(List<double> vec) {
    double norm = 0;
    for (final v in vec) {
      norm += v * v;
    }
    norm = sqrt(norm);
    if (norm < 1e-10) return vec;
    return vec.map((v) => v / norm).toList();
  }

  /// Rayleigh quotient: eigenvalue estimate = v^T * A * v / (v^T * v).
  double _rayleighQuotient(List<List<double>> mat, List<double> vec, int n) {
    double numerator = 0;
    for (var i = 0; i < n; i++) {
      double row = 0;
      for (var j = 0; j < n; j++) {
        row += mat[i][j] * vec[j];
      }
      numerator += vec[i] * row;
    }
    return numerator;
  }

  /// Simulate batch correction by adjusting batch means to align.
  List<List<double>> _simulateCorrection(
    List<List<double>> matrix,
    List<int> ciOrder,
    Map<int, String> batchPerSample,
    int numPeptides,
    int numSamples,
  ) {
    // Find the distinct batches
    final batches = batchPerSample.values.toSet().toList()..sort();

    // For each peptide, compute per-batch mean, then shift all batches
    // toward the grand mean.
    final corrected = List.generate(
      numPeptides,
      (p) => List<double>.from(matrix[p]),
    );

    for (var p = 0; p < numPeptides; p++) {
      // Grand mean for this peptide across all samples
      double grandSum = 0;
      for (var s = 0; s < numSamples; s++) {
        grandSum += matrix[p][s];
      }
      final grandMean = grandSum / numSamples;

      // Per-batch mean
      for (final batch in batches) {
        final indices = <int>[];
        for (var s = 0; s < numSamples; s++) {
          if (batchPerSample[ciOrder[s]] == batch) {
            indices.add(s);
          }
        }
        if (indices.isEmpty) continue;

        double batchSum = 0;
        for (final s in indices) {
          batchSum += matrix[p][s];
        }
        final batchMean = batchSum / indices.length;
        final shift = grandMean - batchMean;

        // Also slightly reduce batch-specific variance (scale correction)
        double batchVar = 0;
        for (final s in indices) {
          batchVar += (matrix[p][s] - batchMean) * (matrix[p][s] - batchMean);
        }
        batchVar = batchVar / indices.length;
        double grandVar = 0;
        for (var s = 0; s < numSamples; s++) {
          grandVar += (matrix[p][s] - grandMean) * (matrix[p][s] - grandMean);
        }
        grandVar = grandVar / numSamples;

        final scaleFactor = (batchVar > 1e-10 && grandVar > 1e-10)
            ? sqrt(grandVar / batchVar) * 0.7 + 0.3
            : 1.0;

        for (final s in indices) {
          corrected[p][s] = grandMean + (matrix[p][s] - batchMean) * scaleFactor + shift * 0.1;
        }
      }
    }

    return corrected;
  }

  @override
  Future<CorrectionResult> computeCorrection({
    required String modelType,
    required String referenceBatch,
    required String mode,
  }) async {
    await _ensureLoaded();

    // Simulate computation delay
    await Future.delayed(const Duration(milliseconds: 800));

    final matData = await _buildMatrix();

    // Compute PCA on uncorrected data
    final before = _computePca(
      matData.matrix,
      matData.ciOrder,
      matData.batchPerSample,
      matData.numPeptides,
      matData.numSamples,
    );

    // Simulate batch correction
    final correctedMatrix = _simulateCorrection(
      matData.matrix,
      matData.ciOrder,
      matData.batchPerSample,
      matData.numPeptides,
      matData.numSamples,
    );

    // Compute PCA on corrected data
    final after = _computePca(
      correctedMatrix,
      matData.ciOrder,
      matData.batchPerSample,
      matData.numPeptides,
      matData.numSamples,
    );

    final batchLabels = matData.batchPerSample.values.toSet().toList()..sort();

    return CorrectionResult(
      before: before,
      after: after,
      batchLabels: batchLabels,
    );
  }

  @override
  Future<List<String>> loadBatchLabels() async {
    await _ensureLoaded();

    final batches = <String>{};
    for (final row in _qtRows!) {
      batches.add(row[5].toString().replaceAll('"', ''));
    }

    final sorted = batches.toList()..sort();
    return sorted;
  }

  @override
  Future<void> saveResults({
    required List<List<double>> correctedMatrix,
    required List<int> ciOrder,
    required List<int> riOrder,
  }) async {
    // Mock: no-op save
    await Future.delayed(const Duration(milliseconds: 300));
    print('MockDataService: saveResults called (no-op)');
  }

  @override
  Future<void> saveResultsWithModel({
    required List<List<double>> correctedMatrix,
    required List<int> ciOrder,
    required List<int> riOrder,
    required String modelJson,
  }) async {
    // Mock: no-op save
    await Future.delayed(const Duration(milliseconds: 300));
    print('MockDataService: saveResultsWithModel called (no-op)');
  }
}

/// Internal helper to hold matrix data and metadata.
class _MatrixData {
  final List<List<double>> matrix;
  final List<int> ciOrder;
  final Map<int, String> batchPerSample;
  final int numPeptides;
  final int numSamples;

  const _MatrixData({
    required this.matrix,
    required this.ciOrder,
    required this.batchPerSample,
    required this.numPeptides,
    required this.numSamples,
  });
}
