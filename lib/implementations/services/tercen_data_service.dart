import 'dart:convert';
import 'dart:math';
import 'package:sci_tercen_context/sci_tercen_context.dart';

import '../../domain/models/pca_result.dart';
import '../../domain/services/data_service.dart';

/// Real Tercen data service for the DASCombat operator.
///
/// Reads data via sci_tercen_context (ctx.select, ctx.cselect, ctx.rselect),
/// runs the ComBat batch correction algorithm (ported from R pgcombat.R),
/// computes PCA, and saves corrected results back to Tercen.
class TercenDataService implements DataService {
  final ServiceFactoryBase _factory;
  final String _taskId;

  AbstractOperatorContext? _ctx;

  /// Cached raw data after first load.
  _RawData? _rawData;

  TercenDataService(this._factory, this._taskId);

  Future<AbstractOperatorContext> _getContext() async {
    if (_ctx != null) return _ctx!;
    print('DASCombat: creating OperatorContext for taskId=$_taskId');
    _ctx = await OperatorContext.create(
      serviceFactory: _factory,
      taskId: _taskId,
    );
    print('DASCombat: OperatorContext created, task=${_ctx!.task?.runtimeType}');
    return _ctx!;
  }

  /// Load and cache the raw data from Tercen.
  Future<_RawData> _loadRawData() async {
    if (_rawData != null) return _rawData!;

    final ctx = await _getContext();

    try {
      await ctx.log('Loading data...');

      // 1. Get color factor names (batch variable)
      List<String> colorFactors;
      try {
        colorFactors = await ctx.colors;
      } catch (_) {
        colorFactors = [];
      }

      if (colorFactors.isEmpty) {
        throw StateError(
            'A batch variable is required. Map a color in the crosstab.');
      }

      final batchColumnName = colorFactors.first;
      print('DASCombat: batch column from colors = $batchColumnName');

      // 2. Fetch main data: .y, .ci, .ri, and the batch color column
      final selectNames = ['.y', '.ci', '.ri', batchColumnName];
      print('DASCombat: selecting $selectNames from main table');
      final qtData = await ctx.select(names: selectNames);

      // Parse columns
      List ciRaw = [];
      List riRaw = [];
      List<double> yValues = [];
      List batchRaw = [];

      for (final col in qtData.columns) {
        final values = col.values as List?;
        if (values == null) continue;
        switch (col.name) {
          case '.ci':
            ciRaw = values;
          case '.ri':
            riRaw = values;
          case '.y':
            yValues = values.map((v) => (v as num).toDouble()).toList();
          default:
            // The batch column name may be namespaced
            if (col.name == batchColumnName ||
                col.name.endsWith('.$batchColumnName') ||
                _stripNamespace(col.name) == _stripNamespace(batchColumnName)) {
              batchRaw = values;
            }
        }
      }

      if (yValues.isEmpty) {
        throw StateError('No .y values returned from ctx.select()');
      }
      if (batchRaw.isEmpty) {
        throw StateError(
            'Batch column "$batchColumnName" not found in select result. '
            'Available columns: ${qtData.columns.map((c) => c.name).toList()}');
      }

      print('DASCombat: fetched ${yValues.length} data points');

      // 3. Build unique sorted ci and ri lists
      final uniqueCi = <int>{};
      final uniqueRi = <int>{};
      for (int i = 0; i < ciRaw.length; i++) {
        uniqueCi.add(_toInt(ciRaw[i]));
        uniqueRi.add(_toInt(riRaw[i]));
      }
      final sortedCi = uniqueCi.toList()..sort();
      final sortedRi = uniqueRi.toList()..sort();
      final ciIdx = {for (var i = 0; i < sortedCi.length; i++) sortedCi[i]: i};
      final riIdx = {for (var i = 0; i < sortedRi.length; i++) sortedRi[i]: i};

      final numSamples = sortedCi.length;
      final numPeptides = sortedRi.length;
      print('DASCombat: matrix dimensions ${numPeptides}x$numSamples');
      await ctx.log('Loaded ${numPeptides} peptides x $numSamples samples');

      // 4. Build data matrix (peptides x samples) and batch mapping
      final matrix =
          List.generate(numPeptides, (_) => List.filled(numSamples, double.nan));
      final batchPerSample = <int, String>{};

      for (int i = 0; i < yValues.length; i++) {
        final ci = _toInt(ciRaw[i]);
        final ri = _toInt(riRaw[i]);
        final y = yValues[i];
        final batch = batchRaw[i].toString();

        matrix[riIdx[ri]!][ciIdx[ci]!] = y;
        batchPerSample[ci] = batch;
      }

      // 5. Fetch column metadata for sample names (tooltips)
      Map<int, Map<String, dynamic>> colMetadata = {};
      try {
        final colData = await ctx.cselect();
        colMetadata = _buildIndexMap(colData);
        print('DASCombat: fetched column metadata, ${colMetadata.length} entries');
      } catch (e) {
        print('DASCombat: cselect failed (non-fatal): $e');
      }

      // Build sample names from column metadata
      final sampleNames = <int, String>{};
      for (int i = 0; i < numSamples; i++) {
        final ci = sortedCi[i];
        final meta = colMetadata[i];
        if (meta != null) {
          // Use the first non-dot column value as sample name
          String name = 'Sample $ci';
          for (final entry in meta.entries) {
            if (!entry.key.startsWith('.')) {
              name = entry.value.toString();
              break;
            }
          }
          sampleNames[ci] = name;
        } else {
          sampleNames[ci] = 'Sample $ci';
        }
      }

      // 6. Get label factor names (for Apply Model mode)
      List<String> labelFactors;
      try {
        labelFactors = await ctx.labels;
      } catch (_) {
        labelFactors = [];
      }
      print('DASCombat: label factors = $labelFactors');

      _rawData = _RawData(
        matrix: matrix,
        ciOrder: sortedCi,
        riOrder: sortedRi,
        batchPerSample: batchPerSample,
        sampleNames: sampleNames,
        numPeptides: numPeptides,
        numSamples: numSamples,
        labelFactors: labelFactors,
        batchColumnName: batchColumnName,
      );

      return _rawData!;
    } catch (e) {
      if (e is StateError) rethrow;
      print('DASCombat: data loading failed: $e');
      await _printDiagnosticReport();
      rethrow;
    }
  }

