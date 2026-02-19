import 'package:flutter/material.dart';
import '../../di/service_locator.dart';
import '../../domain/models/pca_result.dart';
import '../../domain/services/data_service.dart';

/// State provider for the DASCombat Fit operator.
///
/// Each control from spec Section 4.2 maps to one field with a getter + setter.
/// Setters call notifyListeners() to trigger Consumer rebuilds.
class AppStateProvider extends ChangeNotifier {
  final DataService _dataService;

  AppStateProvider({DataService? dataService})
      : _dataService = dataService ?? serviceLocator<DataService>();

  // --- Data loading state ---
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- MODE section: Segmented button ---
  String _mode = 'Fit Model';
  String get mode => _mode;
  void setMode(String value) {
    _mode = value;
    _recompute();
  }

  // --- SETTINGS section ---

  // Model type dropdown
  String _modelType = 'L/S';
  String get modelType => _modelType;
  void setModelType(String value) {
    _modelType = value;
    _recompute();
  }

  // Reference batch dropdown
  String _referenceBatch = 'None';
  String get referenceBatch => _referenceBatch;
  void setReferenceBatch(String value) {
    _referenceBatch = value;
    _recompute();
  }

  // Save model toggle
  bool _saveModel = false;
  bool get saveModel => _saveModel;
  void setSaveModel(bool value) {
    _saveModel = value;
    notifyListeners();
  }

  // --- ACTIONS section ---

  // Status message display
  String _statusMessage = 'Ready';
  String get statusMessage => _statusMessage;

  // Whether PCA has been computed (enables Done button)
  bool _isComputed = false;
  bool get isComputed => _isComputed;

  // --- Data ---

  // Batch labels for the reference batch dropdown
  List<String> _batchLabels = [];
  List<String> get batchLabels => _batchLabels;

  // PCA results (before and after correction)
  CorrectionResult? _correctionResult;
  CorrectionResult? get correctionResult => _correctionResult;

  // Save state
  bool _isSaving = false;
  bool _hasSaved = false;
  bool get isSaving => _isSaving;
  bool get hasSaved => _hasSaved;

  /// Load batch labels and auto-compute the correction on startup.
  Future<void> loadData() async {
    _isLoading = true;
    _error = null;
    _statusMessage = 'Computing correction...';
    notifyListeners();

    try {
      // Load batch labels for the dropdown
      _batchLabels = await _dataService.loadBatchLabels();

      // Auto-compute the correction
      _correctionResult = await _dataService.computeCorrection(
        modelType: _modelType,
        referenceBatch: _referenceBatch,
        mode: _mode,
      );

      _isComputed = true;
      _statusMessage = 'Review the PCA plot, then click Done to save';
    } catch (e) {
      _error = _formatError(e);
      _statusMessage = _error!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recompute the correction with current settings.
  Future<void> _recompute() async {
    _error = null;
    _hasSaved = false;

    try {
      _correctionResult = await _dataService.computeCorrection(
        modelType: _modelType,
        referenceBatch: _referenceBatch,
        mode: _mode,
      );
      _isComputed = true;
      _statusMessage = 'Review the PCA plot, then click Done to save';
    } catch (e) {
      _error = _formatError(e);
      _statusMessage = _error!;
      _correctionResult = null;
      _isComputed = false;
    } finally {
      notifyListeners();
    }
  }

  /// Done button action: save corrected values back to Tercen.
  Future<void> onDone() async {
    if (_correctionResult == null || _isSaving || _hasSaved) return;

    final result = _correctionResult!;
    if (result.correctedMatrix == null ||
        result.ciOrder == null ||
        result.riOrder == null) {
      // Mock mode: no data to save
      _statusMessage = 'Saved successfully';
      _hasSaved = true;
      notifyListeners();
      return;
    }

    _isSaving = true;
    _statusMessage = 'Saving...';
    notifyListeners();

    try {
      if (_saveModel && _mode == 'Fit Model' && result.modelJson != null) {
        await _dataService.saveResultsWithModel(
          correctedMatrix: result.correctedMatrix!,
          ciOrder: result.ciOrder!,
          riOrder: result.riOrder!,
          modelJson: result.modelJson!,
        );
      } else {
        await _dataService.saveResults(
          correctedMatrix: result.correctedMatrix!,
          ciOrder: result.ciOrder!,
          riOrder: result.riOrder!,
        );
      }
      _hasSaved = true;
      _statusMessage = 'Saved successfully';
    } catch (e) {
      _statusMessage = 'Save failed: $e';
      print('DASCombat: save error: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Format validation errors for user-friendly display.
  /// Strips StateError wrapper text, keeps the message.
  String _formatError(Object e) {
    final msg = e.toString();
    // StateError wraps as "Bad state: <message>"
    if (msg.startsWith('Bad state: ')) {
      return msg.substring(11);
    }
    return msg;
  }
}
