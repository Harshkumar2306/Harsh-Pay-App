import 'package:dio/dio.dart';

class ApiClient {
  static const String baseUrl = 'https://harsh-bank.vercel.app/api';
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Fetches wallet data AND last 50 cloud transactions
  Future<Map<String, dynamic>?> fetchWalletData(String appSyncId) async {
    try {
      final response = await _dio.post('/sync/wallet', data: {
        'appSyncId': appSyncId,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      // Offline — return null silently
      return null;
    }
  }

  /// Uploads pending offline transactions to cloud
  Future<Map<String, dynamic>?> syncTransactions(
      String clerkId, List<Map<String, dynamic>> transactions) async {
    try {
      final response = await _dio.post('/sync/transactions', data: {
        'clerkId': clerkId,
        'transactions': transactions,
      });

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
