import 'package:supabase_flutter/supabase_flutter.dart';

class Make {
  final String id;
  final String name;

  Make({required this.id, required this.name});

  factory Make.fromJson(Map<String, dynamic> json) {
    return Make(id: json['id'] as String, name: json['name'] as String);
  }
}

class Model {
  final String id;
  final String name;
  final String makeId;

  Model({required this.id, required this.name, required this.makeId});

  factory Model.fromJson(Map<String, dynamic> json) {
    return Model(
      id: json['id'] as String,
      name: json['name'] as String,
      makeId: json['make_id'] as String,
    );
  }
}

class Style {
  final String id;
  final String styleName;
  final String? fuelType;
  final String modelId;

  Style({
    required this.id,
    required this.styleName,
    this.fuelType,
    required this.modelId,
  });

  factory Style.fromJson(Map<String, dynamic> json) {
    return Style(
      id: json['id'] as String,
      styleName: json['style_name'] as String,
      fuelType: json['fuel_type'] as String?,
      modelId: json['model_id'] as String,
    );
  }
}

class ModelYear {
  final String id;
  final int year;
  final String styleId;

  ModelYear({required this.id, required this.year, required this.styleId});

  factory ModelYear.fromJson(Map<String, dynamic> json) {
    return ModelYear(
      id: json['id'] as String,
      year: json['year'] as int,
      styleId: json['style_id'] as String,
    );
  }
}

class CarService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Отримати всі марки, відсортовані за назвою
  Future<List<Make>> getMakes() async {
    try {
      final response = await _supabase
          .from('makes')
          .select()
          .order('name', ascending: true);

      return (response as List).map((json) => Make.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Отримати моделі для конкретної марки
  Future<List<Model>> getModels(String makeId) async {
    try {
      final response = await _supabase
          .from('models')
          .select()
          .eq('make_id', makeId)
          .order('name', ascending: true);

      return (response as List).map((json) => Model.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Отримати стилі для конкретної моделі
  Future<List<Style>> getStyles(String modelId) async {
    try {
      final response = await _supabase
          .from('styles')
          .select()
          .eq('model_id', modelId)
          .order('style_name', ascending: true);
      final styles = (response as List)
          .map((json) => Style.fromJson(json))
          .toList();
      final seen = <String>{};
      return styles.where((s) => seen.add(s.styleName.trim())).toList();
    } catch (e) {
      return [];
    }
  }

  // Отримати роки випуску для конкретного стилю
  Future<List<ModelYear>> getModelYears(String styleId) async {
    try {
      final response = await _supabase
          .from('model_years')
          .select()
          .eq('style_id', styleId)
          .order('year', ascending: false);

      return (response as List)
          .map((json) => ModelYear.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Отримати рік випуску за ID
  Future<ModelYear?> getModelYearById(String modelYearId) async {
    try {
      final response = await _supabase
          .from('model_years')
          .select()
          .eq('id', modelYearId)
          .single();

      return ModelYear.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
