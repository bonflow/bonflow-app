/// Snapshot of the venue's master data as served by `GET /masterdata`.
class MasterData {
  const MasterData({
    required this.areas,
    required this.tables,
    required this.stations,
    required this.categories,
    required this.articles,
    required this.modifierGroups,
    this.settings = const VenueSettings(),
  });

  factory MasterData.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) => [
      for (final item in (json[key] as List<dynamic>? ?? <dynamic>[]))
        parse(item as Map<String, dynamic>),
    ];
    return MasterData(
      areas: list('areas', Area.fromJson),
      tables: list('tables', DiningTable.fromJson),
      stations: list('stations', Station.fromJson),
      categories: list('categories', ArticleCategory.fromJson),
      articles: list('articles', Article.fromJson),
      modifierGroups: list('modifierGroups', ModifierGroup.fromJson),
      settings: json['settings'] is Map<String, dynamic>
          ? VenueSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : const VenueSettings(),
    );
  }

  final List<Area> areas;
  final List<DiningTable> tables;
  final List<Station> stations;
  final List<ArticleCategory> categories;
  final List<Article> articles;
  final List<ModifierGroup> modifierGroups;
  final VenueSettings settings;

  Article? article(int id) {
    for (final article in articles) {
      if (article.id == id) {
        return article;
      }
    }
    return null;
  }

  DiningTable? table(int id) {
    for (final table in tables) {
      if (table.id == id) {
        return table;
      }
    }
    return null;
  }

  ModifierGroup? modifierGroup(int id) {
    for (final group in modifierGroups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }

  /// Name of a modifier in any group, null if it is no longer on the menu.
  String? modifierName(int id) {
    for (final group in modifierGroups) {
      for (final modifier in group.modifiers) {
        if (modifier.id == id) {
          return modifier.name;
        }
      }
    }
    return null;
  }

  String? stationName(int id) {
    for (final station in stations) {
      if (station.id == id) {
        return station.name;
      }
    }
    return null;
  }

  List<Article> articlesOf(int categoryId) =>
      articles.where((a) => a.categoryId == categoryId).toList();

  List<DiningTable> tablesOf(int areaId) =>
      tables.where((t) => t.areaId == areaId).toList();
}

/// Venue wide settings from the admin UI; missing values fall back to the defaults.
class VenueSettings {
  const VenueSettings({this.coursesEnabled = true});

  factory VenueSettings.fromJson(Map<String, dynamic> json) =>
      VenueSettings(coursesEnabled: json['coursesEnabled'] as bool? ?? true);

  /// Whether articles can be assigned to courses ("Gang").
  final bool coursesEnabled;
}

class Area {
  const Area({required this.id, required this.name, this.color});

  factory Area.fromJson(Map<String, dynamic> json) => Area(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    color: json['color'] as String?,
  );

  final int id;
  final String name;

  /// `#RRGGBB` or null.
  final String? color;
}

class DiningTable {
  const DiningTable({
    required this.id,
    required this.areaId,
    required this.label,
    this.color,
  });

  factory DiningTable.fromJson(Map<String, dynamic> json) => DiningTable(
    id: (json['id'] as num).toInt(),
    areaId: (json['areaId'] as num).toInt(),
    label: json['label'] as String,
    color: json['color'] as String?,
  );

  final int id;
  final int areaId;
  final String label;

  /// `#RRGGBB`, already resolved by the server (own colour, else the area's); may be null.
  final String? color;
}

class Station {
  const Station({required this.id, required this.name});

  factory Station.fromJson(Map<String, dynamic> json) =>
      Station(id: (json['id'] as num).toInt(), name: json['name'] as String);

  final int id;
  final String name;
}

class ArticleCategory {
  const ArticleCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.parentId,
    this.color,
  });

  factory ArticleCategory.fromJson(Map<String, dynamic> json) =>
      ArticleCategory(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        parentId: (json['parentId'] as num?)?.toInt(),
        color: json['color'] as String?,
      );

  final int id;
  final String name;
  final int sortOrder;
  final int? parentId;

  /// `#RRGGBB`, already resolved by the server (own colour, else the parent's); may be null.
  final String? color;
}

class Article {
  const Article({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.modifierGroupIds,
    this.shortName,
    this.stationId,
  });

  factory Article.fromJson(Map<String, dynamic> json) => Article(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    shortName: json['shortName'] as String?,
    categoryId: (json['categoryId'] as num).toInt(),
    price: (json['price'] as num?)?.toDouble() ?? 0,
    stationId: (json['stationId'] as num?)?.toInt(),
    modifierGroupIds: [
      for (final id in (json['modifierGroupIds'] as List<dynamic>? ?? <dynamic>[]))
        (id as num).toInt(),
    ],
  );

  final int id;
  final String name;
  final String? shortName;
  final int categoryId;

  /// Informational only: payment happens outside of BonFlow.
  final double price;
  final int? stationId;
  final List<int> modifierGroupIds;
}

class ModifierGroup {
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.multiSelect,
    required this.modifiers,
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> json) => ModifierGroup(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    multiSelect: json['multiSelect'] as bool? ?? false,
    modifiers: [
      for (final item in (json['modifiers'] as List<dynamic>? ?? <dynamic>[]))
        Modifier.fromJson(item as Map<String, dynamic>),
    ],
  );

  final int id;
  final String name;
  final bool multiSelect;
  final List<Modifier> modifiers;
}

class Modifier {
  const Modifier({required this.id, required this.name});

  factory Modifier.fromJson(Map<String, dynamic> json) =>
      Modifier(id: (json['id'] as num).toInt(), name: json['name'] as String);

  final int id;
  final String name;
}