  @override
  Future<List<String>> loadBatchLabels() async {
    final raw = await _loadRawData();
    final batches = raw.batchPerSample.values.toSet().toList()..sort();
    return batches;
  }

  @override
  Future<CorrectionResult> computeCorrection({
    required String modelType,
    required String referenceBatch,
    required String mode,
  }) async {
    final raw = await _loadRawData();
    final ctx = await _getContext();

    try {
      await ctx.log('Computing correction (mode=$mode, modelType=$modelType)...');
      await ctx.progress('Computing correction', actual: 0, total: 100);

      // Validation: check for missing values (FR-17)
      for (int p = 0; p < raw.numPeptides; p++) {
        for (int s = 0; s < raw.numSamples; s++) {
          if (raw.matrix[p][s].isNaN || raw.matrix[p][s].isInfinite) {
            throw StateError('Missing values are not allowed.');
          }
        }
      }

      // Validation: check for zero standard deviation rows (FR-19)
      final zeroSdRows = <int>[];
      for (int p = 0; p < raw.numPeptides; p++) {
        final row = raw.matrix[p];
        double mean = 0;
        for (final v in row) {
          mean += v;
        }
        mean /= row.length;
        double variance = 0;
        for (final v in row) {
          variance += (v - mean) * (v - mean);
        }
        variance /= (row.length - 1);
        if (variance < 1e-20) {
          zeroSdRows.add(raw.riOrder[p]);
        }
      }
      if (zeroSdRows.isNotEmpty) {
        throw StateError(
            'Variables with 0 standard deviation found (rows: ${zeroSdRows.join(", ")}). '
            'Remove them before running ComBat.');
      }

      // Build batch vector (one per sample, in column order)
      final batchVector = <String>[];
      for (final ci in raw.ciOrder) {
        batchVector.add(raw.batchPerSample[ci] ?? 'unknown');
      }

      await ctx.progress('Running ComBat', actual: 20, total: 100);

      List<List<double>> correctedMatrix;
      String? serializedModel;

      if (mode == 'Apply Model') {
        // Apply Model mode (FR-03)
        if (raw.labelFactors.isEmpty) {
          throw StateError(
              'No saved model found. Add a model output to the labels zone in the crosstab.');
        }

        // Read the model from labels
        final labelName = raw.labelFactors.first;
        print('DASCombat: reading model from label "$labelName"');

        try {
          final labelData = await ctx.select(names: [labelName]);
          String? modelStr;
          for (final col in labelData.columns) {
            final values = col.values as List?;
            if (values != null && values.isNotEmpty) {
              modelStr = values.first.toString();
              break;
            }
          }
          if (modelStr == null || modelStr.isEmpty) {
            throw StateError(
                'No saved model found. Add a model output to the labels zone in the crosstab.');
          }

          final model = _CombatModel.fromJson(jsonDecode(modelStr));
          correctedMatrix = model.apply(raw.matrix, batchVector);
        } catch (e) {
          if (e is StateError) rethrow;
          throw StateError(
              'No saved model found. Add a model output to the labels zone in the crosstab.');
        }
      } else {
        // Fit Model mode (FR-02)
        final meanOnly = modelType == 'L';
        final refBatch =
            (referenceBatch == 'None' || referenceBatch.isEmpty)
                ? null
                : referenceBatch;

        // Validation: single-sample batch with L/S model (FR-18)
        if (!meanOnly) {
          final batchCounts = <String, int>{};
          for (final b in batchVector) {
            batchCounts[b] = (batchCounts[b] ?? 0) + 1;
          }
          for (final entry in batchCounts.entries) {
            if (entry.value == 1) {
              throw StateError(
                  'At least one batch has only 1 observation. '
                  'Consider using the L (location only) model.');
            }
          }
        }

        final combat = _CombatModel();
        correctedMatrix =
            combat.fit(raw.matrix, batchVector, meanOnly: meanOnly, refBatch: refBatch);
        serializedModel = jsonEncode(combat.toJson());
      }

      await ctx.progress('Computing PCA', actual: 60, total: 100);

      // Compute PCA on uncorrected data
      final before = _computePca(
        raw.matrix,
        raw.ciOrder,
        raw.batchPerSample,
        raw.sampleNames,
        raw.numPeptides,
        raw.numSamples,
      );

      // Compute PCA on corrected data
      final after = _computePca(
        correctedMatrix,
        raw.ciOrder,
        raw.batchPerSample,
        raw.sampleNames,
        raw.numPeptides,
        raw.numSamples,
      );

      await ctx.progress('Done', actual: 100, total: 100);
      await ctx.log('Correction computed successfully');

      final batchLabels = raw.batchPerSample.values.toSet().toList()..sort();

      return CorrectionResult(
        before: before,
        after: after,
        batchLabels: batchLabels,
        correctedMatrix: correctedMatrix,
        ciOrder: raw.ciOrder,
        riOrder: raw.riOrder,
        modelJson: serializedModel,
      );
    } catch (e) {
      if (e is StateError) rethrow;
      print('DASCombat: computeCorrection failed: $e');
      await _printDiagnosticReport();
      rethrow;
    }
  }

