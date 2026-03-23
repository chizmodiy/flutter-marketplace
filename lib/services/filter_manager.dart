import 'package:flutter/foundation.dart';

class FilterManager extends ChangeNotifier {
  static final FilterManager _instance = FilterManager._internal();
  factory FilterManager() => _instance;
  FilterManager._internal() {
    _currentFilters['currency'] = 'UAH'; // Set UAH as default currency
  }

  Map<String, dynamic> _currentFilters = {};
  bool _hasActiveFilters = false;

  // Геттери
  Map<String, dynamic> get currentFilters => Map.from(_currentFilters);
  bool get hasActiveFilters => _hasActiveFilters;

  // Покращений метод для встановлення фільтрів
  void setFilters(Map<String, dynamic> filters) {
    _currentFilters = {};
    filters.forEach((key, value) {
      if (_isValidFilter(key, value)) {
        _currentFilters[key] = value;
      }
    });
    // Ensure UAH is always present if no other currency is selected
    if (!_currentFilters.containsKey('currency') ||
        _currentFilters['currency'] == null ||
        _currentFilters['currency'] == '') {
      _currentFilters['currency'] = 'UAH';
    }
    _hasActiveFilters =
        _currentFilters.isNotEmpty; // Recalculate hasActiveFilters
    if (_currentFilters.length == 1 &&
        _currentFilters.containsKey('currency') &&
        _currentFilters['currency'] == 'UAH') {
      _hasActiveFilters = false;
    }
    notifyListeners();
  }

  // Метод для перевірки валідності фільтра
  bool _isValidFilter(String key, dynamic value) {
    if (value == null || value == '' || value == 'all') {
      return false;
    }

    switch (key) {
      case 'minPrice':
      case 'minArea':
      case 'minYear':
      case 'minMileage':
      case 'minAge':
        return value is num && value > 0;

      case 'maxPrice':
        // Максимальна ціна повинна бути меншою за реальну максимальну
        return value is num && value > 0 && value < 999999999;

      case 'maxArea':
        return value is num &&
            value > 0 &&
            value < 10000; // Реалістичний ліміт площі

      case 'maxYear':
        return value is num &&
            value >= 1900 &&
            value <= DateTime.now().year + 1;

      case 'maxMileage':
        return value is num &&
            value > 0 &&
            value < 10000; // Реалістичний ліміт пробігу (тис. км)

      case 'maxAge':
        return value is num &&
            value >= 0 &&
            value < 200; // Реалістичний ліміт віку

      case 'isFree':
        return value == true; // Тільки true має значення

      case 'currency':
        // Фільтр валюти активний, якщо вибрана конкретна валюта (включаючи UAH)
        return value != null && value != '';

      case 'category':
        return value != null && value != '' && value != 'all';

      case 'subcategory':
      case 'region':
      case 'car_brand':
      case 'size':
      case 'condition':
      case 'make_id':
      case 'model_id':
      case 'style_id':
      case 'model_year_id':
        return value != null && value != '';

      default:
        return value != null && value != '';
    }
  }

  // Метод для очищення фільтрів
  void clearFilters() {
    _currentFilters.clear();
    _currentFilters['currency'] = 'UAH'; // Set UAH as default currency
    _hasActiveFilters = false;
    notifyListeners();
  }

  // Метод для оновлення конкретного фільтра
  void updateFilter(String key, dynamic value) {
    if (value == null || value == '') {
      _currentFilters.remove(key);
    } else {
      _currentFilters[key] = value;
    }
    // Ensure UAH is always present if no other currency is selected
    if (!_currentFilters.containsKey('currency') ||
        _currentFilters['currency'] == null ||
        _currentFilters['currency'] == '') {
      _currentFilters['currency'] = 'UAH';
    }
    _hasActiveFilters = _currentFilters.isNotEmpty;
    if (_currentFilters.length == 1 &&
        _currentFilters.containsKey('currency') &&
        _currentFilters['currency'] == 'UAH') {
      _hasActiveFilters = false;
    }
    notifyListeners();
  }

  // Метод для отримання конкретного фільтра
  dynamic getFilter(String key) {
    return _currentFilters[key];
  }

  // Метод для перевірки чи є активні фільтри
  bool hasFilter(String key) {
    return _currentFilters.containsKey(key);
  }

