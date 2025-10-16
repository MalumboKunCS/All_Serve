import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// Centralized logging utility for the All-Serve application.
/// 
/// This class provides structured logging with different levels:
/// - info: General informational messages
/// - debug: Debug/development-only messages (only shown in debug mode)
/// - warning: Warning messages
/// - error: Error messages
/// 
/// All debug messages are automatically filtered out in release mode.
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  /// Log informational messages
  static void info(String message) => _logger.i(message);

  /// Log debug messages (only in debug mode)
  static void debug(String message) {
    if (kDebugMode) {
      _logger.d(message);
    }
  }

  /// Log warning messages
  static void warning(String message) => _logger.w(message);

  /// Log error messages
  static void error(String message) => _logger.e(message);

  /// Log error messages with stack trace
  static void errorWithStackTrace(String message, [StackTrace? stackTrace]) {
    _logger.e(message, error: message, stackTrace: stackTrace);
  }

  /// Close the logger (useful for cleanup)
  static void close() => _logger.close();
}
