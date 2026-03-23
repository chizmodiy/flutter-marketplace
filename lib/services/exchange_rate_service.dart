import 'package:supabase_flutter/supabase_flutter.dart';

class ExchangeRate {
  final String currencyCode;
  final double rateToUah;
  final DateTime lastUpdatedAt;

  ExchangeRate({
    required this.currencyCode,
    required this.rateToUah,
    required this.lastUpdatedAt,
  });

  factory ExchangeRate.fromJson(Map<String, dynamic> json) {
    return ExchangeRate(
      currencyCode: json['currency_code'],
      rateToUah: (json['rate_to_uah'] as num).toDouble(),
      lastUpdatedAt: DateTime.parse(json['last_updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currency_code': currencyCode,
      'rate_to_uah': rateToUah,
      'last_updated_at': lastUpdatedAt.toIso8601String(),
    };
  }
}

class ExchangeRateService {
  final SupabaseClient _supabaseClient;

  ExchangeRateService(this._supabaseClient);

  Future<List<ExchangeRate>> fetchExchangeRates() async {
    try {
      final response = await _supabaseClient
          .from('exchange_rates')
          .select<List<Map<String, dynamic>>>('*');

      return response.map((json) => ExchangeRate.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching exchange rates: $e');
      return [];
    }
  }

  Future<void> updateExchangeRate(String currencyCode, double newRate) async {
    try {
      await _supabaseClient
          .from('exchange_rates')
          .update({
            'rate_to_uah': newRate,
            'last_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('currency_code', currencyCode);
    } catch (e) {
      print('Error updating exchange rate for $currencyCode: $e');
      rethrow; // Rethrow to handle in UI
    }
  }

  Future<void> addExchangeRate(String currencyCode, double rate) async {
    try {
      await _supabaseClient.from('exchange_rates').insert({
        'currency_code': currencyCode,
        'rate_to_uah': rate,
      });
    } catch (e) {
      print('Error adding exchange rate for $currencyCode: $e');
      rethrow; // Rethrow to handle in UI
    }
  }

  Future<void> deleteExchangeRate(String currencyCode) async {
    try {
      await _supabaseClient
          .from('exchange_rates')
          .delete()
          .eq('currency_code', currencyCode);
    } catch (e) {
      print('Error deleting exchange rate for $currencyCode: $e');
      rethrow; // Rethrow to handle in UI
    }
  }
}