  @override
  Future<void> saveResults({
    required List<List<double>> correctedMatrix,
    required List<int> ciOrder,
    required List<int> riOrder,
  }) async {
    final ctx = await _getContext();

    print('DASCombat: saving corrected values...');
    await ctx.log('Saving corrected values...');
    await ctx.progress('Saving', actual: 0, total: 100);

    // Build flat table: .ri, .ci, CmbCor
    final nPeptides = riOrder.length;
    final nSamples = ciOrder.length;
    final nRows = nPeptides * nSamples;

    final outRi = <int>[];
    final outCi = <int>[];
    final outValues = <double>[];

    for (int p = 0; p < nPeptides; p++) {
      for (int s = 0; s < nSamples; s++) {
        outRi.add(riOrder[p]);
        outCi.add(ciOrder[s]);
        outValues.add(correctedMatrix[p][s]);
      }
    }

    // Namespace the value column
    final nsMap = await ctx.addNamespace(['CmbCor']);
    final valueName = nsMap['CmbCor'] ?? 'CmbCor';

    final table = Table();
    table.nRows = nRows;
    table.columns.add(AbstractOperatorContext.makeInt32Column('.ri', outRi));
    table.columns.add(AbstractOperatorContext.makeInt32Column('.ci', outCi));
    table.columns
        .add(AbstractOperatorContext.makeFloat64Column(valueName, outValues));

    print('DASCombat: saving table with $nRows rows, '
        '${table.columns.length} columns');
    for (final col in table.columns) {
      print('  col: ${col.name} type=${col.type} nRows=${col.nRows}');
    }

    await ctx.saveTable(table);
    await ctx.progress('Saved', actual: 100, total: 100);
    await ctx.log('Save completed');
    print('DASCombat: save completed');
  }

  @override
  Future<void> saveResultsWithModel({
    required List<List<double>> correctedMatrix,
    required List<int> ciOrder,
    required List<int> riOrder,
    required String modelJson,
  }) async {
    final ctx = await _getContext();

    print('DASCombat: saving corrected values + model...');
    await ctx.log('Saving corrected values and model...');
    await ctx.progress('Saving', actual: 0, total: 100);

    // Table 1: corrected values (.ri, .ci, CmbCor)
    final nPeptides = riOrder.length;
    final nSamples = ciOrder.length;
    final nRows = nPeptides * nSamples;

    final outRi = <int>[];
    final outCi = <int>[];
    final outValues = <double>[];

    for (int p = 0; p < nPeptides; p++) {
      for (int s = 0; s < nSamples; s++) {
        outRi.add(riOrder[p]);
        outCi.add(ciOrder[s]);
        outValues.add(correctedMatrix[p][s]);
      }
    }

    final nsMap =
        await ctx.addNamespace(['CmbCor', 'model', '.base64.serialized.r.model']);
    final valueName = nsMap['CmbCor'] ?? 'CmbCor';

    final dataTable = Table();
    dataTable.nRows = nRows;
    dataTable.columns
        .add(AbstractOperatorContext.makeInt32Column('.ri', outRi));
    dataTable.columns
        .add(AbstractOperatorContext.makeInt32Column('.ci', outCi));
    dataTable.columns
        .add(AbstractOperatorContext.makeFloat64Column(valueName, outValues));

    // Table 2: model (single row with serialized model)
    final modelColName =
        nsMap['.base64.serialized.r.model'] ?? '.base64.serialized.r.model';
    final modelLabelName = nsMap['model'] ?? 'model';

    final modelTable = Table();
    modelTable.nRows = 1;
    modelTable.columns.add(
        AbstractOperatorContext.makeStringColumn(modelLabelName, ['dascombat_model']));
    modelTable.columns
        .add(AbstractOperatorContext.makeStringColumn(modelColName, [modelJson]));

    // Both data and model must be JoinOperators (server ignores result.tables
    // when result.joinOperators is present). Matches R's save_relation() pattern.

    // Data JoinOperator: .ci/.ri join pair columns
    final dataRel = InMemoryRelation();
    dataRel.inMemoryTable = dataTable;
    final dataJop = JoinOperator();
    final dataPair = ColumnPair();
    dataPair.lColumns.addAll(['.ci', '.ri']);
    dataPair.rColumns.addAll(['.ci', '.ri']);
    dataJop.leftPair = dataPair;
    dataJop.rightRelation = dataRel;

    // Model JoinOperator: empty join keys (as_join_operator(list(), list()))
    final modelRel = InMemoryRelation();
    modelRel.inMemoryTable = modelTable;
    final modelJop = JoinOperator();
    modelJop.rightRelation = modelRel;

    print('DASCombat: saving 2 JoinOperators (data + model) via saveRelation');
    await ctx.saveRelation([dataJop, modelJop]);
    await ctx.progress('Saved', actual: 100, total: 100);
    await ctx.log('Save with model completed');
    print('DASCombat: save with model completed');
  }

