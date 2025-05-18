/// Exception thrown for errors encountered during Genkit flow operations.
class GenkitException implements Exception {
  final String message;
  final int? statusCode; // HTTP status code if applicable
  final String? details; // Further details, potentially response body
  final Object? underlyingException; // For wrapping other exceptions
  final StackTrace? stackTrace; // For capturing the stack trace

  GenkitException(
    this.message, {
    this.statusCode,
    this.details,
    this.underlyingException,
    this.stackTrace,
  });

  @override
  String toString() {
    var str = 'GenkitException: $message';
    if (statusCode != null) {
      str += ' (Status Code: $statusCode)';
    }
    if (details != null && details!.isNotEmpty) {
      str += '\nDetails: $details';
    }
    if (underlyingException != null) {
      str += '\nUnderlying exception: $underlyingException';
    }
    if (stackTrace != null) {
      str += '\nStackTrace:\n$stackTrace';
    }
    return str;
  }
}