  // Метод для отримання кількості активних фільтрів
  int get activeFiltersCount {
    int count = 0;

    bool hasCategoryFilter = false;
    if (_currentFilters.containsKey('category') &&
        _currentFilters['category'] != null &&
        _currentFilters['category'].toString().isNotEmpty &&
        _currentFilters['category'] != 'all') {
      hasCategoryFilter = true;
    }
    if (_currentFilters.containsKey('subcategory') &&
        _currentFilters['subcategory'] != null &&
        _currentFilters['subcategory'].toString().isNotEmpty) {
      hasCategoryFilter = true;
    }
    if (hasCategoryFilter) {
      count++;
    }

    // Region filter: Active if selected
    if (_currentFilters.containsKey('region') &&
        _currentFilters['region'] != null) {
      count++;
    }

    // Price/IsFree filters
    if (_currentFilters.containsKey('isFree') &&
        _currentFilters['isFree'] == true) {
      count++; // 'Віддам безкоштовно' counts as one filter
    } else {
      bool hasPriceMin =
          _currentFilters.containsKey('minPrice') &&
          _currentFilters['minPrice'] != null &&
          _currentFilters['minPrice'] is num &&
          _currentFilters['minPrice'] > 0;
      bool hasPriceMax =
          _currentFilters.containsKey('maxPrice') &&
          _currentFilters['maxPrice'] != null &&
          _currentFilters['maxPrice']
              is num; // Max price can be 0 or other values, check if it's explicitly set
      bool hasCurrency =
          _currentFilters.containsKey('currency') &&
          _currentFilters['currency'] != null &&
          _currentFilters['currency'] != 'UAH';

      if (hasPriceMin || hasPriceMax || hasCurrency) {
        count++;
      }
    }

    // Area filter (minArea and maxArea together count as one if either is present and non-default)
    bool hasAreaMin =
        _currentFilters.containsKey('minArea') &&
        _currentFilters['minArea'] != null &&
        _currentFilters['minArea'] is num &&
        _currentFilters['minArea'] > 0;
    bool hasAreaMax =
        _currentFilters.containsKey('maxArea') &&
        _currentFilters['maxArea'] != null &&
        _currentFilters['maxArea'] is num;
    if (hasAreaMin || hasAreaMax) {
      count++;
    }

    // Year filter (minYear and maxYear together count as one if either is present and non-default)
    bool hasYearMin =
        _currentFilters.containsKey('minYear') &&
        _currentFilters['minYear'] != null &&
        _currentFilters['minYear'] is num &&
        _currentFilters['minYear'] > 0;
    bool hasYearMax =
        _currentFilters.containsKey('maxYear') &&
        _currentFilters['maxYear'] != null &&
        _currentFilters['maxYear'] is num;
    if (hasYearMin || hasYearMax) {
      count++;
    }

    // Mileage filter (minMileage and maxMileage together count as one if either is present and non-default)
    bool hasMileageMin =
        _currentFilters.containsKey('minMileage') &&
        _currentFilters['minMileage'] != null &&
        _currentFilters['minMileage'] is num &&
        _currentFilters['minMileage'] > 0;
    bool hasMileageMax =
        _currentFilters.containsKey('maxMileage') &&
        _currentFilters['maxMileage'] != null &&
        _currentFilters['maxMileage'] is num;
    if (hasMileageMin || hasMileageMax) {
      count++;
    }

    // Car Brand filter
    if (_currentFilters.containsKey('car_brand') &&
        _currentFilters['car_brand'] != null) {
      count++;
    }

    // Size filter
    if (_currentFilters.containsKey('size') &&
        _currentFilters['size'] != null) {
      count++;
    }

    // Condition filter
    if (_currentFilters.containsKey('condition') &&
        _currentFilters['condition'] != null) {
      count++;
    }

    // Age filter (minAge and maxAge together count as one if either is present and non-default)
    bool hasAgeMin =
        _currentFilters.containsKey('minAge') &&
        _currentFilters['minAge'] != null &&
        _currentFilters['minAge'] is num &&
        _currentFilters['minAge'] > 0;
    bool hasAgeMax =
        _currentFilters.containsKey('maxAge') &&
        _currentFilters['maxAge'] != null &&
        _currentFilters['maxAge'] is num;
    if (hasAgeMin || hasAgeMax) {
      count++;
    }

    // Нові фільтри для легкових авто та авто з Польщі
    // Make, Model, Style, ModelYear рахуються окремо
    if (_currentFilters.containsKey('make_id') &&
        _currentFilters['make_id'] != null) {
      count++;
    }

    if (_currentFilters.containsKey('model_id') &&
        _currentFilters['model_id'] != null) {
      count++;
    }

    if (_currentFilters.containsKey('style_id') &&
        _currentFilters['style_id'] != null) {
      count++;
    }

    if (_currentFilters.containsKey('model_year_id') &&
        _currentFilters['model_year_id'] != null) {
      count++;
    }

    return count;
  }
}
