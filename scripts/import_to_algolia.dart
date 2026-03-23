import 'package:algoliasearch/algoliasearch.dart';
import 'dart:convert';
import 'dart:io';

class AlgoliaImporter {
  late final SearchClient searchClient;
  late final String indexName;

  AlgoliaImporter({
    required String appId,
    required String adminKey,
    required String indexName,
  }) {
    this.indexName = indexName;
    searchClient = SearchClient(
      appId: appId,
      apiKey: adminKey, // Використовуємо Admin Key для імпорту
    );
  }

  Future<void> importProductsFromFile(String filePath) async {
    try {
      print('📁 Читаємо файл: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        throw Exception('Файл не знайдено: $filePath');
      }

      final jsonString = await file.readAsString();
      final products = jsonDecode(jsonString) as List<dynamic>;

      print('📊 Знайдено ${products.length} продуктів для імпорту');

      // Імпортуємо дані в Algolia
      await _importBatch(products);

      print('✅ Імпорт завершено успішно!');
    } catch (e) {
      print('❌ Помилка імпорту: $e');
      rethrow;
    }
  }

  Future<void> _importBatch(List<dynamic> products) async {
    try {
      print('🔄 Імпортуємо ${products.length} записів...');

      // Імпортуємо кожен продукт окремо
      for (final product in products) {
        await searchClient.saveObject(indexName: indexName, body: product);
      }

      print('✅ Імпорт завершено');
    } catch (e) {
      print('❌ Помилка batch операції: $e');
      rethrow;
    }
  }

  Future<void> configureIndex() async {
    try {
      print('⚙️ Налаштовуємо індекс...');

      final configFile = File('algolia_config.json');
      if (!await configFile.exists()) {
        throw Exception('Файл конфігурації не знайдено: algolia_config.json');
      }

      final config = jsonDecode(await configFile.readAsString());

      // Налаштовуємо пошукові атрибути
      await searchClient.setSettings(
        indexName: indexName,
        indexSettings: IndexSettings(
          searchableAttributes: config['searchableAttributes'] as List<String>?,
          attributesForFaceting:
              config['attributesForFaceting'] as List<String>?,
          ranking: config['ranking'] as List<String>?,
          customRanking: config['customRanking'] as List<String>?,
          attributesToHighlight:
              config['attributesToHighlight'] as List<String>?,
          attributesToSnippet: config['attributesToSnippet'] as List<String>?,
          snippetEllipsisText: config['snippetEllipsisText'] as String?,
          highlightPreTag: config['highlightPreTag'] as String?,
          highlightPostTag: config['highlightPostTag'] as String?,
          distinct: config['distinct'] as bool?,
          advancedSyntax: config['advancedSyntax'] as bool?,
          decompoundQuery: config['decompoundQuery'] as bool?,
          ignorePlurals: config['ignorePlurals'] as bool?,
          removeStopWords: config['removeStopWords'] as bool?,
          camelCaseAttributes: config['camelCaseAttributes'] as List<String>?,
          numericAttributesForFiltering:
              config['numericAttributesForFiltering'] as List<String>?,
        ),
      );

      print('✅ Налаштування індексу завершено');
    } catch (e) {
      print('❌ Помилка налаштування індексу: $e');
      rethrow;
    }
  }

  Future<void> testSearch(String query) async {
    try {
      print('🔍 Тестуємо пошук: "$query"');

      final response = await searchClient.searchIndex(
        request: SearchForHits(
          indexName: indexName,
          query: query,
          hitsPerPage: 5,
        ),
      );

      print('📊 Знайдено ${response.nbHits} результатів');

      if (response.hits.isNotEmpty) {
        print('📋 Перші результати:');
        for (int i = 0; i < response.hits.length && i < 3; i++) {
          final hit = response.hits[i];
          print('  ${i + 1}. ${hit['title']} (${hit['id']})');
        }
      }
    } catch (e) {
      print('❌ Помилка тестування пошуку: $e');
    }
  }
}

void main() async {
  // Нові ключі Algolia
  const appId = 'XYA8SCV3KC';
  const adminKey = '822ba9bc100be86442292e334d088b20';
  const indexName = 'products';

  final importer = AlgoliaImporter(
    appId: appId,
    adminKey: adminKey,
    indexName: indexName,
  );

  try {
    // 1. Налаштовуємо індекс
    await importer.configureIndex();

    // 2. Імпортуємо дані
    await importer.importProductsFromFile('algolia_products_export.json');

    // 3. Тестуємо пошук
    await importer.testSearch('телефон');
    await importer.testSearch('авто');
  } catch (e) {
    print('❌ Помилка: $e');
  }
}
