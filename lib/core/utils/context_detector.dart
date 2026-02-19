/// Detects whether the app is running inside a Tercen Data Step or standalone.
/// When taskId is present in the URL, the app is embedded — hide the top bar.
/// When absent, the app is in full-screen mode — show the top bar.
class AppContextDetector {
  AppContextDetector._();

  static bool get isInDataStep {
    final taskId = Uri.base.queryParameters['taskId'];
    return taskId != null && taskId.isNotEmpty;
  }

  static String? get taskId => Uri.base.queryParameters['taskId'];
  static String? get workflowId => Uri.base.queryParameters['workflowId'];
  static String? get stepId => Uri.base.queryParameters['stepId'];
}
