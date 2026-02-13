import 'dart:developer';
import 'package:airotrack/Configs/RetryInterceptor.dart';
import 'package:airotrack/Screens/modules/ServerDown/ServerDown.dart';
import 'package:dio/dio.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';


import 'ApiConfigs.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;
  Dio dio = Dio();

  DioClient._internal() {
    dio
      ..options.baseUrl = ApiConfig.baseUrl
      ..options.connectTimeout = Duration(seconds: 20)
      ..options.receiveTimeout = Duration(seconds: 20)
      ..options.headers = {
        "Accept": "application/json",
        "Content-Type": "application/json"
      };

    dio.interceptors.add(RetryInterceptor(dio: dio));
    dio.interceptors.add(_loggingInterceptor());
  }

  /// Logger Interceptor
  InterceptorsWrapper _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        log("➡️ REQUEST: ${options.method} ${options.uri}");
        log("Headers: ${options.headers}");
        log("Data: ${options.data}");
        return handler.next(options);
      },
      onResponse: (response, handler) {
        log("⬅️ RESPONSE: ${response.statusCode} ${response.data}");
        return handler.next(response);
      },
      onError: (DioException error, handler) {
        log("❌ ERROR: ${error.error}");
        return handler.next(error);
      },
    );
  }

  Future<Response> get(String path, {Map<String, dynamic>? query}) async {
    try {
      return await dio.get(path, queryParameters: query);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic body, Map<String, dynamic>? query}) async {
    try {
      return await dio.post(path, data: body, queryParameters: query);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Add token dynamically
  void updateToken(String token) {
    dio.options.headers["Authorization"] = "Bearer $token";
  }

  // GLOBAL ERROR HANDLING
  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      final statusCode = e.response!.statusCode;

      if (statusCode == 422 && data is Map) {
        final msg = data['message'];

        if (msg is Map) {
          final keys = msg.keys.toList();
          if (keys.isNotEmpty) {
            final firstKey = keys[0];
            final firstList = msg[firstKey];
            if (firstList is List && firstList.isNotEmpty) {
              return firstList.first.toString();
            }
          }
        }

        if (msg is String) {
          return msg;
        }

        return "Validation failed";
      }
      else if(statusCode == 500){
        Get.to(ServerDown());
        return "Server error occurred";
      } else {
        // Log more details about the error
        log("Error Status Code: $statusCode");
        log("Error Data: $data");
        if (data is Map && data['message'] != null) {
          final msg = data['message'];
          if (msg is String) return msg;
          if (msg is Map) {
            // Try to extract message from map
            final keys = msg.keys.toList();
            if (keys.isNotEmpty) {
              final firstKey = keys[0];
              final firstValue = msg[firstKey];
              if (firstValue is List && firstValue.isNotEmpty) {
                return firstValue.first.toString();
              }
              if (firstValue is String) {
                return firstValue;
              }
            }
          }
        }
        return "Something went wrong. Code: $statusCode";
      }
    }

    if (e.type == DioExceptionType.connectionError) {
      return "No Internet Connection";
    }

    if (e.type == DioExceptionType.connectionTimeout) {
      return "Connection Timeout. Try again.";
    }

    if (e.type == DioExceptionType.receiveTimeout) {
      return "Receive Timeout. Try again.";
    }

    if (e.type == DioExceptionType.sendTimeout) {
      return "Send Timeout. Try again.";
    }

    // Log the error type and message for debugging
    log("DioException Type: ${e.type}");
    log("DioException Message: ${e.message}");
    if (e.response != null) {
      log("Response Status: ${e.response!.statusCode}");
      log("Response Data: ${e.response!.data}");
    }

    return "Unexpected error occurred: ${e.message ?? e.type.toString()}";
  }

}
