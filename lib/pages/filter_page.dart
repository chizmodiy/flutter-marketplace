import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'package:zeno/models/category.dart';
import 'package:zeno/services/category_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/price_formatter.dart';
import 'package:zeno/models/subcategory.dart';
import 'package:zeno/services/subcategory_service.dart';
import 'package:zeno/pages/category_selection_page.dart';
import 'package:zeno/pages/subcategory_selection_page.dart';
// import 'package:zeno/pages/currency_selection_page.dart'; // Removed import
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zeno/services/listing_service.dart'; // Import ListingService
import 'package:zeno/data/subcategories_data.dart'; // Import for getExtraFieldsForSubcategory
import '../services/profile_service.dart';
import '../widgets/blocked_user_bottom_sheet.dart';
import '../widgets/error_banner.dart';
import 'region_selection_page.dart';
import '../services/filter_manager.dart';
import '../services/exchange_rate_service.dart'; // Додайте цей імпорт
import '../services/car_service.dart';
import '../widgets/keyboard_dismisser.dart';

class FilterPage extends StatefulWidget {
  final Map<String, dynamic> initialFilters;

  const FilterPage({super.key, required this.initialFilters});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  Category? _selectedCategory;
  Subcategory? _selectedSubcategory;
  List<Category> _selectedRegions = [];
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _minAreaController = TextEditingController();
  final TextEditingController _maxAreaController = TextEditingController();
  final TextEditingController _minYearController = TextEditingController();
  final TextEditingController _maxYearController = TextEditingController();
  final TextEditingController _minMileageController = TextEditingController();
  final TextEditingController _maxMileageController = TextEditingController();
  final TextEditingController _minCarYearController = TextEditingController();
  final TextEditingController _maxCarYearController = TextEditingController();
  final TextEditingController _minAgeController = TextEditingController();
  final TextEditingController _maxAgeController = TextEditingController();
  final TextEditingController _radiusRController = TextEditingController();

  String? _selectedCurrency; // Changed to nullable
  bool _isPriceModePrice = true;
  String? _selectedBrand;
  String? _selectedSize;
  String? _selectedCondition;
  String? _selectedCarBrand;

  // Нові фільтри для легкових авто та авто з Польщі
  Make? _selectedMake;
  Model? _selectedModel;
  Style? _selectedStyle;
  ModelYear? _selectedModelYear;
  List<Make> _makes = [];
  List<Model> _models = [];
  List<Style> _styles = [];
  List<ModelYear> _modelYears = [];
  bool _isLoadingMakes = false;
  bool _isLoadingModels = false;
  bool _isLoadingStyles = false;
  bool _isLoadingModelYears = false;
  final CarService _carService = CarService();
  final GlobalKey _makeKey = GlobalKey();
  final GlobalKey _modelKey = GlobalKey();
  final GlobalKey _styleKey = GlobalKey();
  final GlobalKey _modelYearKey = GlobalKey();
  final GlobalKey _makeSelectorKey = GlobalKey();
  final GlobalKey _modelSelectorKey = GlobalKey();
  final GlobalKey _styleSelectorKey = GlobalKey();
  bool _isMakeOpen = false;
  bool _isModelOpen = false;
  bool _isStyleOpen = false;
  bool _isModelYearOpen = false;
  final TextEditingController _makeSearchController = TextEditingController();
  final TextEditingController _modelSearchController = TextEditingController();
  final TextEditingController _styleSearchController = TextEditingController();

  // Змінні для цін
  double _minPrice = 0.0;
  double _maxPrice = 0.0;

  // Змінні для інших діапазонів
  double _minAvailableArea = 0.0;
  double _maxAvailableArea = 200.0;
  double _minAvailableYear = 1990.0;
  double _maxAvailableYear = 2024.0;
  double _minAvailableMileage = 0.0;
  double _maxAvailableMileage = 1000.0; // in thousands km

  // Змінні для помилок валідації
  String? _minPriceError;
  String? _maxPriceError;
  String? _minAgeError;
  String? _maxAgeError;
  String? _minAreaError;
  String? _maxAreaError;
  String? _minYearError;
  String? _maxYearError;
  String? _minMileageError;
  String? _maxMileageError;

  bool _isInitialDataReady = true;
  Timer? _priceValidationTimer;
  Timer? _areaValidationTimer;
  Timer? _yearValidationTimer;
  Timer? _ageValidationTimer;

  bool _isLoadingPrices = true;
  bool _isLoadingCategories = true;
  bool _isLoadingSubcategories = false;
  List<Category> _categories = [];
  List<Subcategory> _subcategories = [];

  late final ListingService _listingService;
  final ProfileService _profileService = ProfileService();

  double _currentMinMileage =
      0.0; // Поточне мінімальне значення пробігу (тис. км)
  double _currentMaxMileage =
      1000.0; // Поточне максимальне значення пробігу (тис. км)

  // Додати змінну для кешування
  static Map<String, double>? _cachedPriceRange;

  // Змінні для курсів валют (ДОДАЙТЕ ЦІ РЯДКИ)
  late final ExchangeRateService _exchangeRateService;
  Map<String, double> _exchangeRatesMap =
      {}; // Карта для зберігання курсів: {'USD': 38.5, 'EUR': 42.0}

  String? _realEstateType = 'sale';
  String? _jobType = 'offering';
  String? _helpType = 'offering';
  String? _giveawayType = 'giving'; // Default to "Віддам"
  String? _conditionType = 'new';
  String? _genderType = 'both'; // Default to "Обидва"

  // Змінні для збереження початкових значень фільтрів
  Map<String, dynamic> _initialFilters = {};

  @override
  void initState() {
    super.initState();
    _exchangeRateService = ExchangeRateService(Supabase.instance.client);
    _initializeFilters();

    if (widget.initialFilters.isNotEmpty) {
      _isInitialDataReady = false;
    }

    _loadExchangeRates().then((_) {
      _loadPriceRange().then((__) {
        if (widget.initialFilters.isNotEmpty && _exchangeRatesMap.isNotEmpty) {
          _applyInitialPriceFilters();
        }
        _checkInitialDataReady();
      });
    });
    _loadCategories();
    _loadMileageRange(); // Завантажуємо діапазон пробігу

    _genderType = widget.initialFilters['gender_type'] ?? 'both';
    _jobType = widget.initialFilters['job_type'] ?? 'offering';
    _conditionType = widget.initialFilters['condition_type'] ?? 'new';

    if (widget.initialFilters['minMileage'] != null) {
      _minMileageController.text = (widget.initialFilters['minMileage'] as num)
          .toStringAsFixed(0);
    }
    if (widget.initialFilters['maxMileage'] != null) {
      _maxMileageController.text = (widget.initialFilters['maxMileage'] as num)
          .toStringAsFixed(0);
    }
    if (widget.initialFilters['radius_r'] != null) {
      _radiusRController.text = widget.initialFilters['radius_r'].toString();
    }
  }

  // НОВИЙ МЕТОД: Завантаження курсів валют з бази даних (ДОДАЙТЕ ЦЕЙ БЛОК)
  Future<void> _loadExchangeRates() async {
    try {
      final rates = await _exchangeRateService.fetchExchangeRates();
      setState(() {
        _exchangeRatesMap = {
          for (var rate in rates) rate.currencyCode: rate.rateToUah,
        };
        // Додаємо UAH до мапи з курсом 1.0, якщо його немає
        if (!_exchangeRatesMap.containsKey('UAH')) {
          _exchangeRatesMap['UAH'] = 1.0;
        }
      });
    } catch (e) {
      print('Error loading exchange rates: $e');
      // Встановлюємо дефолтні курси, якщо не вдалося завантажити
      setState(() {
        _exchangeRatesMap = {'USD': 38.0, 'EUR': 41.0, 'UAH': 1.0};
      });
    }
  }

  // Методи завантаження даних для нових фільтрів авто
  Future<void> _loadMakes() async {
    // Перевіряємо, чи обрана підкатегорія "Легкові автомобілі" або "Автомобілі з Польщі"
    if (_selectedCategory?.name != 'Авто' ||
        (_selectedSubcategory?.name != 'Легкові автомобілі' &&
            _selectedSubcategory?.name != 'Автомобілі з Польщі')) {
      return;
    }

    setState(() {
      _isLoadingMakes = true;
    });

    try {
      final makes = await _carService.getMakes();
      setState(() {
        _makes = makes;
        _isLoadingMakes = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingMakes = false;
      });
    }
  }

