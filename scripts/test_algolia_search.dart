import 'package:algoliasearch/algoliasearch.dart';

class AlgoliaSearchTester {
  late final SearchClient searchClient;
  late final String indexName;

  AlgoliaSearchTester({
    required String appId,
    required String searchKey,
    required String indexName,
  }) {
    this.indexName = indexName;
    searchClient = SearchClient(
      appId: appId,
      apiKey: searchKey, // Використовуємо Search-Only Key для тестування
    );
  }

  Future<void> testBasicSearch(String query) async {
    try {
      print('🔍 Тестуємо базовий пошук: "$query"');

      final response = await searchClient.searchIndex(
        request: SearchForHits(
          indexName: indexName,
          query: query,
          hitsPerPage: 10,
        ),
      );

      print('📊 Результати:');
      print('  - Знайдено: ${response.nbHits} результатів');
      print('  - Показано: ${response.hits.length} результатів');
      print('  - Час виконання: ${response.processingTimeMS}ms');

      if (response.hits.isNotEmpty) {
        print('\n📋 Перші результати:');
        for (int i = 0; i < response.hits.length && i < 5; i++) {
          final hit = response.hits[i];
          print('  ${i + 1}. ${hit['title']} (ID: ${hit['id']})');
          if (hit['price'] != null) {
            print('     Ціна: ${hit['price']} ${hit['currency'] ?? ''}');
          }
          if (hit['location'] != null) {
            print('     Локація: ${hit['location']}');
          }
        }
      }
    } catch (e) {
      print('❌ Помилка пошуку: $e');
    }
  }

  Future<void> testFilteredSearch({
    String? query,
    String? categoryId,
    String? region,
    bool? isFree,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      print('\n🔍 Тестуємо фільтрований пошук');
      print('  Query: $query');
      print('  Category: $categoryId');
      print('  Region: $region');
      print('  Free: $isFree');
      print('  Price: $minPrice - $maxPrice');

      // Будуємо фільтри
      final filters = <String>[];

      if (categoryId != null) {
        filters.add('category_id:$categoryId');
      }

      if (region != null) {
        filters.add('region:$region');
      }

      if (isFree != null) {
        filters.add('is_free:$isFree');
      }

      if (minPrice != null || maxPrice != null) {
        if (minPrice != null && maxPrice != null) {
          filters.add('price:$minPrice TO $maxPrice');
        } else if (minPrice != null) {
          filters.add('price >= $minPrice');
        } else if (maxPrice != null) {
          filters.add('price <= $maxPrice');
        }
      }

      final filterString = filters.isNotEmpty ? filters.join(' AND ') : null;

      final response = await searchClient.searchIndex(
        request: SearchForHits(
          indexName: indexName,
          query: query ?? '',
          filters: filterString,
          hitsPerPage: 10,
        ),
      );

      print('📊 Результати фільтрованого пошуку:');
      print('  - Знайдено: ${response.nbHits} результатів');
      print('  - Фільтри: $filterString');

      if (response.hits.isNotEmpty) {
        print('\n📋 Результати:');
        for (int i = 0; i < response.hits.length && i < 3; i++) {
          final hit = response.hits[i];
          print('  ${i + 1}. ${hit['title']}');
        }
      }
    } catch (e) {
      print('❌ Помилка фільтрованого пошуку: $e');
    }
  }

  Future<void> testGeoSearch({
    required double latitude,
    required double longitude,
    int radiusInKm = 50,
  }) async {
    try {
      print('\n🌍 Тестуємо геопошук');
      print('  Координати: $latitude, $longitude');
      print('  Радіус: ${radiusInKm}km');

      final response = await searchClient.searchIndex(
        request: SearchForHits(
          indexName: indexName,
          query: '',
          aroundLatLng: '$latitude,$longitude',
          aroundRadius: radiusInKm * 1000, // в метрах
          hitsPerPage: 10,
        ),
      );

      print('📊 Результати геопошуку:');
      print('  - Знайдено: ${response.nbHits} результатів');

      if (response.hits.isNotEmpty) {
        print('\n📋 Ближчі результати:');
        for (int i = 0; i < response.hits.length && i < 5; i++) {
          final hit = response.hits[i];
          final distance = hit['_rankingInfo']?['geoDistance'] ?? 'N/A';
          print('  ${i + 1}. ${hit['title']} (відстань: ${distance}м)');
        }
      }
    } catch (e) {
      print('❌ Помилка геопошуку: $e');
    }
  }

  Future<void> testFacets() async {
    try {
      print('\n🏷️ Тестуємо фасети');

      final response = await searchClient.searchIndex(
        request: SearchForHits(
          indexName: indexName,
          query: '',
          facets: ['category_name', 'region', 'is_free'],
          hitsPerPage: 0, // Тільки фасети, без результатів
        ),
      );

      print('📊 Доступні фасети:');

      if (response.facets != null) {
        for (final facet in response.facets!.entries) {
          print('\n  ${facet.key}:');
          for (final value in facet.value.entries) {
            print('    ${value.key}: ${value.value}');
          }
        }
      }
    } catch (e) {
      print('❌ Помилка отримання фасетів: $e');
    }
  }

  Future<void> runAllTests() async {
    print('🚀 Запуск всіх тестів Algolia пошуку\n');

    // Базовий пошук
    await testBasicSearch('телефон');
    await testBasicSearch('авто');
    await testBasicSearch('квартира');

    // Фільтрований пошук
    await testFilteredSearch(query: 'телефон', minPrice: 100, maxPrice: 1000);

    await testFilteredSearch(query: 'авто', isFree: false);

    // Геопошук (Київ)
    await testGeoSearch(latitude: 50.4501, longitude: 30.5234, radiusInKm: 20);

    // Фасети
    await testFacets();

    print('\n✅ Всі тести завершено');
  }
}

void main() async {
  // Нові ключі Algolia
  const appId = 'XYA8SCV3KC';
  const searchKey = '6782ed5c8812fb117b825a5890912b31';
  const indexName = 'products';

  final tester = AlgoliaSearchTester(
    appId: appId,
    searchKey: searchKey,
    indexName: indexName,
  );

  await tester.runAllTests();
}