  // ============================================================
  // Diagnostic report (called on data access failure)
  // ============================================================

  Future<void> _printDiagnosticReport() async {
    try {
      final ctx = _ctx;
      if (ctx == null) {
        print('=== TERCEN DIAGNOSTIC REPORT ===');
        print('Context not yet created');
        print('=== END REPORT ===');
        return;
      }

      print('=== TERCEN DIAGNOSTIC REPORT ===');
      print('Task: ${ctx.taskId} (${ctx.task?.runtimeType})');

      for (final entry in {
        'schema (qtHash)': ctx.schema,
        'cschema (columnHash)': ctx.cschema,
        'rschema (rowHash)': ctx.rschema,
      }.entries) {
        print('\n--- ${entry.key} ---');
        try {
          final s = await entry.value;
          print('Rows: ${s.nRows}, Columns: ${s.columns.map((c) => "${c.name}:${c.type}").join(', ')}');
        } catch (e) {
          print('ERROR: $e');
        }
      }

      try {
        final ns = await ctx.namespace;
        print('\nNamespace: $ns');
      } catch (e) {
        print('\nNamespace ERROR: $e');
      }

      print('=== END REPORT ===');
    } catch (e) {
      print('Diagnostic report failed: $e');
    }
  }

  // ============================================================
  // PCA computation (reused from mock, adapted for real data)
  // ============================================================

