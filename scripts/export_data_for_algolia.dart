import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:io';

class AlgoliaDataExporter {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> exportProductsForAlgolia() async {
    try {
      print('Експортуємо дані для Algolia...');

      // Отримуємо всі активні оголошення з детальною інформацією
      final response = await _supabase
          .from('listings')
          .select('''
            *,
            categories!id(name),
            subcategories!id(name)
          ''')
          .or('status.is.null,status.eq.active');

      final products = response as List<dynamic>;
      print('Знайдено ${products.length} активних оголошень');

      // Трансформуємо дані для Algolia
      final algoliaData = products.map((product) {
        final categoryName =
            (product['categories'] as Map<String, dynamic>?)?['name']
                as String?;
        final subcategoryName =
            (product['subcategories'] as Map<String, dynamic>?)?['name']
                as String?;

        return {
          'objectID': product['id'], // Унікальний ідентифікатор для Algolia
          'id': product['id'],
          'title': product['title'],
          'description': product['description'],
          'price': product['price'],
          'currency': product['currency'],
          'is_free': product['is_free'],
          'is_negotiable': product['is_negotiable'],
          'is_blocked': product['is_blocked'],
          'location': product['location'],
          'region': product['region'],
          'address': product['address'],
          'latitude': product['latitude'],
          'longitude': product['longitude'],
          'category_id': product['category_id'],
          'subcategory_id': product['subcategory_id'],
          'category_name': categoryName,
          'subcategory_name': subcategoryName,
          'user_id': product['user_id'],
          'status': product['status'],
          'phone_number': product['phone_number'],
          'whatsapp': product['whatsapp'],
          'telegram': product['telegram'],
          'viber': product['viber'],
          'custom_attributes': product['custom_attributes'],
          'photos': product['photos'],
          'created_at': product['created_at'],
          'updated_at': product['updated_at'],
          // Додаємо поля для пошуку
          '_tags': [
            if (categoryName != null) categoryName,
            if (subcategoryName != null) subcategoryName,
            if (product['region'] != null) product['region'],
            if (product['is_free'] == true) 'free',
            if (product['is_negotiable'] == true) 'negotiable',
            if (product['is_blocked'] == true) 'blocked',
          ].where((tag) => tag != null).toList(),
        };
      }).toList();

      // Зберігаємо у JSON файл
      final file = File('algolia_products_export.json');
      await file.writeAsString(jsonEncode(algoliaData));

      print('✅ Дані експортовано у файл: algolia_products_export.json');
      print('📊 Кількість записів: ${algoliaData.length}');

      // Показуємо приклад структури
      if (algoliaData.isNotEmpty) {
        print('\n📋 Приклад структури даних:');
        print(jsonEncode(algoliaData.first));
      }
    } catch (e) {
      print('❌ Помилка експорту: $e');
    }
  }

  Future<void> exportCategoriesForAlgolia() async {
    try {
      print('\nЕкспортуємо категорії для Algolia...');

      final response = await _supabase.from('categories').select('*');

      final categories = response as List<dynamic>;

      final algoliaData = categories.map((category) {
        return {
          'objectID': 'category_${category['id']}',
          'id': category['id'],
          'name': category['name'],
          'type': 'category',
          '_tags': ['category'],
        };
      }).toList();

      final file = File('algolia_categories_export.json');
      await file.writeAsString(jsonEncode(algoliaData));

      print('✅ Категорії експортовано у файл: algolia_categories_export.json');
      print('📊 Кількість категорій: ${algoliaData.length}');
    } catch (e) {
      print('❌ Помилка експорту категорій: $e');
    }
  }
}

void main() async {
  // Ініціалізація Supabase (потрібно налаштувати)
  await AlgoliaDataExporter().exportProductsForAlgolia();
  await AlgoliaDataExporter().exportCategoriesForAlgolia();
}
