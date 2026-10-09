import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.storage);
  final FlutterSecureStorage storage;
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.read(key: 'campus_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class ApiClient {
  ApiClient(String confirmedHttpsBaseUrl) {
    final uri = Uri.parse(confirmedHttpsBaseUrl);
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw ArgumentError('HTTPS endpoint required');
    }
    dio = Dio(
      BaseOptions(
        baseUrl: confirmedHttpsBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    dio.interceptors.add(AuthInterceptor(const FlutterSecureStorage()));
  }
  late final Dio dio;
  Future<dynamic> get(String path) async {
    try {
      return (await dio.get<dynamic>(path)).data;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw ApiException(
        status == 401
            ? '登录状态已过期，请重新登录'
            : status != null && status >= 500
            ? '服务器暂时不可用'
            : '网络连接失败，请检查网络',
      );
    }
  }
}