  // Load models when make is selected
  Future<void> _loadModels(String makeId, {bool resetSelection = true}) async {
    setState(() {
      _isLoadingModels = true;
      if (resetSelection) {
        _selectedModel = null;
        _selectedStyle = null;
        _selectedModelYear = null;
        _styles.clear();
        _modelYears.clear();
      }
      _models.clear();
    });

    try {
      final models = await _carService.getModels(makeId);
      setState(() {
        _models = models;
        _isLoadingModels = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  // Load styles when model is selected
  Future<void> _loadStyles(String modelId, {bool resetSelection = true}) async {
    setState(() {
      _isLoadingStyles = true;
      if (resetSelection) {
        _selectedStyle = null;
        _selectedModelYear = null;
        _modelYears.clear();
        // Очищаємо поля "від-до" коли скидаємо Style
        _minCarYearController.clear();
        _maxCarYearController.clear();
        _minYearError = null;
        _maxYearError = null;
      }
      _styles.clear();
    });

    try {
      final styles = await _carService.getStyles(modelId);
      setState(() {
        _styles = styles;
        _isLoadingStyles = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingStyles = false;
      });
    }
  }

  // Load model years when style is selected
  Future<void> _loadModelYears(
    String styleId, {
    bool resetSelection = true,
  }) async {
    setState(() {
      _isLoadingModelYears = true;
      if (resetSelection) {
        _selectedModelYear = null;
      }
      _modelYears.clear();
    });

    try {
      final modelYears = await _carService.getModelYears(styleId);
      setState(() {
        _modelYears = modelYears;
        _isLoadingModelYears = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingModelYears = false;
      });
    }
  }

  void _initializeFilters() {
    if (widget.initialFilters.isNotEmpty) {
      _selectedCurrency = widget.initialFilters['currency'] as String? ?? 'UAH';
      _isPriceModePrice = widget.initialFilters['isFree'] != true;
      // Площа
      if (widget.initialFilters['minArea'] != null) {
        _minAreaController.text = widget.initialFilters['minArea'].toString();
      }
      if (widget.initialFilters['maxArea'] != null) {
        _maxAreaController.text = widget.initialFilters['maxArea'].toString();
      }
      // Рік
      if (widget.initialFilters['minYear'] != null) {
        _minYearController.text = widget.initialFilters['minYear'].toString();
        _minCarYearController.text = widget.initialFilters['minYear']
            .toString();
      }
      if (widget.initialFilters['maxYear'] != null) {
        _maxYearController.text = widget.initialFilters['maxYear'].toString();
        _maxCarYearController.text = widget.initialFilters['maxYear']
            .toString();
      }
      // Рік для легкових авто (якщо Style не обрано)
      if (widget.initialFilters['minCarYear'] != null) {
        _minCarYearController.text = widget.initialFilters['minCarYear']
            .toString();
      }
      if (widget.initialFilters['maxCarYear'] != null) {
        _maxCarYearController.text = widget.initialFilters['maxCarYear']
            .toString();
      }
      // Пробіг
      if (widget.initialFilters['minMileage'] != null) {
        _minMileageController.text =
            (widget.initialFilters['minMileage'] as num).toStringAsFixed(0);
      }
      if (widget.initialFilters['maxMileage'] != null) {
        _maxMileageController.text =
            (widget.initialFilters['maxMileage'] as num).toStringAsFixed(0);
      }
      // Вік
      if (widget.initialFilters['minAge'] != null) {
        _minAgeController.text = widget.initialFilters['minAge'].toString();
      }
      if (widget.initialFilters['maxAge'] != null) {
        _maxAgeController.text = widget.initialFilters['maxAge'].toString();
      }
      _selectedBrand = widget.initialFilters['car_brand'];
      _selectedSize = widget.initialFilters['size'];
      _selectedCondition = widget.initialFilters['condition'];
      _realEstateType = widget.initialFilters['real_estate_type'] ?? 'sale';

      // Ініціалізація нових фільтрів авто (make_id, model_id, style_id, model_year_id)
      // Примітка: повне завантаження буде виконано після завантаження підкатегорій
      // в методі _onCategorySelected або _onSubcategorySelected
      _jobType = widget.initialFilters['job_type'] ?? 'offering';
      _conditionType = widget.initialFilters['condition_type'] ?? 'new';
      if (widget.initialFilters['regions'] != null) {
        _selectedRegions = (widget.initialFilters['regions'] as List).map((r) => Category(id: r['id'], name: r['name'])).toList();
      } else if (widget.initialFilters['region_id'] != null &&
          widget.initialFilters['region_name'] != null) {
        // Backwards compatibility
        _selectedRegions = [
          Category(
            id: widget.initialFilters['region_id'],
            name: widget.initialFilters['region_name'],
          )
        ];
      }
    } else {
      _selectedCurrency = 'UAH'; // Set UAH as default if no initial filters
    }
  }

  // ОНОВЛЕНИЙ МЕТОД: Отримання діапазону цін у вибраній валюті
  Future<Map<String, double>> _getPriceRangeInSelectedCurrency(
    String targetCurrency,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      String priceColumn;

      // Вибираємо відповідний стовпець ціни на основі targetCurrency
      switch (targetCurrency.toLowerCase()) {
        case 'uah':
          priceColumn = 'price_in_uah';
          break;
        case 'usd':
          priceColumn = 'price_in_usd';
          break;
        case 'eur':
          priceColumn = 'price_in_eur';
          break;
        default:
          // За замовчуванням UAH, якщо валюта невідома
          priceColumn = 'price_in_uah';
          break;
      }

      // Запитуємо мінімальну та максимальну ціну безпосередньо з відповідного стовпця
      final response = await supabase
          .rpc(
            'get_min_max_price_by_currency_column',
            params: {'currency_price_column': priceColumn},
          )
          .single();

      if (response != null) {
        final minPrice = (response['min'] as num?)?.toDouble() ?? 0.0;
        final maxPrice = (response['max'] as num?)?.toDouble() ?? 100000.0;

        return {'min': minPrice, 'max': maxPrice};
      }

      // Якщо немає даних, повертаємо дефолтні значення
      return {'min': 0.0, 'max': 100000.0};
    } catch (e) {
      print('Error getting price range in selected currency: $e');
      // Повертаємо дефолтні значення у випадку помилки
      return {'min': 0.0, 'max': 100000.0};
    }
  }

  // ОНОВЛЕНИЙ МЕТОД: Завантаження діапазону цін з урахуванням вибраної валюти
  Future<void> _loadPriceRange() async {
    // Все ще отримуємо діапазон цін (для валідації), але НЕ підставляємо у контролери!
    final priceRangeInSelectedCurrency = await _getPriceRangeInSelectedCurrency(
      _selectedCurrency ?? 'UAH',
    );
    // Логуємо отримані значення для відладки
    print(
      'Price range for [32m${_selectedCurrency ?? 'UAH'}[0m: Min = ${priceRangeInSelectedCurrency['min']}, Max = ${priceRangeInSelectedCurrency['max']}',
    );
    setState(() {
      _minPrice = priceRangeInSelectedCurrency['min'] ?? 0.0;
      _maxPrice = priceRangeInSelectedCurrency['max'] ?? 100000.0;
      _isLoadingPrices = false;
    });
  }

  // ОНОВЛЕНИЙ МЕТОД: Обробка зміни валюти
  Future<void> _onCurrencyChanged(String currency) async {
    setState(() {
      if (currency == 'UAH') {
        _selectedCurrency = 'UAH';
      } else if (_selectedCurrency == currency) {
        _selectedCurrency = 'UAH'; // If already selected, revert to UAH
      } else {
        _selectedCurrency = currency; // Select the new currency
      }
    });

    // Очищуємо кеш цін, щоб отримати свіжі дані
    _cachedPriceRange = null;

    // Перезавантажуємо діапазон цін з новою валютою
    await _loadPriceRange();
  }

  // ОНОВЛЕНИЙ МЕТОД: Застосування початкових фільтрів цін
  void _applyInitialPriceFilters() {
    setState(() {
      if (widget.initialFilters['minPrice'] != null) {
        final minPriceFromFilterUAH = double.tryParse(
          widget.initialFilters['minPrice'].toString(),
        );
        if (minPriceFromFilterUAH != null) {
          // Конвертуємо з UAH в обрану валюту
          final minPriceInSelectedCurrency = _convertFromUAH(
            minPriceFromFilterUAH,
            _selectedCurrency ?? 'UAH',
          );
          _minPriceController.text = minPriceInSelectedCurrency.toStringAsFixed(
            0,
          );
        }
      }

      if (widget.initialFilters['maxPrice'] != null) {
        final maxPriceFromFilterUAH = double.tryParse(
          widget.initialFilters['maxPrice'].toString(),
        );
        if (maxPriceFromFilterUAH != null) {
          // Конвертуємо з UAH в обрану валюту
          final maxPriceInSelectedCurrency = _convertFromUAH(
            maxPriceFromFilterUAH,
            _selectedCurrency ?? 'UAH',
          );
          _maxPriceController.text = maxPriceInSelectedCurrency.toStringAsFixed(
            0,
          );
        }
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final categoryService = CategoryService();
      final categories = await categoryService.getCategories();
      Category? foundCategory;
      if (widget.initialFilters['category'] != null) {
        try {
          foundCategory = categories.firstWhere(
            (cat) => cat.id == widget.initialFilters['category'],
          );
        } catch (_) {}
      }
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
        _selectedCategory = foundCategory;
      });
      if (foundCategory != null) {
        await _loadSubcategories(foundCategory.id);
      }
      _checkInitialDataReady();
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      _checkInitialDataReady();
    }
  }

  void _checkInitialDataReady() {
    if (!widget.initialFilters.isNotEmpty) return;
    if (_exchangeRatesMap.isEmpty ||
        _isLoadingCategories ||
        _isLoadingSubcategories ||
        _isLoadingPrices)
      return;
    if (mounted) {
      setState(() => _isInitialDataReady = true);
    }
  }

  Future<void> _loadSubcategories(String categoryId) async {
    setState(() {
      _isLoadingSubcategories = true;
      _selectedSubcategory = null;
    });

    try {
      final subcategoryService = SubcategoryService(Supabase.instance.client);
      final subcategories = await subcategoryService
          .getSubcategoriesForCategory(categoryId);
      Subcategory? selectedSubcategory;
      setState(() {
        _subcategories = subcategories;
        _isLoadingSubcategories = false;
        if (widget.initialFilters['subcategory'] != null &&
            widget.initialFilters['subcategory'] is String) {
          try {
            selectedSubcategory = _subcategories.firstWhere(
              (sub) => sub.id == widget.initialFilters['subcategory'],
            );
            _selectedSubcategory = selectedSubcategory;
          } catch (_) {}
        }
      });

      if (selectedSubcategory != null &&
          (selectedSubcategory!.name == 'Легкові автомобілі' ||
              selectedSubcategory!.name == 'Автомобілі з Польщі')) {
        await _loadMakes();
        await _initializeCarFiltersFromInitialFilters();
      }
    } catch (e) {
      setState(() {
        _isLoadingSubcategories = false;
      });
    }
  }

  @override
  void dispose() {
    _priceValidationTimer?.cancel();
    _areaValidationTimer?.cancel();
    _yearValidationTimer?.cancel();
    _ageValidationTimer?.cancel();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minAreaController.dispose();
    _maxAreaController.dispose();
    _minYearController.dispose();
    _maxYearController.dispose();
    _minMileageController.dispose();
    _maxMileageController.dispose();
    _minCarYearController.dispose();
    _maxCarYearController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    _radiusRController.dispose();
    _makeSearchController.dispose();
    _modelSearchController.dispose();
    _styleSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadMinMaxPrices(String currency) async {
    setState(() {
      _isLoadingPrices = true;
    });
    try {
      final prices = await _listingService.getMinMaxPrices(currency);
      setState(() {
        _minPrice = 0.0;
        _maxPrice = prices['maxPrice'] ?? 100.0;
        _minPriceController.text = '0';
        _maxPriceController.text = _maxPrice.toStringAsFixed(0);
      });
    } catch (e) {
      setState(() {
        _minPrice = 0.0;
        _maxPrice = 100.0;
        _minPriceController.text = '0';
        _maxPriceController.text = '100';
      });
    } finally {
      setState(() {
        _isLoadingPrices = false;
      });
    }
  }

  void _resetFilters() {
    final FilterManager filterManager = FilterManager();
    filterManager.clearFilters();

    setState(() {
      // Скидаємо всі вибрані значення
      _selectedCategory = null;
      _selectedSubcategory = null;
      _selectedRegions = [];
      _selectedBrand = null;
      _selectedSize = null;
      _selectedCondition = null;
      _subcategories = [];

      // Очищаємо всі текстові поля
      _minPriceController.clear();
      _maxPriceController.clear();
      _minAreaController.clear();
      _maxAreaController.clear();
      _minYearController.clear();
      _maxYearController.clear();
      _minMileageController.clear();
      _maxMileageController.clear();
      _minAgeController.clear();
      _maxAgeController.clear();
      _minCarYearController.clear();
      _maxCarYearController.clear();
      _radiusRController.clear();

      // Скидаємо помилки валідації
      _minPriceError = null;
      _maxPriceError = null;
      _minAgeError = null;
      _maxAgeError = null;
      _minAreaError = null;
      _maxAreaError = null;
      _minYearError = null;
      _maxYearError = null;
      _minMileageError = null;
      _maxMileageError = null;
      _realEstateType = 'sale';
      _jobType = 'offering';
      _conditionType = 'new';

      // Встановлюємо базові значення
      _selectedCurrency = 'UAH'; // Set to UAH on reset
      _isPriceModePrice = true;

      // Перезавантажуємо діапазон цін для відображення оригінальних валют
      _loadPriceRange();
    });
    Navigator.of(context).pop(
      <String, dynamic>{},
    ); // Return empty map after reset with explicit type
  }

  void _applyFilters() {
    // Перевіряємо наявність помилок валідації
    if (_minPriceError != null ||
        _maxPriceError != null ||
        _minAgeError != null ||
        _maxAgeError != null ||
        _minAreaError != null ||
        _maxAreaError != null ||
        _minYearError != null ||
        _maxYearError != null ||
        _minMileageError != null ||
        _maxMileageError != null) {
      _showErrorSnackBar('Будь ласка, виправте помилки у полях фільтрів.');
      return;
    }

    final Map<String, dynamic> filters = {};

    // Логуємо стан для відладки
    print('FilterPage._applyFilters: Selected Currency = $_selectedCurrency');
    print(
      'FilterPage._applyFilters: Min Price Controller Text = ${_minPriceController.text}',
    );
    print(
      'FilterPage._applyFilters: Max Price Controller Text = ${_maxPriceController.text}',
    );

    // Категорія
    if (_selectedCategory != null) {
      filters['category'] = _selectedCategory!.id;
    }

    // Підкатегорія
    if (_selectedSubcategory != null) {
      filters['subcategory'] = _selectedSubcategory!.id;
    }

    // Регіон
    if (_selectedRegions.isNotEmpty) {
      filters['regions'] = _selectedRegions.map((e) => {'id': e.id, 'name': e.name}).toList();
      // Backwards compatibility for single region logic that might still exist occasionally 
      filters['region'] = _selectedRegions.map((e) => e.name).toList();
    }

    // Валюта - ВАЖЛИВО: передаємо тільки якщо не UAH
    if (_selectedCurrency != null) {
      // Changed condition
      filters['currency'] = _selectedCurrency;
    }

    // Режим безкоштовно
    if (!_isPriceModePrice) {
      filters['isFree'] = true;
    } else {
      // Ціни - завжди в гривнях, але конвертуємо для фільтрації
      if (_minPriceController.text.isNotEmpty) {
        final minPriceInSelectedCurrency = double.tryParse(
          _minPriceController.text.replaceAll(' ', ''),
        );
        print(
          'FilterPage._applyFilters: minPriceInSelectedCurrency = $minPriceInSelectedCurrency (Selected Currency: $_selectedCurrency)',
        );
        if (minPriceInSelectedCurrency != null &&
            minPriceInSelectedCurrency >= 0) {
          // Конвертуємо з обраної валюти в гривні для фільтрації в базі даних
          final minPriceInUAH = _convertToUAH(
            minPriceInSelectedCurrency,
            _selectedCurrency ?? 'UAH',
          );
          print(
            'FilterPage._applyFilters: Converted minPriceInUAH = $minPriceInUAH',
          );
          filters['minPrice'] = minPriceInUAH;
        }
      }

      if (_maxPriceController.text.isNotEmpty) {
        final maxPriceInSelectedCurrency = double.tryParse(
          _maxPriceController.text.replaceAll(' ', ''),
        );
        print(
          'FilterPage._applyFilters: maxPriceInSelectedCurrency = $maxPriceInSelectedCurrency (Selected Currency: $_selectedCurrency)',
        );
        if (maxPriceInSelectedCurrency != null &&
            maxPriceInSelectedCurrency >= 0) {
          // Конвертуємо з обраної валюти в гривні для фільтрації в базі даних
          final maxPriceInUAH = _convertToUAH(
            maxPriceInSelectedCurrency,
            _selectedCurrency ?? 'UAH',
          );
          print(
            'FilterPage._applyFilters: Converted maxPriceInUAH = $maxPriceInUAH',
          );
          filters['maxPrice'] = maxPriceInUAH;
        }
      }
    }

    // Площа
    if (_minAreaController.text.isNotEmpty) {
      final minArea = double.tryParse(_minAreaController.text);
      if (minArea != null && minArea > 0 && minArea != _minAvailableArea) {
        filters['minArea'] = minArea;
      }
    }

    if (_maxAreaController.text.isNotEmpty) {
      final maxArea = double.tryParse(_maxAreaController.text);
      if (maxArea != null && maxArea > 0 && maxArea < 10000) {
        filters['maxArea'] = maxArea;
      }
    }

    // Пробіг
    if (_minMileageController.text.isNotEmpty) {
      final minMileage = double.tryParse(_minMileageController.text);
      if (minMileage != null) {
        filters['minMileage'] = minMileage;
      }
    }
    if (_maxMileageController.text.isNotEmpty) {
      final maxMileage = double.tryParse(_maxMileageController.text);
      if (maxMileage != null) {
        filters['maxMileage'] = maxMileage;
      }
    }

    // Рік
    if (_minYearController.text.isNotEmpty) {
      final minYear = int.tryParse(_minYearController.text);
      if (minYear != null && minYear > _minAvailableYear) {
        filters['minYear'] = minYear;
      }
    }

    if (_maxYearController.text.isNotEmpty) {
      final maxYear = int.tryParse(_maxYearController.text);
      if (maxYear != null && maxYear < _maxAvailableYear) {
        filters['maxYear'] = maxYear;
      }
    }

    // Вік
    if (_minAgeController.text.isNotEmpty) {
      final minAge = int.tryParse(_minAgeController.text);
      if (minAge != null && minAge > 0) {
        filters['minAge'] = minAge;
      }
    }

    if (_maxAgeController.text.isNotEmpty) {
      final maxAge = int.tryParse(_maxAgeController.text);
      if (maxAge != null && maxAge < 100 && maxAge > 0) {
        filters['maxAge'] = maxAge;
      }
    }

    // Інші фільтри
    if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
      filters['car_brand'] = _selectedBrand;
    }

    if (_selectedSize != null && _selectedSize!.isNotEmpty) {
      filters['size'] = _selectedSize;
    }

    if (_selectedCondition != null && _selectedCondition!.isNotEmpty) {
      filters['condition'] = _selectedCondition;
    }

    if ((_selectedCategory?.name == 'Нерухомість' ||
            _selectedCategory?.name == 'Житло подобово') &&
        _realEstateType?.isNotEmpty == true) {
      filters['real_estate_type'] = _realEstateType;
    }

    if (_selectedCategory?.name == 'Робота' && _jobType?.isNotEmpty == true) {
      filters['job_type'] = _jobType;
    }

    if (_selectedCategory?.name == 'Одяг та аксесуари' &&
        _conditionType?.isNotEmpty == true) {
      filters['condition_type'] = _conditionType;
    }

    if (_selectedSize != null) {
      filters['size'] = _selectedSize;
    }

    if (_radiusRController.text.isNotEmpty) {
      filters['radius_r'] = double.tryParse(_radiusRController.text);
    }

    if (_genderType != 'both') {
      filters['gender_type'] = _genderType;
    }

    // Нові фільтри для легкових авто та авто з Польщі
    if (_selectedMake != null) {
      filters['make_id'] = _selectedMake!.id;
    }
    if (_selectedModel != null) {
      filters['model_id'] = _selectedModel!.id;
    }
    if (_selectedStyle != null) {
      filters['style_id'] = _selectedStyle!.id;
    }
    final bool isCarOrCarPoland =
        _selectedSubcategory != null &&
        (_selectedSubcategory!.id == 'cars' ||
            _selectedSubcategory!.id == 'cars_poland' ||
            _selectedSubcategory!.name.contains('Легкові автомобілі') ||
            _selectedSubcategory!.name.contains('Автомобілі з Польщі'));
    if (isCarOrCarPoland) {
      if (_minCarYearController.text.isNotEmpty) {
        final minYear = int.tryParse(_minCarYearController.text);
        if (minYear != null && minYear > 1900) {
          filters['minCarYear'] = minYear;
        }
      }
      if (_maxCarYearController.text.isNotEmpty) {
        final maxYear = int.tryParse(_maxCarYearController.text);
        if (maxYear != null && maxYear <= DateTime.now().year + 1) {
          filters['maxCarYear'] = maxYear;
        }
      }
    }

    // Логуємо кінцеві фільтри перед поверненням
    print('FilterPage._applyFilters: Filters to return = $filters');

    // Застосовуємо фільтри через FilterManager
    final FilterManager filterManager = FilterManager();
    filterManager.setFilters(filters);

    // Повертаємо результат
    Navigator.of(context).pop(filters);
  }

  void _navigateToCategorySelection() async {
    final Map<String, dynamic>? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategorySelectionPage(
          selectedCategory: _selectedCategory,
          selectedSubcategory: _selectedSubcategory,
        ),
      ),
    );

    if (result != null) {
      final Category? category = result['category'];
      final Subcategory? subcategory = result['subcategory'];

      if (category != null) {
        _onCategorySelected(
          category,
          subcategory: subcategory,
        ); // Викликаємо _onCategorySelected для оновлення стану та логіки
      } else {
        setState(() {
          _selectedCategory = null;
          _selectedSubcategory = null;
          _minPriceController.clear();
          _maxPriceController.clear();
          _minMileageController.clear();
          _maxMileageController.clear();
          _selectedSize = null;
          _realEstateType = 'sale';
          _jobType = 'offering';
          _helpType = 'offering';
          _giveawayType = 'giving';
          _conditionType = 'new';
          _genderType = 'both';
        });
      }
    }
  }

  void _navigateToSubcategorySelection() async {
    if (_selectedCategory == null) return;

    final Subcategory? selectedSubcategory = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubcategorySelectionPage(
          category: _selectedCategory!,
          selectedSubcategory: _selectedSubcategory,
        ),
      ),
    );

