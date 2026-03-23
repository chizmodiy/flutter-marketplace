import 'package:flutter_map/flutter_map.dart';
import '../config/mapbox_config.dart';

enum MapStyle {
  standard,
  light,
  lightNoLabels,
  dark,
  darkNoLabels,
  toner,
  tonerLite,
  watercolor,
  terrain,
  satellite,
  osmClassic,
  osmOutdoors,
  osmTransport,
  osmCycle,
  osmHOT,
  osmDE,
  mapboxLight,
  mapboxStreets,
  mapboxOutdoors,
  mapboxSatellite,
  mapboxSatelliteStreets,
  domyStyle,
}

class MapStyleService {
  static const Map<MapStyle, MapStyleConfig> _styles = {
    MapStyle.standard: MapStyleConfig(
      name: 'Стандартна',
      description: 'Класична карта з дорогами та назвами',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© OpenStreetMap contributors, © CARTO',
    ),
    MapStyle.light: MapStyleConfig(
      name: 'Світла',
      description: 'Світла карта з мінімальними кольорами',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© OpenStreetMap contributors, © CARTO',
    ),
    MapStyle.lightNoLabels: MapStyleConfig(
      name: 'Світла без назв',
      description: 'Світла карта без доріг та назв',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© OpenStreetMap contributors, © CARTO',
    ),
    MapStyle.dark: MapStyleConfig(
      name: 'Темна',
      description: 'Темна карта для нічного режиму',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© OpenStreetMap contributors, © CARTO',
    ),
    MapStyle.darkNoLabels: MapStyleConfig(
      name: 'Темна без назв',
      description: 'Темна карта без доріг та назв',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© OpenStreetMap contributors, © CARTO',
    ),
    MapStyle.toner: MapStyleConfig(
      name: 'Тонер',
      description: 'Чорно-білий стиль',
      urlTemplate:
          'https://stamen-tiles-{s}.a.ssl.fastly.net/toner/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© Stamen Design, © OpenStreetMap contributors',
    ),
    MapStyle.tonerLite: MapStyleConfig(
      name: 'Тонер лайт',
      description: 'Мінімальний чорно-білий стиль',
      urlTemplate:
          'https://stamen-tiles-{s}.a.ssl.fastly.net/toner-lite/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© Stamen Design, © OpenStreetMap contributors',
    ),
    MapStyle.watercolor: MapStyleConfig(
      name: 'Акварель',
      description: 'Художній акварельний стиль',
      urlTemplate:
          'https://stamen-tiles-{s}.a.ssl.fastly.net/watercolor/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© Stamen Design, © OpenStreetMap contributors',
    ),
    MapStyle.terrain: MapStyleConfig(
      name: 'Рельєф',
      description: 'Карта з рельєфом місцевості',
      urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
      subdomains: ['a', 'b', 'c'],
      attribution: '© OpenStreetMap contributors, © OpenTopoMap',
    ),
    MapStyle.satellite: MapStyleConfig(
      name: 'Супутникова',
      description: 'Супутникові знімки',
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      subdomains: [],
      attribution: '© Esri',
    ),
    MapStyle.osmClassic: MapStyleConfig(
      name: 'OSM Класична',
      description: 'Класичний OpenStreetMap з характерною палітрою',
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: [],
      attribution: '© OpenStreetMap contributors',
    ),
    MapStyle.osmOutdoors: MapStyleConfig(
      name: 'OSM Природа',
      description: 'OpenStreetMap для активного відпочинку',
      urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
      subdomains: ['a', 'b', 'c'],
      attribution: '© OpenStreetMap contributors, © OpenTopoMap',
    ),
    MapStyle.osmTransport: MapStyleConfig(
      name: 'OSM Транспорт',
      description: 'Карта з акцентом на транспортну мережу',
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: [],
      attribution: '© OpenStreetMap contributors',
    ),
    MapStyle.osmCycle: MapStyleConfig(
      name: 'OSM Велосипедна',
      description: 'Карта для велосипедистів з велодоріжками',
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: [],
      attribution: '© OpenStreetMap contributors',
    ),
    MapStyle.osmHOT: MapStyleConfig(
      name: 'OSM Humanitarian',
      description: 'Стиль Humanitarian OpenStreetMap Team',
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: [],
      attribution: '© OpenStreetMap contributors',
    ),
    MapStyle.osmDE: MapStyleConfig(
      name: 'OSM Німецька',
      description: 'Німецький стиль OpenStreetMap',
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: [],
      attribution: '© OpenStreetMap contributors',
    ),
    MapStyle.mapboxLight: MapStyleConfig(
      name: 'Mapbox Світла',
      description: 'Мінімалістичний стиль з чистим дизайном',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© OpenStreetMap contributors, © CARTO',
    ),
    MapStyle.mapboxStreets: MapStyleConfig(
      name: 'Mapbox Вулиці',
      description: 'Raster аналог для Standard (vector-only)',
      urlTemplate:
          'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=YOUR_TOKEN',
      subdomains: [],
      attribution: '© Mapbox, © OpenStreetMap contributors',
    ),
    MapStyle.mapboxOutdoors: MapStyleConfig(
      name: 'Mapbox Природа',
      description: 'Стиль для активного відпочинку (OpenTopoMap fallback)',
      urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
      subdomains: ['a', 'b', 'c'],
      attribution: '© OpenStreetMap contributors, © OpenTopoMap',
    ),
    MapStyle.mapboxSatellite: MapStyleConfig(
      name: 'Mapbox Супутник',
      description: 'Супутникові знімки',
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      subdomains: [],
      attribution: '© Esri',
    ),
    MapStyle.mapboxSatelliteStreets: MapStyleConfig(
      name: 'Mapbox Гібридна',
      description: 'Супутникові знімки з дорогами та назвами',
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
      subdomains: [],
      attribution: '© Esri',
    ),
    MapStyle.domyStyle: MapStyleConfig(
      name: 'Domy Стиль',
      description: 'Стиль карти з додатку Domy - мінімалістичний та чистий',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© OpenStreetMap contributors, © CARTO',
    ),
  };

  static MapStyleConfig getStyleConfig(MapStyle style) {
    return _styles[style] ?? _styles[MapStyle.standard]!;
  }

  static List<MapStyle> get availableStyles => MapStyle.values;

  static TileLayer createTileLayer(MapStyle style) {
    final config = getStyleConfig(style);
    final isMapbox = config.urlTemplate.contains('api.mapbox.com');
    final finalUrl = config.urlTemplate.replaceAll(
      'YOUR_TOKEN',
      mapboxAccessToken,
    );

    // Debug: print URL for Mapbox styles
    if (isMapbox) {
      print('Mapbox URL: $finalUrl');
      print('Token: ${mapboxAccessToken.substring(0, 20)}...');
    }

    return TileLayer(
      urlTemplate: finalUrl,
      subdomains: config.subdomains,
      userAgentPackageName: 'com.valtorian.zeno',
      tileSize: 256, // Використовуємо стандартний розмір для всіх
      additionalOptions: {'attribution': config.attribution},
    );
  }
}

class MapStyleConfig {
  final String name;
  final String description;
  final String urlTemplate;
  final List<String> subdomains;
  final String attribution;

  const MapStyleConfig({
    required this.name,
    required this.description,
    required this.urlTemplate,
    required this.subdomains,
    required this.attribution,
  });
}
