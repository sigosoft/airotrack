import 'dart:async';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class RetryInterceptor extends Interceptor {
  final Dio dio;

  RetryInterceptor({required this.dio});

  Future<bool> _hasInternet() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity.isNotEmpty && connectivity.any((r) => r != ConnectivityResult.none);
  }


  Future<Response?> _retry(RequestOptions requestOptions) async {
    return dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: Options(
        method: requestOptions.method,
        headers: requestOptions.headers,
      ),
    );
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // No internet case
    if (err.type == DioExceptionType.unknown ||
        err.type == DioExceptionType.connectionError) {
      if (!await _hasInternet()) {
        // Wait until internet is restored
        await _waitForInternet();
        final retryResponse = await _retry(err.requestOptions);
        return handler.resolve(retryResponse!);
      }
    }

    return handler.next(err);
  }

  Future<void> _waitForInternet() async {
    final completer = Completer<void>();

    final subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      if (result.isNotEmpty && result.any((r) => r != ConnectivityResult.none)) {
        completer.complete();
      }
    });

    await completer.future;
    await subscription.cancel();
  }

}