  PcaResult _computePca(
    List<List<double>> matrix,
    List<int> ciOrder,
    Map<int, String> batchPerSample,
    Map<int, String> sampleNames,
    int numPeptides,
    int numSamples,
  ) {
    // Transpose: samples as rows, peptides as columns
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
    final cov2 = List.generate(
        numSamples,
        (i) => List.generate(
            numSamples, (j) => cov[i][j] - eigenvalue1 * pc1Vec[i] * pc1Vec[j]));

    // Power iteration for second eigenvector
    final pc2Vec = _powerIteration(cov2, numSamples, 100);
    final eigenvalue2 = _rayleighQuotient(cov2, pc2Vec, numSamples);

    // Total variance
    double totalVar = 0;
    for (var i = 0; i < numSamples; i++) {
      totalVar += cov[i][i];
    }

    final varExplained1 = (eigenvalue1 / totalVar * 100).clamp(0.0, 100.0);
    final varExplained2 = (eigenvalue2 / totalVar * 100).clamp(0.0, 100.0);

    // Build PCA points
    final points = <PcaPoint>[];
    for (var s = 0; s < numSamples; s++) {
      final ci = ciOrder[s];
      final batch = batchPerSample[ci] ?? 'unknown';
      final sampleName = sampleNames[ci] ?? 'Sample $ci';

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

  List<double> _normalize(List<double> vec) {
    double norm = 0;
    for (final v in vec) {
      norm += v * v;
    }
    norm = sqrt(norm);
    if (norm < 1e-10) return vec;
    return vec.map((v) => v / norm).toList();
  }

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

  // ============================================================
  // Helpers
  // ============================================================

  Map<int, Map<String, dynamic>> _buildIndexMap(Table table) {
    final result = <int, Map<String, dynamic>>{};
    for (final col in table.columns) {
      final values = col.values as List?;
      if (values == null) continue;
      for (int i = 0; i < values.length; i++) {
        result.putIfAbsent(i, () => {});
        result[i]![col.name] = values[i];
      }
    }
    return result;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.parse(v.toString());
  }

  static String _stripNamespace(String name) {
    return name.contains('.') ? name.split('.').last : name;
  }
}

// ============================================================
// Raw data container
// ============================================================

class _RawData {
  final List<List<double>> matrix; // peptides x samples
  final List<int> ciOrder;
  final List<int> riOrder;
  final Map<int, String> batchPerSample;
  final Map<int, String> sampleNames;
  final int numPeptides;
  final int numSamples;
  final List<String> labelFactors;
  final String batchColumnName;

  _RawData({
    required this.matrix,
    required this.ciOrder,
    required this.riOrder,
    required this.batchPerSample,
    required this.sampleNames,
    required this.numPeptides,
    required this.numSamples,
    required this.labelFactors,
    required this.batchColumnName,
  });
}

// ============================================================
// ComBat model — ported from R pgcombat.R
// ============================================================

/// Port of the R pgCombat R6 class from pgcombat.R.
///
/// The ComBat algorithm uses empirical Bayes to estimate and remove
/// batch-specific location (gamma) and scale (delta) effects.
class _CombatModel {
  /// Location parameter: grand mean + covariate effects per gene.
  List<double>? L;

  /// Scale parameter: pooled variance per gene.
  List<double>? S;

  /// Empirical Bayes adjusted location parameters (nBatch x nGenes).
  List<List<double>>? gammaStar;

  /// Empirical Bayes adjusted scale parameters (nBatch x nGenes).
  List<List<double>>? deltaStar;

  /// The batch levels in sorted order.
  List<String>? batchLevels;

  _CombatModel();

  /// Fit the ComBat model to data.
  ///
  /// [dat] is a genes x samples matrix (peptides x samples).
  /// [batch] is a batch label per sample (length = nSamples).
  /// [meanOnly] if true, only correct location (L model).
  /// [refBatch] if non-null, designate this batch as reference.
  ///
  /// Returns the corrected matrix (genes x samples).
  List<List<double>> fit(
    List<List<double>> dat,
    List<String> batch, {
    bool meanOnly = false,
    String? refBatch,
  }) {
    final nGenes = dat.length;
    final nArray = dat[0].length;

    // Determine batch levels and indices
    final levels = batch.toSet().toList()..sort();
    final nBatch = levels.length;

    if (refBatch != null && !levels.contains(refBatch)) {
      throw StateError(
          'Reference batch "$refBatch" is not one of the batch levels: $levels');
    }

    final int? refIdx = refBatch != null ? levels.indexOf(refBatch) : null;

    // batches[i] = list of sample indices in batch i
    final batches = List.generate(nBatch, (i) {
      final level = levels[i];
      final indices = <int>[];
      for (int j = 0; j < nArray; j++) {
        if (batch[j] == level) indices.add(j);
      }
      return indices;
    });

    final nBatches = batches.map((b) => b.length).toList();

    // Validation: single-sample batch with L/S model
    if (!meanOnly) {
      for (int i = 0; i < nBatch; i++) {
        if (nBatches[i] == 1) {
          throw StateError(
              'At least one batch has only 1 observation. '
              'Consider using the L (location only) model.');
        }
      }
    }

    // Build batch model matrix (nArray x nBatch)
    // batchmod[j][i] = 1 if sample j belongs to batch i
    final batchmod =
        List.generate(nArray, (_) => List.filled(nBatch, 0.0));
    for (int i = 0; i < nBatch; i++) {
      for (final j in batches[i]) {
        batchmod[j][i] = 1.0;
      }
    }
    if (refIdx != null) {
      // Reference batch: set its column to all 1s
      for (int j = 0; j < nArray; j++) {
        batchmod[j][refIdx] = 1.0;
      }
    }

    // design = batchmod (no additional covariates in this implementation)
    // Check for columns that are all 1s (intercept-like) and remove them,
    // but skip the ref column.
    final keepCols = <int>[];
    for (int c = 0; c < nBatch; c++) {
      if (c == refIdx) {
        keepCols.add(c);
        continue;
      }
      bool allOnes = true;
      for (int j = 0; j < nArray; j++) {
        if (batchmod[j][c] != 1.0) {
          allOnes = false;
          break;
        }
      }
      if (!allOnes) {
        keepCols.add(c);
      }
    }

    final nDesignCols = keepCols.length;
    // design: nArray x nDesignCols
    final design = List.generate(
      nArray,
      (j) => List.generate(nDesignCols, (c) => batchmod[j][keepCols[c]]),
    );

    // B.hat = solve(t(design) %*% design, t(design) %*% t(dat))
    // B.hat: nDesignCols x nGenes
    final dtd = _matMul(_transpose(design), design); // nDesignCols x nDesignCols
    final dtdInv = _invertMatrix(dtd);
    final dtDat = _matMulTransposedDat(_transpose(design), dat); // nDesignCols x nGenes
    final bHat = _matMul(dtdInv, dtDat); // nDesignCols x nGenes

    // Map keepCols indices back to batch indices for grand.mean calculation
    final batchIdxInDesign = <int, int>{};
    for (int c = 0; c < keepCols.length; c++) {
      if (keepCols[c] < nBatch) {
        batchIdxInDesign[keepCols[c]] = c;
      }
    }

    // grand.mean: vector of length nGenes
    final grandMean = List.filled(nGenes, 0.0);
    if (refIdx != null) {
      // grand.mean = B.hat[ref,]
      final refDesignIdx = batchIdxInDesign[refIdx]!;
      for (int g = 0; g < nGenes; g++) {
        grandMean[g] = bHat[refDesignIdx][g];
      }
    } else {
      // grand.mean = crossprod(n.batches / n.array, B.hat[1:n.batch,])
      for (int g = 0; g < nGenes; g++) {
        double sum = 0;
        for (int i = 0; i < nBatch; i++) {
          final designIdx = batchIdxInDesign[i];
          if (designIdx != null) {
            sum += (nBatches[i] / nArray) * bHat[designIdx][g];
          }
        }
        grandMean[g] = sum;
      }
    }

    // var.pooled: vector of length nGenes
    // residuals = dat - t(design %*% B.hat)
    // design %*% B.hat: nArray x nGenes
    final fitted = _matMul(design, bHat); // nArray x nGenes

    final varPooled = List.filled(nGenes, 0.0);
    if (refIdx != null) {
      // Use only the reference batch samples
      final refSamples = batches[refIdx];
      final nRef = refSamples.length;
      for (int g = 0; g < nGenes; g++) {
        double sum = 0;
        for (final j in refSamples) {
          final resid = dat[g][j] - fitted[j][g];
          sum += resid * resid;
        }
        varPooled[g] = sum / nRef;
      }
    } else {
      for (int g = 0; g < nGenes; g++) {
        double sum = 0;
        for (int j = 0; j < nArray; j++) {
          final resid = dat[g][j] - fitted[j][g];
          sum += resid * resid;
        }
        varPooled[g] = sum / nArray;
      }
    }

    // stand.mean = grandMean %*% t(rep(1, nArray))
    // Plus covariate adjustment: tmp %*% B.hat where batch columns are zeroed
    // (No covariates, so stand.mean is just grandMean broadcast)
    // stand.mean: nGenes x nArray
    final standMean = List.generate(
      nGenes,
      (g) => List.filled(nArray, grandMean[g]),
    );

    // s.data = (dat - stand.mean) / sqrt(var.pooled)
    // s.data: nGenes x nArray
    final sData = List.generate(nGenes, (g) {
      final sqrtVar = sqrt(varPooled[g]);
      if (sqrtVar < 1e-20) {
        return List.filled(nArray, 0.0);
      }
      return List.generate(nArray, (j) => (dat[g][j] - standMean[g][j]) / sqrtVar);
    });

    // batch.design = design[, 1:nBatch] (using only batch columns from design)
    // batchDesign: nArray x nBatch
    final batchDesignCols = <int>[];
    for (int i = 0; i < nBatch; i++) {
      final idx = batchIdxInDesign[i];
      if (idx != null) batchDesignCols.add(idx);
    }
    final batchDesign = List.generate(
      nArray,
      (j) => List.generate(batchDesignCols.length, (c) => design[j][batchDesignCols[c]]),
    );

    // gamma.hat = solve(t(batchDesign) %*% batchDesign, t(batchDesign) %*% t(sData))
    // gamma.hat: nBatch x nGenes
    final btb = _matMul(_transpose(batchDesign), batchDesign);
    final btbInv = _invertMatrix(btb);
    final btSdata = _matMulTransposedDat(_transpose(batchDesign), sData);
    final gammaHat = _matMul(btbInv, btSdata); // nBatch x nGenes

    // delta.hat: nBatch x nGenes (row variance of sData within each batch)
    final deltaHat = List.generate(nBatch, (i) {
      final batchSamples = batches[i];
      final n = batchSamples.length;
      return List.generate(nGenes, (g) {
        if (n <= 1) return 1.0;
        double mean = 0;
        for (final j in batchSamples) {
          mean += sData[g][j];
        }
        mean /= n;
        double sum = 0;
        for (final j in batchSamples) {
          final d = sData[g][j] - mean;
          sum += d * d;
        }
        return sum / (n - 1);
      });
    });

    // Empirical Bayes priors
    // gamma.bar = rowMeans(gamma.hat) — mean across genes for each batch
    final gammaBar = List.generate(nBatch, (i) {
      double sum = 0;
      for (int g = 0; g < nGenes; g++) {
        sum += gammaHat[i][g];
      }
      return sum / nGenes;
    });

    // t2 = rowVars(gamma.hat) — variance across genes for each batch
    final t2 = List.generate(nBatch, (i) {
      double mean = gammaBar[i];
      double sum = 0;
      for (int g = 0; g < nGenes; g++) {
        final d = gammaHat[i][g] - mean;
        sum += d * d;
      }
      return sum / (nGenes - 1);
    });

    // a.prior and b.prior for inverse gamma
    final aPrior = List.generate(nBatch, (i) {
      final m = _mean(deltaHat[i]);
      final s2 = _variance(deltaHat[i]);
      return (2 * s2 + m * m) / s2;
    });

    final bPrior = List.generate(nBatch, (i) {
      final m = _mean(deltaHat[i]);
      final s2 = _variance(deltaHat[i]);
      return (m * s2 + m * m * m) / s2;
    });

    // Compute gamma.star and delta.star via iterative solver
    final gammaStarResult =
        List.generate(nBatch, (_) => List.filled(nGenes, 0.0));
    final deltaStarResult =
        List.generate(nBatch, (_) => List.filled(nGenes, 0.0));

    for (int i = 0; i < nBatch; i++) {
      if (meanOnly) {
        // L model: only adjust location
        for (int g = 0; g < nGenes; g++) {
          gammaStarResult[i][g] = _postmean(
              gammaHat[i][g], gammaBar[i], 1.0, 1.0, t2[i]);
          deltaStarResult[i][g] = 1.0;
        }
      } else {
        // L/S model: iterative solver
        final result = _itSol(
          sData,
          batches[i],
          gammaHat[i],
          deltaHat[i],
          gammaBar[i],
          t2[i],
          aPrior[i],
          bPrior[i],
          nGenes,
        );
        gammaStarResult[i] = result[0];
        deltaStarResult[i] = result[1];
      }
    }

    // If reference batch, set its adjustments to neutral
    if (refIdx != null) {
      for (int g = 0; g < nGenes; g++) {
        gammaStarResult[refIdx][g] = 0.0;
        deltaStarResult[refIdx][g] = 1.0;
      }
    }

    // Adjust the data
    // bayesdata = sData
    final bayesdata = List.generate(
        nGenes, (g) => List<double>.from(sData[g]));

    for (int i = 0; i < nBatch; i++) {
      for (final j in batches[i]) {
        for (int g = 0; g < nGenes; g++) {
          // (sData - gamma.star) / sqrt(delta.star)
          // Matches canonical dascombat R package batchcorrect().
          bayesdata[g][j] =
              (bayesdata[g][j] - gammaStarResult[i][g]) /
              sqrt(deltaStarResult[i][g]);
        }
      }
    }

    // Transform back: bayesdata * sqrt(var.pooled) + stand.mean
    final corrected = List.generate(nGenes, (g) {
      final sqrtVar = sqrt(varPooled[g]);
      return List.generate(
          nArray, (j) => bayesdata[g][j] * sqrtVar + standMean[g][j]);
    });

    // If reference batch, restore original values for ref samples
    if (refIdx != null) {
      for (final j in batches[refIdx]) {
        for (int g = 0; g < nGenes; g++) {
          corrected[g][j] = dat[g][j];
        }
      }
    }

    // Store model parameters
    L = List.generate(nGenes, (g) => standMean[g][0]);
    S = varPooled;
    gammaStar = gammaStarResult;
    deltaStar = deltaStarResult;
    batchLevels = levels;

    return corrected;
  }

  /// Apply a previously fitted ComBat model to new data.
  ///
  /// [dat] is genes x samples, [batch] is batch label per sample.
  List<List<double>> apply(List<List<double>> dat, List<String> batch) {
    if (batchLevels == null || L == null || S == null ||
        gammaStar == null || deltaStar == null) {
      throw StateError('Empty combat model, use fit before apply');
    }

    final nGenes = dat.length;
    final nSamples = dat[0].length;

    if (batch.length != nSamples) {
      throw StateError('Data matrix and batch variable don\'t match.');
    }

    final corrected =
        List.generate(nGenes, (_) => List.filled(nSamples, 0.0));

    for (int j = 0; j < nSamples; j++) {
      final bIdx = batchLevels!.indexOf(batch[j]);
      if (bIdx < 0) {
        throw StateError(
            'Batch "${batch[j]}" not found in model batch levels: $batchLevels');
      }

      for (int g = 0; g < nGenes; g++) {
        final sqrtS = sqrt(S![g]);
        if (sqrtS < 1e-20) {
          corrected[g][j] = dat[g][j];
          continue;
        }
        double val = (dat[g][j] - L![g]) / sqrtS;
        val = (val - gammaStar![bIdx][g]) / sqrt(deltaStar![bIdx][g]);
        val = val * sqrtS + L![g];
        corrected[g][j] = val;
      }
    }

    return corrected;
  }

  /// Serialize model to JSON for storage.
  Map<String, dynamic> toJson() {
    return {
      'L': L,
      'S': S,
      'gammaStar': gammaStar,
      'deltaStar': deltaStar,
      'batchLevels': batchLevels,
    };
  }

  /// Deserialize model from JSON.
  factory _CombatModel.fromJson(Map<String, dynamic> json) {
    final model = _CombatModel();
    model.L = (json['L'] as List).map((v) => (v as num).toDouble()).toList();
    model.S = (json['S'] as List).map((v) => (v as num).toDouble()).toList();
    model.gammaStar = (json['gammaStar'] as List)
        .map((row) =>
            (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    model.deltaStar = (json['deltaStar'] as List)
        .map((row) =>
            (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    model.batchLevels = (json['batchLevels'] as List).cast<String>();
    return model;
  }

  // ============================================================
  // ComBat helper functions (ported from R)
  // ============================================================

  /// Posterior mean for location parameter.
  /// R: postmean = function(g.hat, g.bar, n, d.star, t2)
  static double _postmean(
      double gHat, double gBar, double n, double dStar, double t2) {
    return (t2 * n * gHat + dStar * gBar) / (t2 * n + dStar);
  }

  /// Posterior variance for scale parameter.
  /// R: postvar = function(sum2, n, a, b)
  static double _postvar(double sum2, double n, double a, double b) {
    return (0.5 * sum2 + b) / (n / 2 + a - 1);
  }

  /// Iterative solver for empirical Bayes estimation.
  /// R: it.sol = function(sdat, g.hat, d.hat, g.bar, t2, a, b, conv=.0001)
  ///
  /// Returns [gamma.star, delta.star] each of length nGenes.
  static List<List<double>> _itSol(
    List<List<double>> sData,
    List<int> batchIndices,
    List<double> gHat,
    List<double> dHat,
    double gBar,
    double t2,
    double a,
    double b,
    int nGenes,
  ) {
    final n = batchIndices.length.toDouble();
    var gOld = List<double>.from(gHat);
    var dOld = List<double>.from(dHat);

    double change = 1;
    int count = 0;
    const conv = 0.0001;

    while (change > conv) {
      // g.new = postmean(g.hat, g.bar, n, d.old, t2)
      final gNew = List.generate(
          nGenes, (g) => _postmean(gHat[g], gBar, n, dOld[g], t2));

      // sum2 = rowSums((sdat - g.new %*% t(rep(1, ncol(sdat))))^2)
      final sum2 = List.filled(nGenes, 0.0);
      for (int g = 0; g < nGenes; g++) {
        double s = 0;
        for (final j in batchIndices) {
          final d = sData[g][j] - gNew[g];
          s += d * d;
        }
        sum2[g] = s;
      }

      // d.new = postvar(sum2, n, a, b)
      final dNew =
          List.generate(nGenes, (g) => _postvar(sum2[g], n, a, b));

      // change = max(abs(g.new - g.old)/g.old, abs(d.new - d.old)/d.old)
      change = 0;
      for (int g = 0; g < nGenes; g++) {
        if (gOld[g].abs() > 1e-20) {
          final gc = (gNew[g] - gOld[g]).abs() / gOld[g].abs();
          if (gc > change) change = gc;
        }
        if (dOld[g].abs() > 1e-20) {
          final dc = (dNew[g] - dOld[g]).abs() / dOld[g].abs();
          if (dc > change) change = dc;
        }
      }

      gOld = gNew;
      dOld = dNew;
      count++;

      // Safety: prevent infinite loops
      if (count > 5000) break;
    }

    return [gOld, dOld];
  }

  // ============================================================
  // Matrix algebra helpers
  // ============================================================

  /// Transpose a matrix.
  static List<List<double>> _transpose(List<List<double>> m) {
    if (m.isEmpty) return [];
    final rows = m.length;
    final cols = m[0].length;
    return List.generate(cols, (j) => List.generate(rows, (i) => m[i][j]));
  }

  /// Matrix multiply: A (r1 x c1) * B (c1 x c2) = result (r1 x c2).
  static List<List<double>> _matMul(
      List<List<double>> a, List<List<double>> b) {
    final r1 = a.length;
    final c1 = a[0].length;
    final c2 = b[0].length;
    final result = List.generate(r1, (_) => List.filled(c2, 0.0));
    for (int i = 0; i < r1; i++) {
      for (int j = 0; j < c2; j++) {
        double sum = 0;
        for (int k = 0; k < c1; k++) {
          sum += a[i][k] * b[k][j];
        }
        result[i][j] = sum;
      }
    }
    return result;
  }

  /// Multiply A (r1 x c1) with transposed dat (c1 x nGenes, but dat is nGenes x nSamples).
  /// This computes A %*% t(dat) where dat is nGenes x nSamples and A is r1 x nSamples.
  /// Result is r1 x nGenes.
  static List<List<double>> _matMulTransposedDat(
      List<List<double>> a, List<List<double>> dat) {
    final r1 = a.length;
    final nSamples = a[0].length;
    final nGenes = dat.length;
    final result = List.generate(r1, (_) => List.filled(nGenes, 0.0));
    for (int i = 0; i < r1; i++) {
      for (int g = 0; g < nGenes; g++) {
        double sum = 0;
        for (int j = 0; j < nSamples; j++) {
          sum += a[i][j] * dat[g][j];
        }
        result[i][g] = sum;
      }
    }
    return result;
  }

  /// Invert a square matrix using Gauss-Jordan elimination.
  static List<List<double>> _invertMatrix(List<List<double>> m) {
    final n = m.length;
    // Augment with identity
    final aug = List.generate(
        n, (i) => [...m[i], ...List.generate(n, (j) => i == j ? 1.0 : 0.0)]);

    for (int i = 0; i < n; i++) {
      // Partial pivoting
      int maxRow = i;
      double maxVal = aug[i][i].abs();
      for (int k = i + 1; k < n; k++) {
        if (aug[k][i].abs() > maxVal) {
          maxVal = aug[k][i].abs();
          maxRow = k;
        }
      }
      if (maxRow != i) {
        final temp = aug[i];
        aug[i] = aug[maxRow];
        aug[maxRow] = temp;
      }

      final pivot = aug[i][i];
      if (pivot.abs() < 1e-20) {
        throw StateError('Matrix is singular, cannot invert');
      }

      // Scale pivot row
      for (int j = 0; j < 2 * n; j++) {
        aug[i][j] /= pivot;
      }

      // Eliminate other rows
      for (int k = 0; k < n; k++) {
        if (k == i) continue;
        final factor = aug[k][i];
        for (int j = 0; j < 2 * n; j++) {
          aug[k][j] -= factor * aug[i][j];
        }
      }
    }

    // Extract inverse from augmented matrix
    return List.generate(
        n, (i) => List.generate(n, (j) => aug[i][n + j]));
  }

  /// Compute mean of a list of doubles.
  static double _mean(List<double> values) {
    double sum = 0;
    for (final v in values) {
      sum += v;
    }
    return sum / values.length;
  }

  /// Compute sample variance (n-1 denominator) of a list of doubles.
  static double _variance(List<double> values) {
    final m = _mean(values);
    double sum = 0;
    for (final v in values) {
      final d = v - m;
      sum += d * d;
    }
    return sum / (values.length - 1);
  }
}
