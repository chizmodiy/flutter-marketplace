import 'package:http/http.dart' as http;
import 'dart:convert';

class SimpleAlgoliaTester {
  final String appId;
  final String searchKey;
  final String indexName;

  SimpleAlgoliaTester({
    required this.appId,
    required this.searchKey,
    required this.indexName,
  });

  Future<void> testConnection() async {
    try {
      print('🔗 Тестуємо з\'єднання з Algolia...');

      final url =
          'https://$appId-dsn.algolia.net/1/indexes/$indexName/settings';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Algolia-API-Key': searchKey,
          'X-Algolia-Application-Id': appId,
        },
      );

      print('📊 Статус відповіді: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ З\'єднання успішне!');
        final data = jsonDecode(response.body);
        print('📋 Налаштування індексу:');
        print('  - Назва: ${data['indexName']}');
        print(
          '  - Пошукові атрибути: ${data['searchableAttributes']?.join(', ')}',
        );
        print('  - Фасети: ${data['attributesForFaceting']?.join(', ')}');
      } else {
        print('❌ Помилка: ${response.statusCode}');
        print('📄 Відповідь: ${response.body}');
      }
    } catch (e) {
      print('❌ Помилка з\'єднання: $e');
    }
  }

  Future<void> testSearch(String query) async {
    try {
      print('\n🔍 Тестуємо пошук: "$query"');

      final url = 'https://$appId-dsn.algolia.net/1/indexes/$indexName/query';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'X-Algolia-API-Key': searchKey,
          'X-Algolia-Application-Id': appId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'query': query, 'hitsPerPage': 5}),
      );

      print('📊 Статус відповіді: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Пошук успішний!');
        print('📊 Знайдено: ${data['nbHits']} результатів');
        print('⏱️ Час виконання: ${data['processingTimeMS']}ms');

        if (data['hits'] != null && data['hits'].isNotEmpty) {
          print('\n📋 Результати:');
          for (int i = 0; i < data['hits'].length && i < 3; i++) {
            final hit = data['hits'][i];
            print('  ${i + 1}. ${hit['title'] ?? 'Без назви'}');
          }
        }
      } else {
        print('❌ Помилка пошуку: ${response.statusCode}');
        print('📄 Відповідь: ${response.body}');
      }
    } catch (e) {
      print('❌ Помилка пошуку: $e');
    }
  }

  Future<void> testIndexInfo() async {
    try {
      print('\n📊 Отримуємо інформацію про індекс...');

      final url = 'https://$appId-dsn.algolia.net/1/indexes/$indexName';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Algolia-API-Key': searchKey,
          'X-Algolia-Application-Id': appId,
        },
      );

      print('📊 Статус відповіді: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Інформація отримана!');
        print('📋 Деталі індексу:');
        print('  - Назва: ${data['name']}');
        print('  - Кількість записів: ${data['entries']}');
        print('  - Розмір: ${data['dataSize']} байт');
        print('  - Останнє оновлення: ${data['lastUpdate']}');
      } else {
        print('❌ Помилка: ${response.statusCode}');
        print('📄 Відповідь: ${response.body}');
      }
    } catch (e) {
      print('❌ Помилка: $e');
    }
  }

  Future<void> runAllTests() async {
    print('🚀 Запуск простих тестів Algolia\n');

    // Тест з'єднання
    await testConnection();

    // Тест інформації про індекс
    await testIndexInfo();

    // Тест пошуку
    await testSearch('телефон');
    await testSearch('авто');
    await testSearch('квартира');

    print('\n✅ Всі тести завершено');
  }
}

void main() async {
  // Ваші ключі Algolia
  const appId = 'XYA8SCV3KC';
  const searchKey = '6782ed5c8812fb117b825a5890912b31';
  const indexName = 'products';

  final tester = SimpleAlgoliaTester(
    appId: appId,
    searchKey: searchKey,
    indexName: indexName,
  );

  await tester.runAllTests();
}
