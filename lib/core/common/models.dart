class CoreModels {}

class AgentException implements Exception {
  final String source;
  final String message;
  AgentException(this.source, this.message);
  @override
  String toString() => 'AgentException($source): $message';
}
