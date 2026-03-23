# План додавання нових фільтрів для підкатегорій "Легкові авто" та "Авто із Польщі"

## Огляд

На сторінці створення оголошення (`add_listing_page.dart`) вже реалізовані 4 нові фільтри для автомобілів:
1. **Make (Марка)** - `make_id`
2. **Model (Модель)** - `model_id`
3. **Style (Стиль)** - `style_id`
4. **ModelYear (Рік моделі)** - `model_year_id`

Ці фільтри зберігаються в базі даних через `listing_service.dart` і використовують `CarService` для завантаження даних.

## Поточний стан

### Що вже є:
- ✅ `CarService` з методами: `getMakes()`, `getModels(makeId)`, `getStyles(modelId)`, `getModelYears(styleId)`
- ✅ UI компоненти в `add_listing_page.dart` для вибору цих фільтрів
- ✅ Збереження в БД через `listing_service.dart` (поля: `make_id`, `model_id`, `style_id`, `model_year_id`)

### Що потрібно додати:
- ❌ UI компоненти в `filter_page.dart` для вибору цих фільтрів
- ❌ Параметри фільтрації в `product_service.dart`
- ❌ Логіка фільтрації в `_applyFilters` в `product_service.dart`
- ❌ Передача фільтрів з `home_page.dart` до `product_service.dart`
- ❌ Збереження фільтрів в `filter_manager.dart`

## Детальний план реалізації

### 1. Оновлення `filter_page.dart`

#### 1.1. Додати імпорти та змінні стану
```dart
import '../services/car_service.dart'; // Додати імпорт

// Додати змінні стану:
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
```

#### 1.2. Ініціалізація фільтрів з `initialFilters`
В методі `_initializeFilters()` додати:
```dart
// Завантажити вибрані значення з initialFilters
if (widget.initialFilters['make_id'] != null) {
  // Завантажити make та каскадно завантажити model, style, modelYear
  _loadMakes();
  // Після завантаження знайти та встановити _selectedMake
}
```

#### 1.3. Додати методи завантаження даних
```dart
Future<void> _loadMakes() async {
  // Перевірити, чи обрана підкатегорія "Легкові автомобілі" або "Автомобілі з Польщі"
  // Завантажити марки через _carService.getMakes()
}

Future<void> _loadModels(String makeId) async {
  // Завантажити моделі через _carService.getModels(makeId)
  // Скинути _selectedModel, _selectedStyle, _selectedModelYear
}

Future<void> _loadStyles(String modelId) async {
  // Завантажити стилі через _carService.getStyles(modelId)
  // Скинути _selectedStyle, _selectedModelYear
}

Future<void> _loadModelYears(String styleId) async {
  // Завантажити роки через _carService.getModelYears(styleId)
  // Скинути _selectedModelYear
}
```

#### 1.4. Додати UI компоненти
В методі `_buildVehicleFilters()` замінити або додати до існуючого `_showCarBrandSelection` нові селектори:
- `_buildMakeSelector()` - аналогічно до `add_listing_page.dart`
- `_buildModelSelector()` - показується тільки якщо обрано Make
- `_buildStyleSelector()` - показується тільки якщо обрано Model
- `_buildModelYearSelector()` - показується тільки якщо обрано Style

#### 1.5. Оновити метод `_applyFilters()`
Додати до `Map<String, dynamic> filters`:
```dart
if (_selectedMake != null) {
  filters['make_id'] = _selectedMake!.id;
}
if (_selectedModel != null) {
  filters['model_id'] = _selectedModel!.id;
}
if (_selectedStyle != null) {
  filters['style_id'] = _selectedStyle!.id;
}
if (_selectedModelYear != null) {
  filters['model_year_id'] = _selectedModelYear!.id;
}
```

### 2. Оновлення `product_service.dart`

#### 2.1. Додати параметри до методу `getProducts()`
```dart
Future<List<Product>> getProducts({
  // ... існуючі параметри ...
  String? makeId,
  String? modelId,
  String? styleId,
  String? modelYearId,
}) async {
```

#### 2.2. Передати параметри до `_applyFilters()`
```dart
query = _applyFilters(query, 
  // ... існуючі параметри ...
  makeId: makeId,
  modelId: modelId,
  styleId: styleId,
  modelYearId: modelYearId,
);
```

#### 2.3. Додати логіку фільтрації в `_applyFilters()`
```dart
PostgrestFilterBuilder _applyFilters(PostgrestFilterBuilder query, {
  // ... існуючі параметри ...
  String? makeId,
  String? modelId,
  String? styleId,
  String? modelYearId,
}) {
  // ... існуюча логіка ...
  
  // Фільтр за маркою
  if (makeId != null && makeId.isNotEmpty) {
    query = query.eq('make_id', makeId);
  }
  
  // Фільтр за моделлю
  if (modelId != null && modelId.isNotEmpty) {
    query = query.eq('model_id', modelId);
  }
  
  // Фільтр за стилем
  if (styleId != null && styleId.isNotEmpty) {
    query = query.eq('style_id', styleId);
  }
  
  // Фільтр за роком моделі
  if (modelYearId != null && modelYearId.isNotEmpty) {
    query = query.eq('model_year_id', modelYearId);
  }
  
  return query;
}
```

### 3. Оновлення `home_page.dart`

#### 3.1. Передати нові фільтри до `getProducts()`
В методі `_loadProducts()` додати:
```dart
fetchedProducts = await _productService.getProducts(
  // ... існуючі параметри ...
  makeId: currentFilters['make_id'],
  modelId: currentFilters['model_id'],
  styleId: currentFilters['style_id'],
  modelYearId: currentFilters['model_year_id'],
);
```

### 4. Оновлення `filter_manager.dart`

#### 4.1. Додати підрахунок нових фільтрів
В методі `getActiveFiltersCount()` додати:
```dart
// Make filter
if (_currentFilters.containsKey('make_id') && _currentFilters['make_id'] != null) {
  count++;
}

// Model filter
if (_currentFilters.containsKey('model_id') && _currentFilters['model_id'] != null) {
  count++;
}

// Style filter
if (_currentFilters.containsKey('style_id') && _currentFilters['style_id'] != null) {
  count++;
}

// ModelYear filter
if (_currentFilters.containsKey('model_year_id') && _currentFilters['model_year_id'] != null) {
  count++;
}
```

## Важливі моменти

1. **Каскадний вибір**: При зміні Make скидаються Model, Style, ModelYear. При зміні Model скидаються Style, ModelYear. При зміні Style скидається ModelYear.

2. **Умовне відображення**: Фільтри показуються тільки для підкатегорій "Легкові автомобілі" (`cars`) та "Автомобілі з Польщі" (`cars_poland`).

3. **Ініціалізація**: При відкритті сторінки фільтрів з вже вибраними значеннями потрібно каскадно завантажити всі залежні дані (Make -> Model -> Style -> ModelYear).

4. **Очищення**: При скиданні фільтрів або зміні підкатегорії потрібно очистити всі вибрані значення.

## Порядок виконання

1. Спочатку додати UI компоненти в `filter_page.dart`
2. Потім додати логіку фільтрації в `product_service.dart`
3. Оновити `home_page.dart` для передачі фільтрів
4. Оновити `filter_manager.dart` для підрахунку активних фільтрів
5. Протестувати каскадний вибір та фільтрацію

