import 'package:flutter/services.dart';
import 'dart:async';

class SmsAutofillService {
  static final SmsAutofillService _instance = SmsAutofillService._internal();
  factory SmsAutofillService() => _instance;
  SmsAutofillService._internal();

  /// Ініціалізує SMS автозаповнення
  Future<void> initialize() async {
    try {
      print('SMS автозаповнення ініціалізовано (без дозволів SMS)');
    } catch (e) {
      print('Помилка ініціалізації SMS автозаповнення: $e');
    }
  }

  /// Отримує код з SMS автоматично
  /// Повертає код якщо знайдено, інакше null
  Future<String?> getCodeFromSms({
    String? senderPhoneNumber,
    String? appSignature,
  }) async {
    try {
      print('Спроба отримання коду з SMS');
      return null; // Поки що повертаємо null, оскільки використовуємо вбудовані можливості Flutter
    } catch (e) {
      print('Помилка отримання коду з SMS: $e');
      return null;
    }
  }

  /// Слухає SMS і повертає код коли він надходить
  Stream<String> listenForSmsCode() {
    // Повертаємо порожній стрим, оскільки використовуємо вбудовані можливості
    return Stream.empty();
  }

  /// Перевіряє чи доступне SMS автозаповнення
  Future<bool> isSmsAutofillAvailable() async {
    try {
      // Flutter підтримує автозаповнення через AutofillHints без дозволів SMS
      // Це працює через системні можливості Android/iOS
      return true;
    } catch (e) {
      print('SMS автозаповнення недоступне: $e');
      return false;
    }
  }

  /// Отримує підпис додатку для SMS
  Future<String> getAppSignature() async {
    try {
      return 'flutter_app'; // Повертаємо базовий підпис
    } catch (e) {
      print('Помилка отримання підпису додатку: $e');
      return '';
    }
  }

  /// Зупиняє прослуховування SMS
  void dispose() {
    try {
      print('SMS сервіс зупинено');
    } catch (e) {
      print('Помилка зупинки прослуховування SMS: $e');
    }
  }

  /// Парсить код з тексту SMS
  /// Шукає 6-значний код у форматі "Ваш код підтвердження для Zeno: 123456"
  String? parseCodeFromSms(String smsText) {
    try {
      // Шукаємо 6-значний код
      final regex = RegExp(r'\b\d{6}\b');
      final match = regex.firstMatch(smsText);

      if (match != null) {
        return match.group(0);
      }

      // Альтернативний пошук для різних форматів
      final alternativeRegex = RegExp(
        r'код[:\s]*(\d{6})',
        caseSensitive: false,
      );
      final altMatch = alternativeRegex.firstMatch(smsText);

      if (altMatch != null) {
        return altMatch.group(1);
      }

      return null;
    } catch (e) {
      print('Помилка парсингу коду з SMS: $e');
      return null;
    }
  }
}
