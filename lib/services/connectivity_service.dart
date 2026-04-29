import 'dart:io';
import 'dart:async';

class ConnectivityService {
  /// Check if the device has internet connectivity
  /// Tries to connect to Google DNS — fast and reliable
  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Run a Firebase operation with internet check.
  /// If no internet, throws a user-friendly exception.
  /// If the operation fails with a network error, also provides a clear message.
  static Future<T> runWithConnectivity<T>(Future<T> Function() operation) async {
    final connected = await hasInternet();
    if (!connected) {
      throw NoInternetException();
    }

    try {
      return await operation();
    } on SocketException catch (_) {
      throw NoInternetException();
    } on TimeoutException catch (_) {
      throw NoInternetException(
          message: 'Connection timed out. Please check your internet and try again.');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('network') ||
          msg.contains('unavailable') ||
          msg.contains('failed host lookup') ||
          msg.contains('socket') ||
          msg.contains('connection refused') ||
          msg.contains('connection reset')) {
        throw NoInternetException();
      }
      rethrow;
    }
  }
}

/// Custom exception for no internet scenarios
class NoInternetException implements Exception {
  final String message;
  NoInternetException({
    this.message = 'No internet connection. Please check your network and try again.',
  });

  @override
  String toString() => message;
}
