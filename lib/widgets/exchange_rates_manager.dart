import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/exchange_rate_service.dart';

class ExchangeRatesManager extends StatefulWidget {
  const ExchangeRatesManager({Key? key}) : super(key: key);

  @override
  State<ExchangeRatesManager> createState() => _ExchangeRatesManagerState();
}

class _ExchangeRatesManagerState extends State<ExchangeRatesManager> {
  late final ExchangeRateService _exchangeRateService;
  List<ExchangeRate> _exchangeRates = [];
  bool _isLoading = true;
  String? _errorMessage;

  final Map<String, TextEditingController> _rateControllers = {};
  final Map<String, String?> _rateErrorMessages = {};
  final Map<String, double> _originalRates = {}; // Зберігати оригінальні курси

  @override
  void initState() {
    super.initState();
    _exchangeRateService = ExchangeRateService(Supabase.instance.client);
    _fetchExchangeRates();
  }

  Future<void> _fetchExchangeRates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _exchangeRates = await _exchangeRateService.fetchExchangeRates();
      _exchangeRates.sort((a, b) => a.currencyCode.compareTo(b.currencyCode));

      _rateControllers.forEach((key, controller) => controller.dispose());
      _rateControllers.clear();
      _rateErrorMessages.clear();
      _originalRates.clear(); // Очистити оригінальні курси

      for (var rate in _exchangeRates) {
        _rateControllers[rate.currencyCode] = TextEditingController(
          text: rate.rateToUah.toStringAsFixed(4),
        );
        _rateErrorMessages[rate.currencyCode] = null;
        _originalRates[rate.currencyCode] =
            rate.rateToUah; // Зберегти оригінальний курс
      }
    } catch (e) {
      _errorMessage = 'Не вдалося завантажити курси валют: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _validateAndSetError(String currencyCode, String? message) {
    setState(() {
      _rateErrorMessages[currencyCode] = message;
    });
  }

  bool _isRateChanged(String currencyCode) {
    final controller = _rateControllers[currencyCode];
    if (controller == null) return false;

    final currentRate = double.tryParse(controller.text.trim());
    final originalRate = _originalRates[currencyCode];

    // Порівнюємо з фіксованою точністю, щоб уникнути проблем з числами з плаваючою комою
    return currentRate != null &&
        originalRate != null &&
        (currentRate - originalRate).abs() > 0.000001; // Достатньо мала різниця
  }

  Future<void> _updateRate(String currencyCode) async {
    final controller = _rateControllers[currencyCode];
    if (controller == null) return;

    final newRateString = controller.text.trim();

    if (newRateString.isEmpty) {
      _validateAndSetError(currencyCode, 'Поле не може бути порожнім.');
      return;
    }

    final newRate = double.tryParse(newRateString);

    if (newRate == null) {
      _validateAndSetError(currencyCode, 'Введіть дійсне число.');
      return;
    }

    if (newRate <= 0) {
      _validateAndSetError(currencyCode, 'Курс повинен бути більшим за нуль.');
      return;
    }

    final parts = newRateString.split('.');
    if (parts.length > 1 && parts[1].length > 4) {
      _validateAndSetError(currencyCode, 'Максимум 4 знаки після коми.');
      return;
    }

    _validateAndSetError(currencyCode, null);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _exchangeRateService.updateExchangeRate(currencyCode, newRate);
      _showSnackBar('Курс для $currencyCode оновлено успішно!', Colors.green);
      _rateControllers[currencyCode]?.text = newRate.toStringAsFixed(4);
      _originalRates[currencyCode] =
          newRate; // Оновити оригінальний курс після успішного збереження
    } catch (e) {
      _showSnackBar(
        'Помилка оновлення курсу для $currencyCode: $e',
        Colors.red,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  void dispose() {
    _rateControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Курси валют',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _exchangeRates.length,
              itemBuilder: (context, index) {
                final rate = _exchangeRates[index];
                final controller = _rateControllers[rate.currencyCode];
                final errorMessage = _rateErrorMessages[rate.currencyCode];

                final bool isDisabled =
                    _isLoading ||
                    (errorMessage != null) ||
                    !_isRateChanged(rate.currencyCode);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4E4E7)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${rate.currencyCode} до UAH',
                        style: const TextStyle(
                          color: Color(0xFF52525B),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          letterSpacing: 0.14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFFAFAFA),
                          hintText: 'Введіть курс',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE4E4E7),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE4E4E7),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF52525B),
                              width: 2,
                            ),
                          ),
                          errorText: errorMessage,
                        ),
                        onChanged: (value) {
                          if (errorMessage != null) {
                            _validateAndSetError(rate.currencyCode, null);
                          }
                          setState(
                            () {},
                          ); // Оновлюємо UI для перевірки _isRateChanged
                        },
                        onSubmitted: (_) => _updateRate(rate.currencyCode),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isDisabled
                              ? null
                              : () => _updateRate(rate.currencyCode),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDisabled
                                ? const Color(0xFFF4F4F5)
                                : const Color(
                                    0xFF015873,
                                  ), // Zinc-100 (inactive) / Primary (active)
                            foregroundColor: isDisabled
                                ? Colors.black
                                : Colors
                                      .white, // Black (inactive) / White (active)
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                width: 1,
                                color: isDisabled
                                    ? const Color(0xFFF4F4F5)
                                    : const Color(
                                        0xFF015873,
                                      ), // Zinc-100 (inactive) / Primary (active)
                              ),
                              borderRadius: BorderRadius.circular(200),
                            ),
                            shadowColor: isDisabled
                                ? Colors.transparent
                                : const Color(
                                    0x0C101828,
                                  ), // Shadow only for active
                            elevation: isDisabled ? 0 : 2,
                          ),
                          child: Text(
                            'Зберегти зміни',
                            style: TextStyle(
                              color: isDisabled ? Colors.black : Colors.white,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              height: 1.40,
                              letterSpacing: 0.14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