    if (selectedSubcategory != null) {
    setState(() {
      _selectedSubcategory = selectedSubcategory == _selectedSubcategory ? null : selectedSubcategory;
    });
  }  }

  void _showCarBrandSelection() {
    final List<String> carBrands = [
      'Volkswagen',
      'BMW',
      'Audi',
      'Mercedes-Benz',
      'Toyota',
      'Renault',
      'Skoda',
      'Ford',
      'Nissan',
      'Opel',
      'Інше',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE4E4E7))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Оберіть марку авто',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: carBrands.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(carBrands[index]),
                    onTap: () {
                      setState(() {
                        _selectedCarBrand = carBrands[index];
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Removed _navigateToCurrencySelection method

  @override
  Widget build(BuildContext context) {
    print(
      'DEBUG: Currently on FilterPage. Selected Category: ${_selectedCategory?.name}',
    ); // Оновлене логування
    return wrapWithKeyboardDismisser(
      Scaffold(
        backgroundColor: AppColors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 1 + 20),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.zinc200, width: 1.0),
              ),
            ),
            child: AppBar(
              backgroundColor: AppColors.white,
              elevation: 0,
              automaticallyImplyLeading:
                  false, // Прибираємо автоматичну кнопку назад
              title: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, color: AppColors.black, size: 24),
                    const SizedBox(width: 18), // Відстань 18 пікселів
                    Text(
                      'Фільтр',
                      style: TextStyle(
                        color: const Color(0xFF161817),
                        fontSize: 24,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        height: 1.20,
                      ),
                    ),
                  ],
                ),
              ),
              centerTitle: false,
              actions: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _resetFilters,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'Скинути фільтри',
                            style: TextStyle(
                              color: const Color(0xFF015873) /* Primary */,
                              fontSize: 16,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              height: 1.50,
                              letterSpacing: 0.16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: !_isInitialDataReady
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: Listener(
                      onPointerDown: (event) {
                        if (_isMakeOpen || _isModelOpen || _isStyleOpen) {
                          if (!_isTapInsideCarDropdown(event.position)) {
                            setState(() {
                              _isMakeOpen = false;
                              _isModelOpen = false;
                              _isStyleOpen = false;
                            });
                          }
                        }
                      },
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // БЛОК 1: Категорія та підкатегорія
                            _buildBlock1(),

                            const SizedBox(height: 24),

                            // БЛОК 2: Валюта
                            if (_selectedCategory?.name !=
                                    'Віддам безкоштовно' &&
                                _selectedCategory?.name != 'Знайомства')
                              _buildCurrencyBlock(),

                            const SizedBox(height: 24),

                            // БЛОК 3: Ціна
                            if (_selectedCategory?.name !=
                                    'Віддам безкоштовно' &&
                                _selectedCategory?.name != 'Знайомства')
                              _buildBlock2(),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Fixed buttons at the bottom
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border(
                        top: BorderSide(color: AppColors.zinc200, width: 1),
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isFormValid() ? _applyFilters : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isFormValid()
                                  ? AppColors.primaryColor
                                  : AppColors.zinc200,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Підтвердити',
                              style: AppTextStyles.body1Semibold.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: AppColors.zinc200,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Text(
                              'Скасувати',
                              style: AppTextStyles.body1Semibold.copyWith(
                                color: AppColors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBlock1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _navigateToCategorySelection,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: const Color(0xFFFAFAFA) /* Zinc-50 */,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: 1,
                  color: const Color(0xFFE4E4E7) /* Zinc-200 */,
                ),
                borderRadius: BorderRadius.circular(200),
              ),
              shadows: [
                BoxShadow(
                  color: Color(0x0C101828),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _selectedCategory?.name ?? 'Оберіть категорію',
                        style: TextStyle(
                          color: _selectedCategory == null
                              ? const Color(0xFFA1A1AA) /* Zinc-400 */
                              : Colors.black,
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.50,
                          letterSpacing: 0.16,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedCategory?.name != 'Віддам безкоштовно')
                  Container(
                    width: 20,
                    height: 20,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(),
                    child: Stack(),
                  ),
              ],
            ),
          ),
        ),
        if (_selectedCategory != null &&
            _selectedCategory?.name != 'Віддам безкоштовно') ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _navigateToSubcategorySelection,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: 1,
                    color: const Color(0xFFE4E4E7) /* Zinc-200 */,
                  ),
                  borderRadius: BorderRadius.circular(200),
                ),
                shadows: [
                  BoxShadow(
                    color: Color(0x0C101828),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _selectedSubcategory?.name ?? 'Оберіть підкатегорію',
                          style: TextStyle(
                            color: _selectedSubcategory == null
                                ? const Color(0xFFA1A1AA) /* Zinc-400 */
                                : Colors.black,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            height: 1.50,
                            letterSpacing: 0.16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(),
                    child: Stack(),
                  ),
                ],
              ),
            ),
          ),
        ],
        // Додаткові фільтри одразу після вибору підкатегорії
        if (_selectedSubcategory != null) ...[
          const SizedBox(height: 8),
          _buildAdditionalFilters(),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _navigateToRegionSelection,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: const Color(0xFFFAFAFA) /* Zinc-50 */,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: 1,
                  color: const Color(0xFFE4E4E7) /* Zinc-200 */,
                ),
                borderRadius: BorderRadius.circular(200),
              ),
              shadows: [
                BoxShadow(
                  color: Color(0x0C101828),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedRegions.isEmpty
                              ? 'Оберіть області'
                              : _selectedRegions.map((e) => e.name).join(', '),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: _selectedRegions.isEmpty
                                ? const Color(0xFFA1A1AA) /* Zinc-400 */
                                : Colors.black,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            height: 1.50,
                            letterSpacing: 0.16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(),
                  child: Stack(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlock2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок та перемикач для Ціна
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ціна',
              style: TextStyle(
                color: const Color(0xFF09090B) /* Zinc-950 */,
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                height: 1.40,
                letterSpacing: 0.14,
              ),
            ),
            GestureDetector(
              onTap: () {
                // Поля "Ціна" НЕ обовʼязкові — не підтягуємо min/max з бази і не автозаповнюємо.
                setState(() {
                  _isPriceModePrice = !_isPriceModePrice;
                  _minPriceController.clear();
                  _maxPriceController.clear();
                  _minPriceError = null;
                  _maxPriceError = null;
                });
              },
              child: Container(
                width: 40,
                padding: const EdgeInsets.all(4),
                decoration: ShapeDecoration(
                  color: _isPriceModePrice
                      ? const Color(0xFF015873) /* Primary */
                      : const Color(0xFFE4E4E7) /* Zinc-200 */,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(133.33),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Color(0x4CA5A3AE),
                      blurRadius: 5.33,
                      offset: Offset(0, 2.67),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: _isPriceModePrice
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: ShapeDecoration(
                        color: Colors.white /* White */,
                        shape: OvalBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Контент для режиму "Ціна"
        if (_isPriceModePrice) ...[
          const SizedBox(height: 16),
          // Поля вводу цін
          Row(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: _minPriceError != null
                            ? Colors.red
                            : const Color(0xFFE4E4E7) /* Zinc-200 */,
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x0C101828),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _minPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                        PriceInputFormatter(),
                      ],
                      textAlign: TextAlign.center,
                      onChanged: (value) =>
                          _debouncedPriceValidation(value, true),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: _getPriceHintForCurrency(1),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.0,
                          letterSpacing: 0.16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                        letterSpacing: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 44,
                child: Center(
                  child: Text(
                    '-',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA) /* Zinc-400 */,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      height: 1.50,
                      letterSpacing: 0.16,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: _maxPriceError != null
                            ? Colors.red
                            : const Color(0xFFE4E4E7) /* Zinc-200 */,
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x0C101828),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                        PriceInputFormatter(),
                      ],
                      textAlign: TextAlign.center,
                      onChanged: (value) =>
                          _debouncedPriceValidation(value, false),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: _getPriceHintForCurrency(1000),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.0,
                          letterSpacing: 0.16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                        letterSpacing: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],

        // Заголовок та перемикач для Безкоштовно
        const SizedBox(
          height: 16,
        ), // Відстань 16 пікселів між слайдером та блоком "Безкоштовно"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Безкоштовно',
              style: TextStyle(
                color: const Color(0xFF09090B) /* Zinc-950 */,
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                height: 1.40,
                letterSpacing: 0.14,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isPriceModePrice = false;
                  _minPriceController.clear();
                  _maxPriceController.clear();
                });
              },
              child: Container(
                width: 40,
                padding: const EdgeInsets.all(4),
                decoration: ShapeDecoration(
                  color: !_isPriceModePrice
                      ? const Color(0xFF015873) /* Primary */
                      : const Color(0xFFE4E4E7) /* Zinc-200 */,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(133.33),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Color(0x4CA5A3AE),
                      blurRadius: 5.33,
                      offset: Offset(0, 2.67),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: !_isPriceModePrice
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: ShapeDecoration(
                        color: Colors.white /* White */,
                        shape: OvalBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrencyBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Валюта',
          style: TextStyle(
            color: const Color(0xFF52525B) /* Zinc-600 */,
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            height: 1.40,
            letterSpacing: 0.14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(200),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCurrency = _selectedCurrency == 'UAH' ? null : 'UAH';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      color: _selectedCurrency == 'UAH'
                          ? const Color(0xFF015873) /* Primary */
                          : Colors.white /* White */,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          width: 1,
                          color: _selectedCurrency == 'UAH'
                              ? const Color(0xFF015873) /* Primary */
                              : const Color(0xFFE4E4E7) /* Zinc-200 */,
                        ),
                        borderRadius: BorderRadius.circular(200),
                      ),
                      shadows: [
                        BoxShadow(
                          color: Color(0x0C101828),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(),
                          child: SvgPicture.asset(
                            'assets/icons/currency-grivna-svgrepo-com 1.svg',
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              _selectedCurrency == 'UAH'
                                  ? Colors.white
                                  : const Color(0xFF52525B),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ГРН',
                          style: TextStyle(
                            color: _selectedCurrency == 'UAH'
                                ? Colors.white /* White */
                                : const Color(0xFF52525B) /* Zinc-600 */,
                            fontSize: 14,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            height: 1.40,
                            letterSpacing: 0.14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCurrency = _selectedCurrency == 'EUR' ? null : 'EUR';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      color: _selectedCurrency == 'EUR'
                          ? const Color(0xFF015873) /* Primary */
                          : Colors.white /* White */,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          width: 1,
                          color: _selectedCurrency == 'EUR'
                              ? const Color(0xFF015873) /* Primary */
                              : const Color(0xFFE4E4E7) /* Zinc-200 */,
                        ),
                        borderRadius: BorderRadius.circular(200),
                      ),
                      shadows: [
                        BoxShadow(
                          color: Color(0x0C101828),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(),
                          child: SvgPicture.asset(
                            'assets/icons/currency-euro.svg',
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              _selectedCurrency == 'EUR'
                                  ? Colors.white
                                  : const Color(0xFF52525B),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'EUR',
                          style: TextStyle(
                            color: _selectedCurrency == 'EUR'
                                ? Colors.white /* White */
                                : const Color(0xFF52525B) /* Zinc-600 */,
                            fontSize: 14,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            height: 1.40,
                            letterSpacing: 0.14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCurrency = _selectedCurrency == 'USD' ? null : 'USD';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      color: _selectedCurrency == 'USD'
                          ? const Color(0xFF015873) /* Primary */
                          : Colors.white /* White */,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          width: 1,
                          color: _selectedCurrency == 'USD'
                              ? const Color(0xFF015873) /* Primary */
                              : const Color(0xFFE4E4E7) /* Zinc-200 */,
                        ),
                        borderRadius: BorderRadius.circular(200),
                      ),
                      shadows: [
                        BoxShadow(
                          color: Color(0x0C101828),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(),
                          child: SvgPicture.asset(
                            'assets/icons/currency-dollar.svg',
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              _selectedCurrency == 'USD'
                                  ? Colors.white
                                  : const Color(0xFF52525B),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'USD',
                          style: TextStyle(
                            color: _selectedCurrency == 'USD'
                                ? Colors.white /* White */
                                : const Color(0xFF52525B) /* Zinc-600 */,
                            fontSize: 14,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            height: 1.40,
                            letterSpacing: 0.14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToRegionSelection() async {
    final Map<String, dynamic>? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegionSelectionPage(initialSelectedRegions: _selectedRegions)),
    );

    if (result != null) {
      final List<Category>? categories = result['categories'];
      if (categories != null) {
        setState(() {
          _selectedRegions = categories;
        });
      }
    }
  }

  // Метод для отримання діапазону цін з бази (всі валюти конвертовані в гривні)
  Future<Map<String, double>> _getPriceRangeFromDatabase() async {
    try {
      final supabase = Supabase.instance.client;

      // Отримуємо всі ціни з різних валют
      final response = await supabase
          .from('listings')
          .select('price, currency')
          .not('price', 'is', null)
          .not('is_free', 'eq', true); // Виключаємо безкоштовні оголошення

      if (response != null && response.isNotEmpty) {
        // Конвертуємо всі ціни в гривні
        final pricesInUAH = response.map((item) {
          final price = (item['price'] as num).toDouble();
          final currency =
              item['currency'] as String? ??
              'UAH'; // Ensure currency is not null
          return _convertToUAH(price, currency);
        }).toList();

        pricesInUAH.sort();

        final minPrice = pricesInUAH.first;
        final maxPrice = pricesInUAH.last;

        return {'min': minPrice, 'max': maxPrice};
      }

      // Якщо немає даних, повертаємо дефолтні значення
      return {'min': 0.0, 'max': 100000.0};
    } catch (e) {
      print('Error getting price range: $e');
      // Повертаємо дефолтні значення у випадку помилки
      return {'min': 0.0, 'max': 100000.0};
    }
  }

  // Метод для конвертації ціни в гривні (ОНОВІТТЬ ЦЕЙ МЕТОД)
  double _convertToUAH(double price, String currency) {
    final rate =
        _exchangeRatesMap[currency.toUpperCase()] ??
        1.0; // Використовуємо завантажений курс
    return price * rate;
  }

  // Метод для конвертації з гривень в обрану валюту (ОНОВІТТЬ ЦЕЙ МЕТОД)
  double _convertFromUAH(double priceUAH, String currency) {
    final rate = _exchangeRatesMap[currency.toUpperCase()] ?? 1.0;
    if (rate == 0) return priceUAH;
    return priceUAH / rate;
  }

  String _getPriceHintForCurrency(int value) {
    switch (_selectedCurrency?.toUpperCase() ?? 'UAH') {
      case 'EUR':
        return '$value€';
      case 'USD':
        return '\$$value';
      default:
        return '$value₴';
    }
  }

  void _debouncedPriceValidation(String value, bool isMinPrice) {
    _priceValidationTimer?.cancel();
    if (value.isEmpty) {
      setState(() {
        if (isMinPrice) {
          _minPriceError = null;
        } else {
          _maxPriceError = null;
        }
      });
      return;
    }
    _priceValidationTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final error = _validatePrice(value, isMinPrice);
      setState(() {
        if (isMinPrice) {
          _minPriceError = error;
        } else {
          _maxPriceError = error;
        }
      });
      if (error != null) {
        _showErrorSnackBar(error);
      }
    });
  }

  void _debouncedAreaValidation(String value, bool isMinArea) {
    _areaValidationTimer?.cancel();
    if (value.isEmpty) {
      setState(() {
        if (isMinArea)
          _minAreaError = null;
        else
          _maxAreaError = null;
      });
      return;
    }
    final isRequired =
        _selectedCategory?.name == 'Нерухомість' ||
        _selectedCategory?.name == 'Житло подобово' ||
        (_selectedSubcategory != null &&
            (getExtraFieldsForSubcategory(_selectedSubcategory!.id)?['area'] !=
                null));
    _areaValidationTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final error = _validateArea(value, isMinArea, isRequired: isRequired);
      setState(() {
        if (isMinArea)
          _minAreaError = error;
        else
          _maxAreaError = error;
      });
      if (error != null) {
        _showErrorSnackBar(error);
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
  }

  void _debouncedYearValidation(
    String value,
    bool isMinYear, {
    bool isRequired = false,
  }) {
    _yearValidationTimer?.cancel();
    if (value.isEmpty) {
      setState(() {
        if (isMinYear)
          _minYearError = null;
        else
          _maxYearError = null;
      });
      return;
    }
    _yearValidationTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final error = _validateYear(value, isMinYear, isRequired: isRequired);
      setState(() {
        if (isMinYear)
          _minYearError = error;
        else
          _maxYearError = error;
      });
    });
  }

  void _debouncedCarYearValidation(String value, bool isMinYear) {
    _yearValidationTimer?.cancel();
    if (value.isEmpty) {
      setState(() {
        if (isMinYear)
          _minYearError = null;
        else
          _maxYearError = null;
      });
      return;
    }
    _yearValidationTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final isRequired =
          _selectedCategory?.name == 'Авто' ||
          (_selectedSubcategory != null &&
              (getExtraFieldsForSubcategory(
                    _selectedSubcategory!.id,
                  )?['year'] !=
                  null));
      final error = _validateYear(value, isMinYear, isRequired: isRequired);
      setState(() {
        if (isMinYear)
          _minYearError = error;
        else
          _maxYearError = error;
      });
    });
  }

  void _debouncedAgeValidation(String value, bool isMinAge) {
    _ageValidationTimer?.cancel();
    if (value.isEmpty) {
      setState(() {
        if (isMinAge)
          _minAgeError = null;
        else
          _maxAgeError = null;
      });
      return;
    }
    final isRequired =
        _selectedCategory?.name == 'Знайомства' ||
        (_selectedSubcategory != null &&
            (getExtraFieldsForSubcategory(_selectedSubcategory!.id)?['age'] !=
                null));
    _ageValidationTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final error = _validateAge(value, isMinAge, isRequired: isRequired);
      setState(() {
        if (isMinAge)
          _minAgeError = error;
        else
          _maxAgeError = error;
      });
      if (error != null) {
        _showErrorSnackBar(error);
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
  }

  String? _validatePrice(String? value, bool isMinPrice) {
    if (value == null || value.isEmpty) return null;

    final String cleanValue = value.replaceAll(' ', '');
    final price = double.tryParse(cleanValue);
    if (price == null) {
      return 'Введіть дійсне число';
    }

    if (price < 0) {
      return 'Ціна не може бути від\'ємною';
    }

    // Перевірка, що мінімальна ціна не дорівнює максимальній
    final minPriceVal = double.tryParse(
      _minPriceController.text.replaceAll(' ', ''),
    );
    final maxPriceVal = double.tryParse(
      _maxPriceController.text.replaceAll(' ', ''),
    );

    if (minPriceVal != null &&
        maxPriceVal != null &&
        minPriceVal == maxPriceVal) {
      return 'Мінімальна та максимальна ціни не можуть бути однаковими';
    }

    if (price < 1) {
      return 'Мінімальна ціна: 1';
    }

    // Перевіряємо, щоб мінімальна ціна не була більше максимальної
    if (isMinPrice) {
      final maxPrice = double.tryParse(
        _maxPriceController.text.replaceAll(' ', ''),
      );
      if (maxPrice != null && price > maxPrice) {
        return 'Мінімальна ціна не може бути більше максимальної';
      }
    } else {
      final minPrice = double.tryParse(
        _minPriceController.text.replaceAll(' ', ''),
      );
      if (minPrice != null && price < minPrice) {
        return 'Максимальна ціна не може бути менше мінімальної';
      }
    }

    return null;
  }

  // Метод для показу помилки через SnackBar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ErrorBanner(
          message: message,
          onClose: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Метод для валідації віку
  String? _validateAge(
    String? value,
    bool isMinAge, {
    bool isRequired = false,
  }) {
    if (value == null || value.isEmpty) {
      return isRequired
          ? 'Це поле є обов\'язковим'
          : null; // If field is required, return error
    }

    final age = int.tryParse(value);
    if (age == null) {
      return 'Введіть дійсне число';
    }

    if (age < 0) {
      return 'Вік не може бути від\'ємним';
    }

    // Get current values from controllers to validate against each other
    final minAgeVal = int.tryParse(_minAgeController.text);
    final maxAgeVal = int.tryParse(_maxAgeController.text);

    if (isMinAge) {
      if (maxAgeVal != null && age > maxAgeVal) {
        return 'Мінімальний вік не може бути більшим за максимальний';
      }
      if (age == maxAgeVal && maxAgeVal != null) {
        return 'Мінімальний та максимальний вік не можуть бути однаковими';
      }
    } else {
      // isMaxAge
      if (minAgeVal != null && age < minAgeVal) {
        return 'Максимальний вік не може бути меншим за мінімальний';
      }
      if (age == minAgeVal && minAgeVal != null) {
        return 'Мінімальний та максимальний вік не можуть бути однаковими';
      }
    }

    return null;
  }

  // Метод для валідації площі
  String? _validateArea(
    String? value,
    bool isMinArea, {
    bool isRequired = false,
  }) {
    if (value == null || value.isEmpty) {
      return isRequired
          ? 'Це поле є обов\'язковим'
          : null; // If field is required, return error
    }

    final area = double.tryParse(value);
    if (area == null) {
      return 'Введіть дійсне число';
    }

    if (area < 0) {
      return 'Площа не може бути від\'ємною';
    }

    // Get current values from controllers to validate against each other
    final minAreaVal = double.tryParse(_minAreaController.text);
    final maxAreaVal = double.tryParse(_maxAreaController.text);

    if (isMinArea) {
      if (maxAreaVal != null && area > maxAreaVal) {
        return 'Мінімальна площа не може бути більшою за максимальну';
      }
      if (area == maxAreaVal && maxAreaVal != null) {
        return 'Мінімальна та максимальна площа не можуть бути однаковими';
      }
    } else {
      // isMaxArea
      if (minAreaVal != null && area < minAreaVal) {
        return 'Максимальна площа не може бути меншою за мінімальну';
      }
      if (area == minAreaVal && minAreaVal != null) {
        return 'Мінімальна та максимальна площа не можуть бути однаковими';
      }
    }

    return null;
  }

  Widget _buildAdditionalFilters() {
    // Фільтри для нерухомості
    if (_selectedCategory?.name == 'Нерухомість' ||
        _selectedSubcategory!.name.contains('Квартири') ||
        _selectedSubcategory!.name.contains('Кімнати') ||
        _selectedSubcategory!.name.contains('Будинки') ||
        _selectedSubcategory!.name.contains('Земля') ||
        _selectedSubcategory!.name.contains('Комерційна нерухомість') ||
        _selectedSubcategory!.name.contains('Гаражі') ||
        _selectedSubcategory!.name.contains('парковки') ||
        _selectedSubcategory!.name.contains('Нерухомість за кордоном') ||
        _selectedSubcategory!.id == 'apartments' ||
        _selectedSubcategory!.id == 'rooms' ||
        _selectedSubcategory!.id == 'houses' ||
        _selectedSubcategory!.id == 'commercial' ||
        _selectedSubcategory!.id == 'garages' ||
        _selectedSubcategory!.id == 'foreign' ||
        _selectedSubcategory!.id == 'houses_daily' ||
        _selectedSubcategory!.id == 'apartments_daily' ||
        _selectedSubcategory!.id == 'rooms_daily') {
      return _buildRealEstateFilters();
    }

    // Фільтри для житла подобово
    if (_selectedCategory?.name == 'Житло подобово' ||
        _selectedSubcategory!.name.contains('Будинки подобово') ||
        _selectedSubcategory!.name.contains('Квартири подобово') ||
        _selectedSubcategory!.name.contains('Кімнати подобово') ||
        _selectedSubcategory!.name.contains('Готелі') ||
        _selectedSubcategory!.name.contains('бази відпочинку') ||
        _selectedSubcategory!.name.contains('Хостели') ||
        _selectedSubcategory!.name.contains('койко-місця') ||
        _selectedSubcategory!.name.contains('Пропозиції Туроператорів') ||
        _selectedSubcategory!.id == 'houses_daily' ||
        _selectedSubcategory!.id == 'apartments_daily' ||
        _selectedSubcategory!.id == 'rooms_daily') {
      return _buildDailyAccommodationFilters();
    }

    // Фільтри для авто - оновлені назви з вашого списку
    if (_selectedCategory?.name == 'Авто' ||
        _selectedSubcategory!.name.contains('Легкові автомобілі') ||
        _selectedSubcategory!.name.contains('Вантажні автомобілі') ||
        _selectedSubcategory!.name.contains('Автобуси') ||
        _selectedSubcategory!.name.contains('Мото') ||
        _selectedSubcategory!.name.contains('Спецтехніка') ||
        _selectedSubcategory!.name.contains('Сільгосптехніка') ||
        _selectedSubcategory!.name.contains('Водний транспорт') ||
        _selectedSubcategory!.name.contains('Автомобілі з Польщі') ||
        _selectedSubcategory!.name.contains('Причепи') ||
        _selectedSubcategory!.name.contains('будинки на колесах') ||
        _selectedSubcategory!.name.contains(
          'Вантажівки та спецтехніка з Польщі',
        ) ||
        _selectedSubcategory!.name.contains('Інший транспорт') ||
        _selectedSubcategory!.id == 'cars' ||
        _selectedSubcategory!.id == 'trucks' ||
        _selectedSubcategory!.id == 'buses' ||
        _selectedSubcategory!.id == 'moto' ||
        _selectedSubcategory!.id == 'special_equipment' ||
        _selectedSubcategory!.id == 'agricultural' ||
        _selectedSubcategory!.id == 'water_transport' ||
        _selectedSubcategory!.id == 'cars_poland' ||
        _selectedSubcategory!.id == 'trailers' ||
        _selectedSubcategory!.id == 'trucks_poland' ||
        _selectedSubcategory!.id == 'other_transport') {
      return _buildVehicleFilters();
    }

    // Фільтри для моди
    if (_selectedCategory?.name == 'Одяг та аксесуари' ||
        _selectedSubcategory!.name.contains('Жіночий одяг') ||
        _selectedSubcategory!.name.contains('Чоловічий одяг') ||
        _selectedSubcategory!.name.contains('Жіноче взуття') ||
        _selectedSubcategory!.name.contains('Чоловіче взуття') ||
        _selectedSubcategory!.name.contains('Жіноча білизна') ||
        _selectedSubcategory!.name.contains('купальники') ||
        _selectedSubcategory!.name.contains('Чоловіча білизна') ||
        _selectedSubcategory!.name.contains('плавки') ||
        _selectedSubcategory!.name.contains('Одяг для вагітних') ||
        _selectedSubcategory!.name.contains('Спецодяг') ||
        _selectedSubcategory!.name.contains('Спецвзуття') ||
        _selectedSubcategory!.id == 'women_clothes' ||
        _selectedSubcategory!.id == 'men_clothes' ||
        _selectedSubcategory!.id == 'women_shoes' ||
        _selectedSubcategory!.id == 'men_shoes' ||
        _selectedSubcategory!.id == 'women_underwear' ||
        _selectedSubcategory!.id == 'men_underwear' ||
        _selectedSubcategory!.id == 'maternity_clothes' ||
        _selectedSubcategory!.id == 'work_clothes' ||
        _selectedSubcategory!.id == 'work_shoes') {
      return _buildFashionFilters();
    }

    // Фільтри для знайомств
    if (_selectedCategory?.name == 'Знайомства' ||
        _selectedSubcategory!.name.contains(
          'Чоловіки, які шукають знайомства',
        ) ||
        _selectedSubcategory!.name.contains('Жінки, які шукають знайомства') ||
        _selectedSubcategory!.id == 'women_dating' ||
        _selectedSubcategory!.id == 'men_dating') {
      return _buildDatingFilters();
    }

    // Фільтри для роботи
    if (_selectedCategory?.name == 'Робота') {
      return _buildJobFilters();
    }

    if (_selectedCategory?.name == 'Запчастини для транспорту' &&
        _selectedSubcategory?.name == 'Шини, диски і колеса') {
      return _buildTireFilters();
    }

    if (_selectedCategory?.name == 'Дитячий світ') {
      return _buildGenderTypeToggle();
    }

    return const SizedBox.shrink();
  }

  Widget _buildRealEstateFilters() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE4E4E7), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Тип угоди',
            style: TextStyle(
              color: const Color(0xFF09090B) /* Zinc-950 */,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              height: 1.40,
              letterSpacing: 0.14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _realEstateType = _realEstateType == 'sale' ? null : 'sale';
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _realEstateType == 'sale'
                            ? const Color(0xFF015873)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          'Продаж',
                          style: TextStyle(
                            color: _realEstateType == 'sale'
                                ? Colors.white
                                : const Color(0xFF71717A), // Zinc-500
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _realEstateType = _realEstateType == 'rent' ? null : 'rent';
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _realEstateType == 'rent'
                            ? const Color(0xFF015873)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          'Оренда',
                          style: TextStyle(
                            color: _realEstateType == 'rent'
                                ? Colors.white
                                : const Color(0xFF71717A), // Zinc-500
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Кількість м²',
            style: TextStyle(
              color: const Color(0xFF09090B) /* Zinc-950 */,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              height: 1.40,
              letterSpacing: 0.14,
            ),
          ),
          const SizedBox(height: 16),
          // Поля вводу площі
          Row(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: _minAreaError != null
                            ? Colors.red
                            : const Color(0xFFE4E4E7) /* Zinc-200 */,
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x0C101828),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _minAreaController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) =>
                          _debouncedAreaValidation(value, true),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0 м²',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.50,
                          letterSpacing: 0.16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                        letterSpacing: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 44,
                child: Center(
                  child: Text(
                    '-',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA) /* Zinc-400 */,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      height: 1.50,
                      letterSpacing: 0.16,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: _maxAreaError != null
                            ? Colors.red
                            : const Color(0xFFE4E4E7) /* Zinc-200 */,
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x0C101828),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _maxAreaController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) =>
                          _debouncedAreaValidation(value, false),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '200 м²',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.50,
                          letterSpacing: 0.16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                        letterSpacing: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleFilters() {
    // Перевіряємо, чи це легкові авто або авто з Польщі
    bool isCarOrCarPoland =
        _selectedSubcategory != null &&
        (_selectedSubcategory!.id == 'cars' ||
            _selectedSubcategory!.id == 'cars_poland' ||
            _selectedSubcategory!.name.contains('Легкові автомобілі') ||
            _selectedSubcategory!.name.contains('Автомобілі з Польщі'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Нові каскадні селектори для легкових авто та авто з Польщі
        if (isCarOrCarPoland) ...[
          _buildMakeSelector(),
          if (_selectedMake != null) ...[
            const SizedBox(height: 20),
            _buildModelSelector(),
          ],
          if (_selectedModel != null) ...[
            const SizedBox(height: 20),
            _buildStyleSelector(),
          ],
          const SizedBox(height: 20),
          _buildCarYearRangeSelector(),
          const SizedBox(height: 16),
        ],

        // Блок "Рік випуску" (показуємо тільки якщо НЕ легкові авто або авто з Польщі)
        if (!isCarOrCarPoland) ...[
          Text(
            'Рік випуску',
            style: TextStyle(
              color: const Color(0xFF09090B) /* Zinc-950 */,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              height: 1.40,
              letterSpacing: 0.14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: _minYearError != null
                            ? Colors.red
                            : const Color(0xFFE4E4E7),
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x0C101828),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _minCarYearController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) =>
                          _debouncedCarYearValidation(value, true),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '1999',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.50,
                          letterSpacing: 0.16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                        letterSpacing: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 44,
                child: Center(
                  child: Text(
                    '-',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA) /* Zinc-400 */,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      height: 1.50,
                      letterSpacing: 0.16,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: _maxYearError != null
                            ? Colors.red
                            : const Color(0xFFE4E4E7),
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x0C101828),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _maxCarYearController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) =>
                          _debouncedCarYearValidation(value, false),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '2022',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.50,
                          letterSpacing: 0.16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                        letterSpacing: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Блок "Пробіг, тис. км"
          Text(
            'Пробіг, тис. км',
            style: TextStyle(
              color: const Color(0xFF09090B) /* Zinc-950 */,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              height: 1.40,
              letterSpacing: 0.14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: _minMileageError != null
                            ? Colors.red
                            : const Color(0xFFE4E4E7),
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x0C101828),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _minMileageController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        _updateSliderFromTextFieldsForMileage(); // Оновлюємо слайдер
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0 тис. км',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.50,
                          letterSpacing: 0.16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                        letterSpacing: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 44,
                child: Center(
                  child: Text(
                    '-',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA) /* Zinc-400 */,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      height: 1.50,
                      letterSpacing: 0.16,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: _maxMileageError != null
                            ? Colors.red
                            : const Color(0xFFE4E4E7),
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x0C101828),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _maxMileageController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        _updateSliderFromTextFieldsForMileage(); // Оновлюємо слайдер
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '1000 тис. км',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.50,
                          letterSpacing: 0.16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                        letterSpacing: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        // Слайдер для пробігу
        const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildFashionFilters() {
    final sizes = _getSizesForSubcategory();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConditionTypeToggle(),
        if (sizes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSizeSelector(sizes),
        ],
      ],
    );
  }

  Widget _buildSizeSelector(List<String> sizes) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE4E4E7), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Розмір',
            style: TextStyle(
              color: const Color(0xFF09090B),
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sizes.map((size) {
              final isSelected = _selectedSize == size;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSize = isSelected ? null : size;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF015873) : Colors.white,
                    borderRadius: BorderRadius.circular(200),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF015873)
                          : const Color(0xFFE4E4E7),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    size,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF27272A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionTypeToggle() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE4E4E7), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Стан',
            style: TextStyle(
              color: const Color(0xFF09090B),
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _conditionType = _conditionType == 'new' ? null : 'new';
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _conditionType == 'new'
                            ? const Color(0xFF015873)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          'Новий',
                          style: TextStyle(
                            color: _conditionType == 'new'
                                ? Colors.white
                                : const Color(0xFF71717A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _conditionType = _conditionType == 'used' ? null : 'used';
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _conditionType == 'used'
                            ? const Color(0xFF015873)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          'Б/У',
                          style: TextStyle(
                            color: _conditionType == 'used'
                                ? Colors.white
                                : const Color(0xFF71717A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyAccommodationFilters() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE4E4E7), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Кількість м²',
            style: TextStyle(
              color: const Color(0xFF09090B) /* Zinc-950 */,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              height: 1.40,
              letterSpacing: 0.14,
            ),
          ),
          const SizedBox(height: 16),
          // Поля вводу площі
          Row(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: _minAreaError != null
                            ? Colors.red
                            : const Color(0xFFE4E4E7) /* Zinc-200 */,
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x0C101828),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _minAreaController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) =>
                          _debouncedAreaValidation(value, true),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0 м²',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.50,
                          letterSpacing: 0.16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                        letterSpacing: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 44,
                child: Center(
                  child: Text(
                    '-',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA) /* Zinc-400 */,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      height: 1.50,
                      letterSpacing: 0.16,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: _maxAreaError != null
                            ? Colors.red
                            : const Color(0xFFE4E4E7) /* Zinc-200 */,
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x0C101828),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _maxAreaController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) =>
                          _debouncedAreaValidation(value, false),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '200 м²',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.50,
                          letterSpacing: 0.16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                        letterSpacing: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatingFilters() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE4E4E7), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Вік',
            style: TextStyle(
              color: const Color(0xFF09090B) /* Zinc-950 */,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              height: 1.40,
              letterSpacing: 0.14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: _minAgeError != null
                            ? Colors.red
                            : const Color(0xFFE4E4E7) /* Zinc-200 */,
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x0C101828),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _minAgeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) =>
                          _debouncedAgeValidation(value, true),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '18',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.50,
                          letterSpacing: 0.16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                        letterSpacing: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 44,
                child: Center(
                  child: Text(
                    '-',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA) /* Zinc-400 */,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      height: 1.50,
                      letterSpacing: 0.16,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: _maxAgeError != null
                            ? Colors.red
                            : const Color(0xFFE4E4E7) /* Zinc-200 */,
                      ),
                      borderRadius: BorderRadius.circular(200),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x0C101828),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _maxAgeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) =>
                          _debouncedAgeValidation(value, false),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '65',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.50,
                          letterSpacing: 0.16,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                        letterSpacing: 0.16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Метод для валідації року випуску
  String? _validateYear(
    String? value,
    bool isMinYear, {
    bool isRequired = false,
  }) {
    if (value == null || value.isEmpty) {
      return isRequired
          ? 'Це поле є обов\'язковим'
          : null; // If field is required, return error
    }

    final year = int.tryParse(value);
    if (year == null) {
      return 'Введіть дійсне число';
    }

    // Assume valid year range, e.g., 1900 to current year + 1
    final currentYear = DateTime.now().year;
    if (year < 1900 || year > currentYear + 1) {
      return 'Введіть рік між 1900 та ${currentYear + 1}';
    }

    // Перевіряємо порівняння тільки якщо обидва поля заповнені
    final minYearVal = _minCarYearController.text.isNotEmpty
        ? int.tryParse(_minCarYearController.text)
        : null;
    final maxYearVal = _maxCarYearController.text.isNotEmpty
        ? int.tryParse(_maxCarYearController.text)
        : null;

    if (isMinYear) {
      // Перевіряємо тільки якщо поле "до" заповнене
      if (maxYearVal != null && year > maxYearVal) {
        return 'Мінімальний рік не може бути більшим за максимальний';
      }
      if (maxYearVal != null && year == maxYearVal) {
        return 'Мінімальний та максимальний рік не можуть бути однаковими';
      }
    } else {
      // isMaxYear
      // Перевіряємо тільки якщо поле "від" заповнене
      if (minYearVal != null && year < minYearVal) {
        return 'Максимальний рік не може бути меншим за мінімальний';
      }
      if (minYearVal != null && year == minYearVal) {
        return 'Мінімальний та максимальний рік не можуть бути однаковими';
      }
    }

    return null;
  }

  // Метод для оновлення слайдера пробігу на основі текстових полів
  void _updateSliderFromTextFieldsForMileage() {
    final minMileageText = _minMileageController.text;
    final maxMileageText = _maxMileageController.text;

    final double minMileage =
        double.tryParse(minMileageText) ?? _minAvailableMileage;
    final double maxMileage =
        double.tryParse(maxMileageText) ?? _maxAvailableMileage;

    setState(() {
      _currentMinMileage = minMileage.clamp(
        _minAvailableMileage,
        _maxAvailableMileage,
      );
      _currentMaxMileage = maxMileage.clamp(
        _minAvailableMileage,
        _maxAvailableMileage,
      );

      if (_currentMinMileage > _currentMaxMileage) {
        final temp = _currentMinMileage;
        _currentMinMileage = _currentMaxMileage;
        _currentMaxMileage = temp;
      }
    });
  }

  // Метод для оновлення значень слайдера пробігу
  void _updateMileageSliderValues(double minValue, double maxValue) {
    setState(() {
      _currentMinMileage = minValue.clamp(
        _minAvailableMileage,
        _maxAvailableMileage,
      );
      _currentMaxMileage = maxValue.clamp(
        _minAvailableMileage,
        _maxAvailableMileage,
      );
      _minMileageController.text = _currentMinMileage.toStringAsFixed(0);
      _maxMileageController.text = _currentMaxMileage.toStringAsFixed(0);
    });
  }

  bool _isFormValid() {
    // Check general price validation if price mode is active
    if (_isPriceModePrice &&
        (_minPriceError != null || _maxPriceError != null)) {
      return false;
    }

    // Check additional filters validation based on selected subcategory
    if (_selectedSubcategory != null) {
      final extraFields = getExtraFieldsForSubcategory(
        _selectedSubcategory!.id,
      );

      if (extraFields != null) {
        // Check for area fields if present
        if (extraFields['area'] != null) {
          if (_minAreaError != null || _maxAreaError != null) return false;
          if (_validateArea(_minAreaController.text, true, isRequired: true) !=
              null)
            return false;
          if (_validateArea(_maxAreaController.text, false, isRequired: true) !=
              null)
            return false;
        }
        // Check for year fields if present
        if (extraFields['year'] != null || _selectedCategory?.name == 'Авто') {
          if (_minYearError != null || _maxYearError != null) return false;
          if (_validateYear(_minYearController.text, true, isRequired: true) !=
              null)
            return false;
          if (_validateYear(_maxYearController.text, false, isRequired: true) !=
              null)
            return false;
        }
        // Check for mileage fields if present
        if (_selectedCategory?.name == 'Авто') {
          // Mileage validation can be added here if needed
        }
        // Check for age fields if present
        if (extraFields['age'] != null) {
          if (_minAgeError != null || _maxAgeError != null) return false;
          if (_validateAge(_minAgeController.text, true, isRequired: true) !=
              null)
            return false;
          if (_validateAge(_maxAgeController.text, false, isRequired: true) !=
              null)
            return false;
        }
      }
    }

    // If no errors, form is valid
    return true;
  }

  Future<Map<String, double>> _getMileageRangeFromDatabase() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('listings')
          .select('mileage_thousands_km')
          .not(
            'mileage_thousands_km',
            'is',
            null,
          ); // Фільтруємо записи, де пробіг не null

      if (response != null && response.isNotEmpty) {
        final mileages = response
            .map((item) => (item['mileage_thousands_km'] as num?)?.toDouble())
            .where((mileage) => mileage != null)
            .cast<double>()
            .toList();

        if (mileages.isNotEmpty) {
          mileages.sort();
          final minMileage = mileages.first;
          final maxMileage = mileages.last;

          return {'min': minMileage, 'max': maxMileage};
        }
      }

      return {'min': 0.0, 'max': 1000.0};
    } catch (e) {
      print('Error loading mileage range: $e');
      return {'min': 0.0, 'max': 1000.0};
    }
  }

  Future<void> _loadMileageRange() async {
    try {
      final mileageRange = await _getMileageRangeFromDatabase();
      setState(() {
        _minAvailableMileage = mileageRange['min'] ?? 0.0;
        _maxAvailableMileage = mileageRange['max'] ?? 1000.0;

        // Переконуємося, що мінімальне значення менше максимального
        if (_minAvailableMileage >= _maxAvailableMileage) {
          _minAvailableMileage = 0.0;
          _maxAvailableMileage = 1000.0;
        }

        _currentMinMileage = _minAvailableMileage;
        _currentMaxMileage = _maxAvailableMileage;

        // _minMileageController.text = _minAvailableMileage.toStringAsFixed(0);
        // _maxMileageController.text = _maxAvailableMileage.toStringAsFixed(0);
      });
    } catch (e) {
      print('Error setting initial mileage: $e');
    }
  }

  Widget _buildGiveawayTypeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Тип розміщення',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _giveawayType = 'giving');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _giveawayType == 'giving'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Віддам',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _giveawayType == 'giving'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _giveawayType = 'taking');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _giveawayType == 'taking'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Прийму',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _giveawayType == 'taking'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onCategorySelected(Category category, {Subcategory? subcategory}) {
    setState(() {
    if (_selectedCategory?.id == category.id) {
      // Якщо та сама категорія, скидаємо її
      _selectedCategory = null;
      _selectedSubcategory = null;
      _selectedSize = null;
      _selectedMake = null;
      _selectedModel = null;
      _selectedStyle = null;
      _selectedModelYear = null;
      _makes.clear();
      _models.clear();
      _styles.clear();
      _modelYears.clear();
    } else {
        _selectedCategory = category;
        _selectedSubcategory =
            subcategory; // Скидаємо підкатегорію при зміні категорії
        // Очищаємо залежні фільтри, якщо потрібно
        _selectedSize = null;
        // Очищаємо нові фільтри авто при зміні категорії
        _selectedMake = null;
        _selectedModel = null;
        _selectedStyle = null;
        _selectedModelYear = null;
        _makes.clear();
        _models.clear();
        _styles.clear();
        _modelYears.clear();
      }

      if (subcategory != null) {
        _selectedSubcategory = subcategory;
        // Завантажуємо марки, якщо обрана підкатегорія "Легкові автомобілі" або "Автомобілі з Польщі"
        if (subcategory.name == 'Легкові автомобілі' ||
            subcategory.name == 'Автомобілі з Польщі') {
          _loadMakes().then((_) {
            _initializeCarFiltersFromInitialFilters();
          });
        }
      }

      // Логіка для автоматичного вибору типу для деяких категорій
      if (category.name == 'Нерухомість' || category.name == 'Житло подобово') {
        _realEstateType = 'sale';
      }

      _minPriceController.clear();
      _maxPriceController.clear();
      _minMileageController.clear();
      _maxMileageController.clear();
      _selectedSize = null;
      _jobType = 'offering';
      _helpType = 'offering';
      _giveawayType = 'giving'; // Reset to default when category changes
      _conditionType = 'new';
      _genderType = 'both';
      _radiusRController.clear();
    });
  }

  void _onSubcategorySelected(Subcategory subcategory) {
    setState(() {
      _selectedSubcategory = subcategory;
      _minPriceController.clear();
      _maxPriceController.clear();
      _minMileageController.clear();
      _maxMileageController.clear();
      _selectedSize = null;
      _realEstateType = 'sale';
      _jobType = 'offering';
      _helpType = 'offering';
      _giveawayType = 'giving'; // Reset to default when subcategory changes
      _conditionType = 'new';
      _genderType = 'both';

      // Очищаємо нові фільтри авто при зміні підкатегорії
      _selectedMake = null;
      _selectedModel = null;
      _selectedStyle = null;
      _selectedModelYear = null;
      _makes.clear();
      _models.clear();
      _styles.clear();
      _modelYears.clear();
    });

    // Завантажуємо марки, якщо обрана підкатегорія "Легкові автомобілі" або "Автомобілі з Польщі"
    if (subcategory.name == 'Легкові автомобілі' ||
        subcategory.name == 'Автомобілі з Польщі') {
      _loadMakes().then((_) {
        // Після завантаження makes, якщо є initialFilters, ініціалізуємо вибрані значення
        _initializeCarFiltersFromInitialFilters();
      });
    }
  }

  // Метод для каскадної ініціалізації фільтрів авто з initialFilters
  Future<void> _initializeCarFiltersFromInitialFilters() async {
    if (widget.initialFilters.isEmpty) return;

    final makeId = widget.initialFilters['make_id'] as String?;
    final modelId = widget.initialFilters['model_id'] as String?;
    final styleId = widget.initialFilters['style_id'] as String?;
    final minCarYear = widget.initialFilters['minCarYear'];
    final maxCarYear = widget.initialFilters['maxCarYear'];

    if (minCarYear != null) {
      _minCarYearController.text = minCarYear.toString();
    }
    if (maxCarYear != null) {
      _maxCarYearController.text = maxCarYear.toString();
    }

    if (makeId != null && _makes.isNotEmpty) {
      try {
        final make = _makes.firstWhere((m) => m.id == makeId);
        setState(() {
          _selectedMake = make;
        });
        await _loadModels(makeId, resetSelection: false);
        if (modelId != null && _models.isNotEmpty) {
          try {
            final model = _models.firstWhere((m) => m.id == modelId);
            setState(() {
              _selectedModel = model;
            });
            await _loadStyles(modelId, resetSelection: false);
            if (styleId != null && _styles.isNotEmpty) {
              try {
                final style = _styles.firstWhere((s) => s.id == styleId);
                setState(() {
                  _selectedStyle = style;
                });
              } catch (_) {}
            }
          } catch (_) {}
        }
      } catch (_) {}
    }
  }

  Widget _buildJobFilters() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE4E4E7), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Тип оголошення',
            style: TextStyle(
              color: const Color(0xFF09090B),
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _jobType = _jobType == 'offering' ? null : 'offering';
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _jobType == 'offering'
                            ? const Color(0xFF015873)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          'Пропоную',
                          style: TextStyle(
                            color: _jobType == 'offering'
                                ? Colors.white
                                : const Color(0xFF71717A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _jobType = _jobType == 'seeking' ? null : 'seeking';
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _jobType == 'seeking'
                            ? const Color(0xFF015873)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          'Шукаю',
                          style: TextStyle(
                            color: _jobType == 'seeking'
                                ? Colors.white
                                : const Color(0xFF71717A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getSizesForSubcategory() {
    if (_selectedSubcategory == null) return [];

    switch (_selectedSubcategory!.name) {
      case 'Жіночий одяг':
        return ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
      case 'Жіноче взуття':
        return ['34', '35', '36', '37', '38', '39', '40', '41', '42'];
      case 'Чоловічий одяг':
        return ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
      case 'Чоловіче взуття':
        return ['39', '40', '41', '42', '43', '44', '45', '46', '47'];
      case 'Жіноча білизна та купальники':
        return ['XS', 'S', 'M', 'L', 'XL'];
      case 'Чоловіча білизна та плавки':
        return ['S', 'M', 'L', 'XL', 'XXL'];
      case 'Одяг для вагітних':
        return ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
      case 'Спецодяг':
        return ['S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
      case 'Спецвзуття та аксесуари':
        return [
          '38',
          '39',
          '40',
          '41',
          '42',
          '43',
          '44',
          '45',
          '46',
          '47',
          '48',
        ];
      default:
        return [];
    }
  }

  Widget _buildTireFilters() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE4E4E7), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Радіус (R)',
            style: TextStyle(
              color: const Color(0xFF09090B),
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: ShapeDecoration(
              color: const Color(0xFFFAFAFA),
              shape: RoundedRectangleBorder(
                side: BorderSide(width: 1, color: const Color(0xFFE4E4E7)),
                borderRadius: BorderRadius.circular(200),
              ),
            ),
            child: TextField(
              controller: _radiusRController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Введіть радіус',
                hintStyle: TextStyle(color: Color(0xFFA1A1AA)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderTypeToggle() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE4E4E7), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Стать',
            style: TextStyle(
              color: const Color(0xFF09090B),
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
            ),
            child: Row(
              children: [
                _buildGenderOption('boy', 'Хлопчик'),
                _buildGenderOption('girl', 'Дівчинка'),
                _buildGenderOption('both', 'Обидва'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderOption(String value, String text) {
    final isSelected = _genderType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _genderType = value;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF015873) : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF71717A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isTapInsideCarDropdown(Offset globalPosition) {
    bool check(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return false;
      final topLeft = box.localToGlobal(Offset.zero);
      return Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        box.size.width,
        box.size.height,
      ).contains(globalPosition);
    }

    if (_isMakeOpen && check(_makeSelectorKey)) return true;
    if (_isModelOpen && check(_modelSelectorKey)) return true;
    if (_isStyleOpen && check(_styleSelectorKey)) return true;
    return false;
  }

  List<Make> get _filteredMakes {
    final q = _makeSearchController.text.toLowerCase().trim();
    if (q.isEmpty) return _makes;
    return _makes.where((m) => m.name.toLowerCase().contains(q)).toList();
  }

  List<Model> get _filteredModels {
    final q = _modelSearchController.text.toLowerCase().trim();
    if (q.isEmpty) return _models;
    return _models.where((m) => m.name.toLowerCase().contains(q)).toList();
  }

  List<Style> get _filteredStyles {
    final q = _styleSearchController.text.toLowerCase().trim();
    if (q.isEmpty) return _styles;
    return _styles.where((s) => s.styleName.toLowerCase().contains(q)).toList();
  }

  Widget _buildMakeSelector() {
    return Column(
      key: _makeSelectorKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Марка',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _makeKey,
          onTap: () {
            setState(() {
              _isMakeOpen = !_isMakeOpen;
              _isModelOpen = false;
              _isStyleOpen = false;
              _isModelYearOpen = false;
            });
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(color: AppColors.zinc200, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.05),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedMake?.name ?? 'Оберіть марку',
                    style: AppTextStyles.body1Regular.copyWith(
                      color: _selectedMake != null
                          ? AppColors.color2
                          : AppColors.color5,
                    ),
                  ),
                ),
                if (_isLoadingMakes)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  SvgPicture.asset(
                    'assets/icons/chevron_down.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      AppColors.color7,
                      BlendMode.srcIn,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isMakeOpen)
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.zinc200),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.03),
                  offset: Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _makeSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Пошук...',
                      hintStyle: AppTextStyles.body2Regular.copyWith(
                        color: AppColors.color5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.color5,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.zinc200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.zinc200),
                      ),
                    ),
                    style: AppTextStyles.body2Regular,
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: _filteredMakes.length,
                    itemBuilder: (context, index) {
                      final make = _filteredMakes[index];
                      return _buildMakeItem(make);
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMakeItem(Make make) {
    final isSelected = _selectedMake?.id == make.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMake = make;
            _selectedModel = null;
            _selectedStyle = null;
            _selectedModelYear = null;
            _isMakeOpen = false;
            _makeSearchController.clear();
            _models.clear();
            _styles.clear();
            _modelYears.clear();
          });
          _loadModels(make.id);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.zinc50 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  make.name,
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                SvgPicture.asset(
                  'assets/icons/check.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    AppColors.primaryColor,
                    BlendMode.srcIn,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelSelector() {
    return Column(
      key: _modelSelectorKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Модель',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _modelKey,
          onTap: () {
            setState(() {
              _isModelOpen = !_isModelOpen;
              _isStyleOpen = false;
              _isModelYearOpen = false;
            });
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(color: AppColors.zinc200, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.05),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedModel?.name ?? 'Оберіть модель',
                    style: AppTextStyles.body1Regular.copyWith(
                      color: _selectedModel != null
                          ? AppColors.color2
                          : AppColors.color5,
                    ),
                  ),
                ),
                if (_isLoadingModels)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  SvgPicture.asset(
                    'assets/icons/chevron_down.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      AppColors.color7,
                      BlendMode.srcIn,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isModelOpen)
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.zinc200),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.03),
                  offset: Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _modelSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Пошук...',
                      hintStyle: AppTextStyles.body2Regular.copyWith(
                        color: AppColors.color5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.color5,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.zinc200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.zinc200),
                      ),
                    ),
                    style: AppTextStyles.body2Regular,
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount:
                        _filteredModels.length +
                        (_selectedModel != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_selectedModel != null && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedModel = null;
                                _selectedStyle = null;
                                _selectedModelYear = null;
                                _isModelOpen = false;
                                _styles.clear();
                                _modelYears.clear();
                                _modelSearchController.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.clear,
                                    size: 18,
                                    color: AppColors.color5,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Очистити',
                                    style: AppTextStyles.body2Regular.copyWith(
                                      color: AppColors.color5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      final model =
                          _filteredModels[_selectedModel != null
                              ? index - 1
                              : index];
                      return _buildModelItem(model);
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildModelItem(Model model) {
    final isSelected = _selectedModel?.id == model.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedModel = model;
            _selectedStyle = null;
            _selectedModelYear = null;
            _isModelOpen = false;
            _modelSearchController.clear();
            _styles.clear();
            _modelYears.clear();
          });
          _loadStyles(model.id);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.zinc50 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  model.name,
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                SvgPicture.asset(
                  'assets/icons/check.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    AppColors.primaryColor,
                    BlendMode.srcIn,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyleSelector() {
    return Column(
      key: _styleSelectorKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Підмодель / Стиль',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _styleKey,
          onTap: () {
            setState(() {
              _isStyleOpen = !_isStyleOpen;
              _isModelYearOpen = false;
            });
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(color: AppColors.zinc200, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.05),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedStyle != null
                        ? '${_selectedStyle!.styleName}${_selectedStyle!.fuelType != null ? ' (${_selectedStyle!.fuelType})' : ''}'
                        : 'Оберіть стиль',
                    style: AppTextStyles.body1Regular.copyWith(
                      color: _selectedStyle != null
                          ? AppColors.color2
                          : AppColors.color5,
                    ),
                  ),
                ),
                if (_isLoadingStyles)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  SvgPicture.asset(
                    'assets/icons/chevron_down.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      AppColors.color7,
                      BlendMode.srcIn,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isStyleOpen)
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.zinc200),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.03),
                  offset: Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _styleSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Пошук...',
                      hintStyle: AppTextStyles.body2Regular.copyWith(
                        color: AppColors.color5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.color5,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.zinc200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.zinc200),
                      ),
                    ),
                    style: AppTextStyles.body2Regular,
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount:
                        _filteredStyles.length +
                        (_selectedStyle != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_selectedStyle != null && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedStyle = null;
                                _selectedModelYear = null;
                                _isStyleOpen = false;
                                _modelYears.clear();
                                _styleSearchController.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.clear,
                                    size: 18,
                                    color: AppColors.color5,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Очистити',
                                    style: AppTextStyles.body2Regular.copyWith(
                                      color: AppColors.color5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      final style =
                          _filteredStyles[_selectedStyle != null
                              ? index - 1
                              : index];
                      return _buildStyleItem(style);
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStyleItem(Style style) {
    final isSelected = _selectedStyle?.id == style.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStyle = style;
            _selectedModelYear = null;
            _isStyleOpen = false;
            _styleSearchController.clear();
            _modelYears.clear();
          });
          _loadModelYears(style.id);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.zinc50 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${style.styleName}${style.fuelType != null ? ' (${style.fuelType})' : ''}',
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                SvgPicture.asset(
                  'assets/icons/check.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    AppColors.primaryColor,
                    BlendMode.srcIn,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelYearSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Рік випуску (необов\'язково)',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _modelYearKey,
          onTap: () {
            setState(() {
              _isModelYearOpen = !_isModelYearOpen;
            });
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(color: AppColors.zinc200, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.05),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedModelYear != null
                        ? _selectedModelYear!.year.toString()
                        : 'Оберіть рік',
                    style: AppTextStyles.body1Regular.copyWith(
                      color: _selectedModelYear != null
                          ? AppColors.color2
                          : AppColors.color5,
                    ),
                  ),
                ),
                if (_isLoadingModelYears)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  SvgPicture.asset(
                    'assets/icons/chevron_down.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      AppColors.color7,
                      BlendMode.srcIn,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isModelYearOpen)
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.zinc200),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.03),
                  offset: Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount:
                  _modelYears.length + (_selectedModelYear != null ? 1 : 0),
              itemBuilder: (context, index) {
                // Якщо є вибраний рік, перший елемент - це опція "Очистити"
                if (_selectedModelYear != null && index == 0) {
                  return _buildClearModelYearItem();
                }
                // Індекс для списку років (з урахуванням опції "Очистити")
                final yearIndex = _selectedModelYear != null
                    ? index - 1
                    : index;
                final modelYear = _modelYears[yearIndex];
                return _buildModelYearItem(modelYear);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildClearModelYearItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedModelYear = null;
            _isModelYearOpen = false;
          });
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Не вибрано',
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelYearItem(ModelYear modelYear) {
    final isSelected = _selectedModelYear?.id == modelYear.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedModelYear = modelYear;
            _isModelYearOpen = false;
          });
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.zinc50 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  modelYear.year.toString(),
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                SvgPicture.asset(
                  'assets/icons/check.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    AppColors.primaryColor,
                    BlendMode.srcIn,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Метод для побудови полів "від-до" для року випуску (коли Style не обрано)
  Widget _buildCarYearRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Рік випуску',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: ShapeDecoration(
                  color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 1,
                      color: _minYearError != null
                          ? Colors.red
                          : const Color(0xFFE4E4E7),
                    ),
                    borderRadius: BorderRadius.circular(200),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Color(0x0C101828),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: TextField(
                    controller: _minCarYearController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (value) => _debouncedYearValidation(
                      value,
                      true,
                      isRequired: false,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '1999',
                      hintStyle: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                        letterSpacing: 0.16,
                      ),
                    ),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      height: 1.50,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 8,
              height: 44,
              child: Center(
                child: Text(
                  '-',
                  style: TextStyle(
                    color: Color(0xFFA1A1AA) /* Zinc-400 */,
                    fontSize: 16,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    height: 1.50,
                    letterSpacing: 0.16,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: ShapeDecoration(
                  color: const Color(0xFFFAFAFA) /* Zinc-50 */,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 1,
                      color: _maxYearError != null
                          ? Colors.red
                          : const Color(0xFFE4E4E7),
                    ),
                    borderRadius: BorderRadius.circular(200),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Color(0x0C101828),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: TextField(
                    controller: _maxCarYearController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (value) => _debouncedYearValidation(
                      value,
                      false,
                      isRequired: false,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '2022',
                      hintStyle: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                        letterSpacing: 0.16,
                      ),
                    ),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      height: 1.50,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
