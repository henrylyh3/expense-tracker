// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class Categories extends Table with TableInfo<Categories, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Categories(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL PRIMARY KEY CHECK (length(id) BETWEEN 1 AND 64)',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80)',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (type IN (\'income\', \'expense\'))',
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(icon_key) BETWEEN 1 AND 64)',
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (length(color_hex) = 7 AND substr(color_hex, 1, 1) = \'#\' AND substr(color_hex, 2) NOT GLOB \'*[^0-9A-Fa-f]*\')',
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK (typeof(sort_order) = \'integer\' AND sort_order >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT FALSE CHECK (is_archived IN (0, 1))',
    defaultValue: const CustomExpression('FALSE'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    iconKey,
    colorHex,
    sortOrder,
    isArchived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_iconKeyMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorHexMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
    );
  }

  @override
  Categories createAlias(String alias) {
    return Categories(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String name;
  final String type;
  final String iconKey;
  final String colorHex;
  final int sortOrder;
  final bool isArchived;
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.colorHex,
    required this.sortOrder,
    required this.isArchived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['icon_key'] = Variable<String>(iconKey);
    map['color_hex'] = Variable<String>(colorHex);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_archived'] = Variable<bool>(isArchived);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      iconKey: Value(iconKey),
      colorHex: Value(colorHex),
      sortOrder: Value(sortOrder),
      isArchived: Value(isArchived),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      iconKey: serializer.fromJson<String>(json['icon_key']),
      colorHex: serializer.fromJson<String>(json['color_hex']),
      sortOrder: serializer.fromJson<int>(json['sort_order']),
      isArchived: serializer.fromJson<bool>(json['is_archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'icon_key': serializer.toJson<String>(iconKey),
      'color_hex': serializer.toJson<String>(colorHex),
      'sort_order': serializer.toJson<int>(sortOrder),
      'is_archived': serializer.toJson<bool>(isArchived),
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? type,
    String? iconKey,
    String? colorHex,
    int? sortOrder,
    bool? isArchived,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    iconKey: iconKey ?? this.iconKey,
    colorHex: colorHex ?? this.colorHex,
    sortOrder: sortOrder ?? this.sortOrder,
    isArchived: isArchived ?? this.isArchived,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('iconKey: $iconKey, ')
          ..write('colorHex: $colorHex, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, type, iconKey, colorHex, sortOrder, isArchived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.iconKey == this.iconKey &&
          other.colorHex == this.colorHex &&
          other.sortOrder == this.sortOrder &&
          other.isArchived == this.isArchived);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> iconKey;
  final Value<String> colorHex;
  final Value<int> sortOrder;
  final Value<bool> isArchived;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    required String type,
    required String iconKey,
    required String colorHex,
    this.sortOrder = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       iconKey = Value(iconKey),
       colorHex = Value(colorHex);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? iconKey,
    Expression<String>? colorHex,
    Expression<int>? sortOrder,
    Expression<bool>? isArchived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (iconKey != null) 'icon_key': iconKey,
      if (colorHex != null) 'color_hex': colorHex,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isArchived != null) 'is_archived': isArchived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? iconKey,
    Value<String>? colorHex,
    Value<int>? sortOrder,
    Value<bool>? isArchived,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconKey: iconKey ?? this.iconKey,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('iconKey: $iconKey, ')
          ..write('colorHex: $colorHex, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isArchived: $isArchived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Currencies extends Table with TableInfo<Currencies, Currency> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Currencies(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL PRIMARY KEY CHECK (length(code) = 3 AND code NOT GLOB \'*[^A-Z]*\')',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80)',
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (length(trim(symbol)) BETWEEN 1 AND 12)',
  );
  static const VerificationMeta _decimalPlacesMeta = const VerificationMeta(
    'decimalPlaces',
  );
  late final GeneratedColumn<int> decimalPlaces = GeneratedColumn<int>(
    'decimal_places',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (typeof(decimal_places) = \'integer\' AND decimal_places BETWEEN 0 AND 6)',
  );
  static const VerificationMeta _rateToMyrMeta = const VerificationMeta(
    'rateToMyr',
  );
  late final GeneratedColumn<String> rateToMyr = GeneratedColumn<String>(
    'rate_to_myr',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (length(rate_to_myr) BETWEEN 1 AND 25 AND rate_to_myr NOT GLOB \'*[^0-9.]*\' AND rate_to_myr GLOB \'*[1-9]*\' AND substr(rate_to_myr, 1, 1) <> \'.\' AND substr(rate_to_myr, -1) <> \'.\' AND(length(rate_to_myr) = 1 OR substr(rate_to_myr, 1, 1) <> \'0\' OR substr(rate_to_myr, 2, 1) = \'.\')AND(instr(rate_to_myr, \'.\') = 0 AND length(rate_to_myr) <= 12 OR instr(rate_to_myr, \'.\') BETWEEN 2 AND 13 AND length(rate_to_myr) - instr(rate_to_myr, \'.\') BETWEEN 1 AND 12 AND substr(rate_to_myr, instr(rate_to_myr, \'.\') + 1) NOT GLOB \'*.*\'))',
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT TRUE CHECK (is_active IN (0, 1))',
    defaultValue: const CustomExpression('TRUE'),
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (typeof(created_at_utc) = \'integer\' AND created_at_utc >= 0)',
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (typeof(updated_at_utc) = \'integer\' AND updated_at_utc >= created_at_utc)',
  );
  @override
  List<GeneratedColumn> get $columns => [
    code,
    name,
    symbol,
    decimalPlaces,
    rateToMyr,
    isActive,
    createdAtUtc,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'currencies';
  @override
  VerificationContext validateIntegrity(
    Insertable<Currency> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('decimal_places')) {
      context.handle(
        _decimalPlacesMeta,
        decimalPlaces.isAcceptableOrUnknown(
          data['decimal_places']!,
          _decimalPlacesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_decimalPlacesMeta);
    }
    if (data.containsKey('rate_to_myr')) {
      context.handle(
        _rateToMyrMeta,
        rateToMyr.isAcceptableOrUnknown(data['rate_to_myr']!, _rateToMyrMeta),
      );
    } else if (isInserting) {
      context.missing(_rateToMyrMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  Currency map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Currency(
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      decimalPlaces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}decimal_places'],
      )!,
      rateToMyr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate_to_myr'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  Currencies createAlias(String alias) {
    return Currencies(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'CHECK(code <> \'MYR\' OR(decimal_places = 2 AND rate_to_myr = \'1\' AND is_active = 1))',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class Currency extends DataClass implements Insertable<Currency> {
  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;
  final String rateToMyr;
  final bool isActive;
  final int createdAtUtc;
  final int updatedAtUtc;
  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimalPlaces,
    required this.rateToMyr,
    required this.isActive,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['symbol'] = Variable<String>(symbol);
    map['decimal_places'] = Variable<int>(decimalPlaces);
    map['rate_to_myr'] = Variable<String>(rateToMyr);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    return map;
  }

  CurrenciesCompanion toCompanion(bool nullToAbsent) {
    return CurrenciesCompanion(
      code: Value(code),
      name: Value(name),
      symbol: Value(symbol),
      decimalPlaces: Value(decimalPlaces),
      rateToMyr: Value(rateToMyr),
      isActive: Value(isActive),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory Currency.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Currency(
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      symbol: serializer.fromJson<String>(json['symbol']),
      decimalPlaces: serializer.fromJson<int>(json['decimal_places']),
      rateToMyr: serializer.fromJson<String>(json['rate_to_myr']),
      isActive: serializer.fromJson<bool>(json['is_active']),
      createdAtUtc: serializer.fromJson<int>(json['created_at_utc']),
      updatedAtUtc: serializer.fromJson<int>(json['updated_at_utc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'symbol': serializer.toJson<String>(symbol),
      'decimal_places': serializer.toJson<int>(decimalPlaces),
      'rate_to_myr': serializer.toJson<String>(rateToMyr),
      'is_active': serializer.toJson<bool>(isActive),
      'created_at_utc': serializer.toJson<int>(createdAtUtc),
      'updated_at_utc': serializer.toJson<int>(updatedAtUtc),
    };
  }

  Currency copyWith({
    String? code,
    String? name,
    String? symbol,
    int? decimalPlaces,
    String? rateToMyr,
    bool? isActive,
    int? createdAtUtc,
    int? updatedAtUtc,
  }) => Currency(
    code: code ?? this.code,
    name: name ?? this.name,
    symbol: symbol ?? this.symbol,
    decimalPlaces: decimalPlaces ?? this.decimalPlaces,
    rateToMyr: rateToMyr ?? this.rateToMyr,
    isActive: isActive ?? this.isActive,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  Currency copyWithCompanion(CurrenciesCompanion data) {
    return Currency(
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      decimalPlaces: data.decimalPlaces.present
          ? data.decimalPlaces.value
          : this.decimalPlaces,
      rateToMyr: data.rateToMyr.present ? data.rateToMyr.value : this.rateToMyr,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Currency(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('symbol: $symbol, ')
          ..write('decimalPlaces: $decimalPlaces, ')
          ..write('rateToMyr: $rateToMyr, ')
          ..write('isActive: $isActive, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    code,
    name,
    symbol,
    decimalPlaces,
    rateToMyr,
    isActive,
    createdAtUtc,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Currency &&
          other.code == this.code &&
          other.name == this.name &&
          other.symbol == this.symbol &&
          other.decimalPlaces == this.decimalPlaces &&
          other.rateToMyr == this.rateToMyr &&
          other.isActive == this.isActive &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class CurrenciesCompanion extends UpdateCompanion<Currency> {
  final Value<String> code;
  final Value<String> name;
  final Value<String> symbol;
  final Value<int> decimalPlaces;
  final Value<String> rateToMyr;
  final Value<bool> isActive;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> rowid;
  const CurrenciesCompanion({
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.symbol = const Value.absent(),
    this.decimalPlaces = const Value.absent(),
    this.rateToMyr = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurrenciesCompanion.insert({
    required String code,
    required String name,
    required String symbol,
    required int decimalPlaces,
    required String rateToMyr,
    this.isActive = const Value.absent(),
    required int createdAtUtc,
    required int updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : code = Value(code),
       name = Value(name),
       symbol = Value(symbol),
       decimalPlaces = Value(decimalPlaces),
       rateToMyr = Value(rateToMyr),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<Currency> custom({
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? symbol,
    Expression<int>? decimalPlaces,
    Expression<String>? rateToMyr,
    Expression<bool>? isActive,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (symbol != null) 'symbol': symbol,
      if (decimalPlaces != null) 'decimal_places': decimalPlaces,
      if (rateToMyr != null) 'rate_to_myr': rateToMyr,
      if (isActive != null) 'is_active': isActive,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CurrenciesCompanion copyWith({
    Value<String>? code,
    Value<String>? name,
    Value<String>? symbol,
    Value<int>? decimalPlaces,
    Value<String>? rateToMyr,
    Value<bool>? isActive,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return CurrenciesCompanion(
      code: code ?? this.code,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      decimalPlaces: decimalPlaces ?? this.decimalPlaces,
      rateToMyr: rateToMyr ?? this.rateToMyr,
      isActive: isActive ?? this.isActive,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (decimalPlaces.present) {
      map['decimal_places'] = Variable<int>(decimalPlaces.value);
    }
    if (rateToMyr.present) {
      map['rate_to_myr'] = Variable<String>(rateToMyr.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurrenciesCompanion(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('symbol: $symbol, ')
          ..write('decimalPlaces: $decimalPlaces, ')
          ..write('rateToMyr: $rateToMyr, ')
          ..write('isActive: $isActive, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Trips extends Table with TableInfo<Trips, Trip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Trips(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL PRIMARY KEY CHECK (length(id) BETWEEN 1 AND 64)',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80)',
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<Trip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  Trips createAlias(String alias) {
    return Trips(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Trip extends DataClass implements Insertable<Trip> {
  final String id;
  final String name;
  const Trip({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(id: Value(id), name: Value(name));
  }

  factory Trip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trip(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Trip copyWith({String? id, String? name}) =>
      Trip(id: id ?? this.id, name: name ?? this.name);
  Trip copyWithCompanion(TripsCompanion data) {
    return Trip(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trip(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trip && other.id == this.id && other.name == this.name);
}

class TripsCompanion extends UpdateCompanion<Trip> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> rowid;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripsCompanion.insert({
    required String id,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Trip> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return TripsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class CurrencyRates extends Table with TableInfo<CurrencyRates, CurrencyRate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  CurrencyRates(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL PRIMARY KEY CHECK (length(id) BETWEEN 1 AND 80)',
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES currencies(code)ON UPDATE CASCADE ON DELETE RESTRICT',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80)',
  );
  static const VerificationMeta _rateToMyrMeta = const VerificationMeta(
    'rateToMyr',
  );
  late final GeneratedColumn<String> rateToMyr = GeneratedColumn<String>(
    'rate_to_myr',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (length(rate_to_myr) BETWEEN 1 AND 25 AND rate_to_myr NOT GLOB \'*[^0-9.]*\' AND rate_to_myr GLOB \'*[1-9]*\' AND substr(rate_to_myr, 1, 1) <> \'.\' AND substr(rate_to_myr, -1) <> \'.\' AND(length(rate_to_myr) = 1 OR substr(rate_to_myr, 1, 1) <> \'0\' OR substr(rate_to_myr, 2, 1) = \'.\')AND(instr(rate_to_myr, \'.\') = 0 AND length(rate_to_myr) <= 12 OR instr(rate_to_myr, \'.\') BETWEEN 2 AND 13 AND length(rate_to_myr) - instr(rate_to_myr, \'.\') BETWEEN 1 AND 12 AND substr(rate_to_myr, instr(rate_to_myr, \'.\') + 1) NOT GLOB \'*.*\'))',
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT TRUE CHECK (is_active IN (0, 1))',
    defaultValue: const CustomExpression('TRUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currencyCode,
    name,
    rateToMyr,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'currency_rates';
  @override
  VerificationContext validateIntegrity(
    Insertable<CurrencyRate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('rate_to_myr')) {
      context.handle(
        _rateToMyrMeta,
        rateToMyr.isAcceptableOrUnknown(data['rate_to_myr']!, _rateToMyrMeta),
      );
    } else if (isInserting) {
      context.missing(_rateToMyrMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CurrencyRate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CurrencyRate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      rateToMyr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate_to_myr'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  CurrencyRates createAlias(String alias) {
    return CurrencyRates(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'CHECK(currency_code <> \'MYR\')',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class CurrencyRate extends DataClass implements Insertable<CurrencyRate> {
  final String id;
  final String currencyCode;
  final String name;
  final String rateToMyr;
  final bool isActive;
  const CurrencyRate({
    required this.id,
    required this.currencyCode,
    required this.name,
    required this.rateToMyr,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['currency_code'] = Variable<String>(currencyCode);
    map['name'] = Variable<String>(name);
    map['rate_to_myr'] = Variable<String>(rateToMyr);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  CurrencyRatesCompanion toCompanion(bool nullToAbsent) {
    return CurrencyRatesCompanion(
      id: Value(id),
      currencyCode: Value(currencyCode),
      name: Value(name),
      rateToMyr: Value(rateToMyr),
      isActive: Value(isActive),
    );
  }

  factory CurrencyRate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CurrencyRate(
      id: serializer.fromJson<String>(json['id']),
      currencyCode: serializer.fromJson<String>(json['currency_code']),
      name: serializer.fromJson<String>(json['name']),
      rateToMyr: serializer.fromJson<String>(json['rate_to_myr']),
      isActive: serializer.fromJson<bool>(json['is_active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'currency_code': serializer.toJson<String>(currencyCode),
      'name': serializer.toJson<String>(name),
      'rate_to_myr': serializer.toJson<String>(rateToMyr),
      'is_active': serializer.toJson<bool>(isActive),
    };
  }

  CurrencyRate copyWith({
    String? id,
    String? currencyCode,
    String? name,
    String? rateToMyr,
    bool? isActive,
  }) => CurrencyRate(
    id: id ?? this.id,
    currencyCode: currencyCode ?? this.currencyCode,
    name: name ?? this.name,
    rateToMyr: rateToMyr ?? this.rateToMyr,
    isActive: isActive ?? this.isActive,
  );
  CurrencyRate copyWithCompanion(CurrencyRatesCompanion data) {
    return CurrencyRate(
      id: data.id.present ? data.id.value : this.id,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      name: data.name.present ? data.name.value : this.name,
      rateToMyr: data.rateToMyr.present ? data.rateToMyr.value : this.rateToMyr,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurrencyRate(')
          ..write('id: $id, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('name: $name, ')
          ..write('rateToMyr: $rateToMyr, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, currencyCode, name, rateToMyr, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurrencyRate &&
          other.id == this.id &&
          other.currencyCode == this.currencyCode &&
          other.name == this.name &&
          other.rateToMyr == this.rateToMyr &&
          other.isActive == this.isActive);
}

class CurrencyRatesCompanion extends UpdateCompanion<CurrencyRate> {
  final Value<String> id;
  final Value<String> currencyCode;
  final Value<String> name;
  final Value<String> rateToMyr;
  final Value<bool> isActive;
  final Value<int> rowid;
  const CurrencyRatesCompanion({
    this.id = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.name = const Value.absent(),
    this.rateToMyr = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurrencyRatesCompanion.insert({
    required String id,
    required String currencyCode,
    required String name,
    required String rateToMyr,
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       currencyCode = Value(currencyCode),
       name = Value(name),
       rateToMyr = Value(rateToMyr);
  static Insertable<CurrencyRate> custom({
    Expression<String>? id,
    Expression<String>? currencyCode,
    Expression<String>? name,
    Expression<String>? rateToMyr,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (name != null) 'name': name,
      if (rateToMyr != null) 'rate_to_myr': rateToMyr,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CurrencyRatesCompanion copyWith({
    Value<String>? id,
    Value<String>? currencyCode,
    Value<String>? name,
    Value<String>? rateToMyr,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return CurrencyRatesCompanion(
      id: id ?? this.id,
      currencyCode: currencyCode ?? this.currencyCode,
      name: name ?? this.name,
      rateToMyr: rateToMyr ?? this.rateToMyr,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rateToMyr.present) {
      map['rate_to_myr'] = Variable<String>(rateToMyr.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurrencyRatesCompanion(')
          ..write('id: $id, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('name: $name, ')
          ..write('rateToMyr: $rateToMyr, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class TripRates extends Table with TableInfo<TripRates, TripRate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TripRates(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES trips(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES currencies(code)ON UPDATE CASCADE ON DELETE CASCADE',
  );
  static const VerificationMeta _rateToMyrMeta = const VerificationMeta(
    'rateToMyr',
  );
  late final GeneratedColumn<String> rateToMyr = GeneratedColumn<String>(
    'rate_to_myr',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (length(rate_to_myr) BETWEEN 1 AND 25 AND rate_to_myr NOT GLOB \'*[^0-9.]*\' AND rate_to_myr GLOB \'*[1-9]*\' AND substr(rate_to_myr, 1, 1) <> \'.\' AND substr(rate_to_myr, -1) <> \'.\' AND(length(rate_to_myr) = 1 OR substr(rate_to_myr, 1, 1) <> \'0\' OR substr(rate_to_myr, 2, 1) = \'.\')AND(instr(rate_to_myr, \'.\') = 0 AND length(rate_to_myr) <= 12 OR instr(rate_to_myr, \'.\') BETWEEN 2 AND 13 AND length(rate_to_myr) - instr(rate_to_myr, \'.\') BETWEEN 1 AND 12 AND substr(rate_to_myr, instr(rate_to_myr, \'.\') + 1) NOT GLOB \'*.*\'))',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'CHECK (name IS NULL OR length(trim(name)) BETWEEN 1 AND 80)',
  );
  static const VerificationMeta _rateIdMeta = const VerificationMeta('rateId');
  late final GeneratedColumn<String> rateId = GeneratedColumn<String>(
    'rate_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES currency_rates(id)ON DELETE RESTRICT',
  );
  @override
  List<GeneratedColumn> get $columns => [
    tripId,
    currencyCode,
    rateToMyr,
    name,
    rateId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_rates';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripRate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('rate_to_myr')) {
      context.handle(
        _rateToMyrMeta,
        rateToMyr.isAcceptableOrUnknown(data['rate_to_myr']!, _rateToMyrMeta),
      );
    } else if (isInserting) {
      context.missing(_rateToMyrMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('rate_id')) {
      context.handle(
        _rateIdMeta,
        rateId.isAcceptableOrUnknown(data['rate_id']!, _rateIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tripId, currencyCode};
  @override
  TripRate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripRate(
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      rateToMyr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate_to_myr'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      rateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate_id'],
      ),
    );
  }

  @override
  TripRates createAlias(String alias) {
    return TripRates(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(trip_id, currency_code)',
    'CHECK(currency_code <> \'MYR\')',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class TripRate extends DataClass implements Insertable<TripRate> {
  final String tripId;
  final String currencyCode;
  final String rateToMyr;
  final String? name;
  final String? rateId;
  const TripRate({
    required this.tripId,
    required this.currencyCode,
    required this.rateToMyr,
    this.name,
    this.rateId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trip_id'] = Variable<String>(tripId);
    map['currency_code'] = Variable<String>(currencyCode);
    map['rate_to_myr'] = Variable<String>(rateToMyr);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || rateId != null) {
      map['rate_id'] = Variable<String>(rateId);
    }
    return map;
  }

  TripRatesCompanion toCompanion(bool nullToAbsent) {
    return TripRatesCompanion(
      tripId: Value(tripId),
      currencyCode: Value(currencyCode),
      rateToMyr: Value(rateToMyr),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      rateId: rateId == null && nullToAbsent
          ? const Value.absent()
          : Value(rateId),
    );
  }

  factory TripRate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripRate(
      tripId: serializer.fromJson<String>(json['trip_id']),
      currencyCode: serializer.fromJson<String>(json['currency_code']),
      rateToMyr: serializer.fromJson<String>(json['rate_to_myr']),
      name: serializer.fromJson<String?>(json['name']),
      rateId: serializer.fromJson<String?>(json['rate_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trip_id': serializer.toJson<String>(tripId),
      'currency_code': serializer.toJson<String>(currencyCode),
      'rate_to_myr': serializer.toJson<String>(rateToMyr),
      'name': serializer.toJson<String?>(name),
      'rate_id': serializer.toJson<String?>(rateId),
    };
  }

  TripRate copyWith({
    String? tripId,
    String? currencyCode,
    String? rateToMyr,
    Value<String?> name = const Value.absent(),
    Value<String?> rateId = const Value.absent(),
  }) => TripRate(
    tripId: tripId ?? this.tripId,
    currencyCode: currencyCode ?? this.currencyCode,
    rateToMyr: rateToMyr ?? this.rateToMyr,
    name: name.present ? name.value : this.name,
    rateId: rateId.present ? rateId.value : this.rateId,
  );
  TripRate copyWithCompanion(TripRatesCompanion data) {
    return TripRate(
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      rateToMyr: data.rateToMyr.present ? data.rateToMyr.value : this.rateToMyr,
      name: data.name.present ? data.name.value : this.name,
      rateId: data.rateId.present ? data.rateId.value : this.rateId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripRate(')
          ..write('tripId: $tripId, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('rateToMyr: $rateToMyr, ')
          ..write('name: $name, ')
          ..write('rateId: $rateId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(tripId, currencyCode, rateToMyr, name, rateId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripRate &&
          other.tripId == this.tripId &&
          other.currencyCode == this.currencyCode &&
          other.rateToMyr == this.rateToMyr &&
          other.name == this.name &&
          other.rateId == this.rateId);
}

class TripRatesCompanion extends UpdateCompanion<TripRate> {
  final Value<String> tripId;
  final Value<String> currencyCode;
  final Value<String> rateToMyr;
  final Value<String?> name;
  final Value<String?> rateId;
  final Value<int> rowid;
  const TripRatesCompanion({
    this.tripId = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.rateToMyr = const Value.absent(),
    this.name = const Value.absent(),
    this.rateId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripRatesCompanion.insert({
    required String tripId,
    required String currencyCode,
    required String rateToMyr,
    this.name = const Value.absent(),
    this.rateId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tripId = Value(tripId),
       currencyCode = Value(currencyCode),
       rateToMyr = Value(rateToMyr);
  static Insertable<TripRate> custom({
    Expression<String>? tripId,
    Expression<String>? currencyCode,
    Expression<String>? rateToMyr,
    Expression<String>? name,
    Expression<String>? rateId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tripId != null) 'trip_id': tripId,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (rateToMyr != null) 'rate_to_myr': rateToMyr,
      if (name != null) 'name': name,
      if (rateId != null) 'rate_id': rateId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripRatesCompanion copyWith({
    Value<String>? tripId,
    Value<String>? currencyCode,
    Value<String>? rateToMyr,
    Value<String?>? name,
    Value<String?>? rateId,
    Value<int>? rowid,
  }) {
    return TripRatesCompanion(
      tripId: tripId ?? this.tripId,
      currencyCode: currencyCode ?? this.currencyCode,
      rateToMyr: rateToMyr ?? this.rateToMyr,
      name: name ?? this.name,
      rateId: rateId ?? this.rateId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (rateToMyr.present) {
      map['rate_to_myr'] = Variable<String>(rateToMyr.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rateId.present) {
      map['rate_id'] = Variable<String>(rateId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripRatesCompanion(')
          ..write('tripId: $tripId, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('rateToMyr: $rateToMyr, ')
          ..write('name: $name, ')
          ..write('rateId: $rateId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Transactions extends Table with TableInfo<Transactions, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Transactions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL PRIMARY KEY CHECK (length(id) = 36 AND substr(id, 9, 1) = \'-\' AND substr(id, 14, 1) = \'-\' AND substr(id, 19, 1) = \'-\' AND substr(id, 24, 1) = \'-\' AND length("replace"(id, \'-\', \'\')) = 32 AND "replace"(id, \'-\', \'\') NOT GLOB \'*[^0-9A-Fa-f]*\')',
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES categories(id)ON UPDATE RESTRICT ON DELETE RESTRICT',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (type IN (\'income\', \'expense\'))',
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (typeof(amount_minor) = \'integer\' AND amount_minor > 0)',
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES currencies(code)ON UPDATE RESTRICT ON DELETE RESTRICT',
  );
  static const VerificationMeta _exchangeRateSnapshotMeta =
      const VerificationMeta('exchangeRateSnapshot');
  late final GeneratedColumn<String>
  exchangeRateSnapshot = GeneratedColumn<String>(
    'exchange_rate_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (length(exchange_rate_snapshot) BETWEEN 1 AND 25 AND exchange_rate_snapshot NOT GLOB \'*[^0-9.]*\' AND exchange_rate_snapshot GLOB \'*[1-9]*\' AND substr(exchange_rate_snapshot, 1, 1) <> \'.\' AND substr(exchange_rate_snapshot, -1) <> \'.\' AND(length(exchange_rate_snapshot) = 1 OR substr(exchange_rate_snapshot, 1, 1) <> \'0\' OR substr(exchange_rate_snapshot, 2, 1) = \'.\')AND(instr(exchange_rate_snapshot, \'.\') = 0 AND length(exchange_rate_snapshot) <= 12 OR instr(exchange_rate_snapshot, \'.\') BETWEEN 2 AND 13 AND length(exchange_rate_snapshot) - instr(exchange_rate_snapshot, \'.\') BETWEEN 1 AND 12 AND substr(exchange_rate_snapshot, instr(exchange_rate_snapshot, \'.\') + 1) NOT GLOB \'*.*\'))',
  );
  static const VerificationMeta _amountMyrMinorMeta = const VerificationMeta(
    'amountMyrMinor',
  );
  late final GeneratedColumn<int> amountMyrMinor = GeneratedColumn<int>(
    'amount_myr_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (typeof(amount_myr_minor) = \'integer\' AND amount_myr_minor >= 0)',
  );
  static const VerificationMeta _transactionDateMeta = const VerificationMeta(
    'transactionDate',
  );
  late final GeneratedColumn<String> transactionDate = GeneratedColumn<String>(
    'transaction_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (transaction_date GLOB \'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\' AND transaction_date BETWEEN \'0001-01-01\' AND \'9999-12-31\' AND date(transaction_date, \'+0 days\') IS NOT NULL AND date(transaction_date, \'+0 days\') = transaction_date)',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (note IS NULL OR length(note) <= 2000)',
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (typeof(created_at_utc) = \'integer\' AND created_at_utc >= 0)',
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (typeof(updated_at_utc) = \'integer\' AND updated_at_utc >= created_at_utc)',
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'personal\' REFERENCES trips(id)',
    defaultValue: const CustomExpression('\'personal\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    type,
    amountMinor,
    currencyCode,
    exchangeRateSnapshot,
    amountMyrMinor,
    transactionDate,
    note,
    createdAtUtc,
    updatedAtUtc,
    tripId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('exchange_rate_snapshot')) {
      context.handle(
        _exchangeRateSnapshotMeta,
        exchangeRateSnapshot.isAcceptableOrUnknown(
          data['exchange_rate_snapshot']!,
          _exchangeRateSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exchangeRateSnapshotMeta);
    }
    if (data.containsKey('amount_myr_minor')) {
      context.handle(
        _amountMyrMinorMeta,
        amountMyrMinor.isAcceptableOrUnknown(
          data['amount_myr_minor']!,
          _amountMyrMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMyrMinorMeta);
    }
    if (data.containsKey('transaction_date')) {
      context.handle(
        _transactionDateMeta,
        transactionDate.isAcceptableOrUnknown(
          data['transaction_date']!,
          _transactionDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionDateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      exchangeRateSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange_rate_snapshot'],
      )!,
      amountMyrMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_myr_minor'],
      )!,
      transactionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_date'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
    );
  }

  @override
  Transactions createAlias(String alias) {
    return Transactions(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'CHECK(currency_code <> \'MYR\' OR(exchange_rate_snapshot = \'1\' AND amount_myr_minor = amount_minor))',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final String categoryId;
  final String type;
  final int amountMinor;
  final String currencyCode;
  final String exchangeRateSnapshot;
  final int amountMyrMinor;
  final String transactionDate;
  final String? note;
  final int createdAtUtc;
  final int updatedAtUtc;
  final String tripId;
  const Transaction({
    required this.id,
    required this.categoryId,
    required this.type,
    required this.amountMinor,
    required this.currencyCode,
    required this.exchangeRateSnapshot,
    required this.amountMyrMinor,
    required this.transactionDate,
    this.note,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.tripId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['type'] = Variable<String>(type);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency_code'] = Variable<String>(currencyCode);
    map['exchange_rate_snapshot'] = Variable<String>(exchangeRateSnapshot);
    map['amount_myr_minor'] = Variable<int>(amountMyrMinor);
    map['transaction_date'] = Variable<String>(transactionDate);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    map['trip_id'] = Variable<String>(tripId);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      type: Value(type),
      amountMinor: Value(amountMinor),
      currencyCode: Value(currencyCode),
      exchangeRateSnapshot: Value(exchangeRateSnapshot),
      amountMyrMinor: Value(amountMyrMinor),
      transactionDate: Value(transactionDate),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      tripId: Value(tripId),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['category_id']),
      type: serializer.fromJson<String>(json['type']),
      amountMinor: serializer.fromJson<int>(json['amount_minor']),
      currencyCode: serializer.fromJson<String>(json['currency_code']),
      exchangeRateSnapshot: serializer.fromJson<String>(
        json['exchange_rate_snapshot'],
      ),
      amountMyrMinor: serializer.fromJson<int>(json['amount_myr_minor']),
      transactionDate: serializer.fromJson<String>(json['transaction_date']),
      note: serializer.fromJson<String?>(json['note']),
      createdAtUtc: serializer.fromJson<int>(json['created_at_utc']),
      updatedAtUtc: serializer.fromJson<int>(json['updated_at_utc']),
      tripId: serializer.fromJson<String>(json['trip_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'category_id': serializer.toJson<String>(categoryId),
      'type': serializer.toJson<String>(type),
      'amount_minor': serializer.toJson<int>(amountMinor),
      'currency_code': serializer.toJson<String>(currencyCode),
      'exchange_rate_snapshot': serializer.toJson<String>(exchangeRateSnapshot),
      'amount_myr_minor': serializer.toJson<int>(amountMyrMinor),
      'transaction_date': serializer.toJson<String>(transactionDate),
      'note': serializer.toJson<String?>(note),
      'created_at_utc': serializer.toJson<int>(createdAtUtc),
      'updated_at_utc': serializer.toJson<int>(updatedAtUtc),
      'trip_id': serializer.toJson<String>(tripId),
    };
  }

  Transaction copyWith({
    String? id,
    String? categoryId,
    String? type,
    int? amountMinor,
    String? currencyCode,
    String? exchangeRateSnapshot,
    int? amountMyrMinor,
    String? transactionDate,
    Value<String?> note = const Value.absent(),
    int? createdAtUtc,
    int? updatedAtUtc,
    String? tripId,
  }) => Transaction(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    type: type ?? this.type,
    amountMinor: amountMinor ?? this.amountMinor,
    currencyCode: currencyCode ?? this.currencyCode,
    exchangeRateSnapshot: exchangeRateSnapshot ?? this.exchangeRateSnapshot,
    amountMyrMinor: amountMyrMinor ?? this.amountMyrMinor,
    transactionDate: transactionDate ?? this.transactionDate,
    note: note.present ? note.value : this.note,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    tripId: tripId ?? this.tripId,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      type: data.type.present ? data.type.value : this.type,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      exchangeRateSnapshot: data.exchangeRateSnapshot.present
          ? data.exchangeRateSnapshot.value
          : this.exchangeRateSnapshot,
      amountMyrMinor: data.amountMyrMinor.present
          ? data.amountMyrMinor.value
          : this.amountMyrMinor,
      transactionDate: data.transactionDate.present
          ? data.transactionDate.value
          : this.transactionDate,
      note: data.note.present ? data.note.value : this.note,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('exchangeRateSnapshot: $exchangeRateSnapshot, ')
          ..write('amountMyrMinor: $amountMyrMinor, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('note: $note, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('tripId: $tripId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    type,
    amountMinor,
    currencyCode,
    exchangeRateSnapshot,
    amountMyrMinor,
    transactionDate,
    note,
    createdAtUtc,
    updatedAtUtc,
    tripId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.type == this.type &&
          other.amountMinor == this.amountMinor &&
          other.currencyCode == this.currencyCode &&
          other.exchangeRateSnapshot == this.exchangeRateSnapshot &&
          other.amountMyrMinor == this.amountMyrMinor &&
          other.transactionDate == this.transactionDate &&
          other.note == this.note &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.tripId == this.tripId);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String> type;
  final Value<int> amountMinor;
  final Value<String> currencyCode;
  final Value<String> exchangeRateSnapshot;
  final Value<int> amountMyrMinor;
  final Value<String> transactionDate;
  final Value<String?> note;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<String> tripId;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.type = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.exchangeRateSnapshot = const Value.absent(),
    this.amountMyrMinor = const Value.absent(),
    this.transactionDate = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.tripId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required String categoryId,
    required String type,
    required int amountMinor,
    required String currencyCode,
    required String exchangeRateSnapshot,
    required int amountMyrMinor,
    required String transactionDate,
    this.note = const Value.absent(),
    required int createdAtUtc,
    required int updatedAtUtc,
    this.tripId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       categoryId = Value(categoryId),
       type = Value(type),
       amountMinor = Value(amountMinor),
       currencyCode = Value(currencyCode),
       exchangeRateSnapshot = Value(exchangeRateSnapshot),
       amountMyrMinor = Value(amountMyrMinor),
       transactionDate = Value(transactionDate),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? type,
    Expression<int>? amountMinor,
    Expression<String>? currencyCode,
    Expression<String>? exchangeRateSnapshot,
    Expression<int>? amountMyrMinor,
    Expression<String>? transactionDate,
    Expression<String>? note,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<String>? tripId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (type != null) 'type': type,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (exchangeRateSnapshot != null)
        'exchange_rate_snapshot': exchangeRateSnapshot,
      if (amountMyrMinor != null) 'amount_myr_minor': amountMyrMinor,
      if (transactionDate != null) 'transaction_date': transactionDate,
      if (note != null) 'note': note,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (tripId != null) 'trip_id': tripId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? categoryId,
    Value<String>? type,
    Value<int>? amountMinor,
    Value<String>? currencyCode,
    Value<String>? exchangeRateSnapshot,
    Value<int>? amountMyrMinor,
    Value<String>? transactionDate,
    Value<String?>? note,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<String>? tripId,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRateSnapshot: exchangeRateSnapshot ?? this.exchangeRateSnapshot,
      amountMyrMinor: amountMyrMinor ?? this.amountMyrMinor,
      transactionDate: transactionDate ?? this.transactionDate,
      note: note ?? this.note,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      tripId: tripId ?? this.tripId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (exchangeRateSnapshot.present) {
      map['exchange_rate_snapshot'] = Variable<String>(
        exchangeRateSnapshot.value,
      );
    }
    if (amountMyrMinor.present) {
      map['amount_myr_minor'] = Variable<int>(amountMyrMinor.value);
    }
    if (transactionDate.present) {
      map['transaction_date'] = Variable<String>(transactionDate.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('exchangeRateSnapshot: $exchangeRateSnapshot, ')
          ..write('amountMyrMinor: $amountMyrMinor, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('note: $note, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('tripId: $tripId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AppSettings extends Table with TableInfo<AppSettings, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AppSettings(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL PRIMARY KEY CHECK (length("key") BETWEEN 1 AND 80)',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(value) <= 4000)',
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  AppSettings createAlias(String alias) {
    return AppSettings(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SharedSessions extends Table
    with TableInfo<SharedSessions, SharedSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SharedSessions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (role IN (\'host\', \'guest\'))',
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES trips(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _secretMeta = const VerificationMeta('secret');
  late final GeneratedColumn<String> secret = GeneratedColumn<String>(
    'secret',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _endpointMeta = const VerificationMeta(
    'endpoint',
  );
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
    'endpoint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _cacheMeta = const VerificationMeta('cache');
  late final GeneratedColumn<String> cache = GeneratedColumn<String>(
    'cache',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    role,
    tripId,
    name,
    secret,
    endpoint,
    cache,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('secret')) {
      context.handle(
        _secretMeta,
        secret.isAcceptableOrUnknown(data['secret']!, _secretMeta),
      );
    } else if (isInserting) {
      context.missing(_secretMeta);
    }
    if (data.containsKey('endpoint')) {
      context.handle(
        _endpointMeta,
        endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta),
      );
    } else if (isInserting) {
      context.missing(_endpointMeta);
    }
    if (data.containsKey('cache')) {
      context.handle(
        _cacheMeta,
        cache.isAcceptableOrUnknown(data['cache']!, _cacheMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SharedSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      secret: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secret'],
      )!,
      endpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}endpoint'],
      )!,
      cache: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache'],
      ),
    );
  }

  @override
  SharedSessions createAlias(String alias) {
    return SharedSessions(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'CHECK((role = \'host\' AND trip_id IS NOT NULL)OR(role = \'guest\' AND trip_id IS NULL))',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class SharedSession extends DataClass implements Insertable<SharedSession> {
  final String id;
  final String role;
  final String? tripId;
  final String name;
  final String secret;
  final String endpoint;
  final String? cache;
  const SharedSession({
    required this.id,
    required this.role,
    this.tripId,
    required this.name,
    required this.secret,
    required this.endpoint,
    this.cache,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<String>(tripId);
    }
    map['name'] = Variable<String>(name);
    map['secret'] = Variable<String>(secret);
    map['endpoint'] = Variable<String>(endpoint);
    if (!nullToAbsent || cache != null) {
      map['cache'] = Variable<String>(cache);
    }
    return map;
  }

  SharedSessionsCompanion toCompanion(bool nullToAbsent) {
    return SharedSessionsCompanion(
      id: Value(id),
      role: Value(role),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      name: Value(name),
      secret: Value(secret),
      endpoint: Value(endpoint),
      cache: cache == null && nullToAbsent
          ? const Value.absent()
          : Value(cache),
    );
  }

  factory SharedSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedSession(
      id: serializer.fromJson<String>(json['id']),
      role: serializer.fromJson<String>(json['role']),
      tripId: serializer.fromJson<String?>(json['trip_id']),
      name: serializer.fromJson<String>(json['name']),
      secret: serializer.fromJson<String>(json['secret']),
      endpoint: serializer.fromJson<String>(json['endpoint']),
      cache: serializer.fromJson<String?>(json['cache']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'role': serializer.toJson<String>(role),
      'trip_id': serializer.toJson<String?>(tripId),
      'name': serializer.toJson<String>(name),
      'secret': serializer.toJson<String>(secret),
      'endpoint': serializer.toJson<String>(endpoint),
      'cache': serializer.toJson<String?>(cache),
    };
  }

  SharedSession copyWith({
    String? id,
    String? role,
    Value<String?> tripId = const Value.absent(),
    String? name,
    String? secret,
    String? endpoint,
    Value<String?> cache = const Value.absent(),
  }) => SharedSession(
    id: id ?? this.id,
    role: role ?? this.role,
    tripId: tripId.present ? tripId.value : this.tripId,
    name: name ?? this.name,
    secret: secret ?? this.secret,
    endpoint: endpoint ?? this.endpoint,
    cache: cache.present ? cache.value : this.cache,
  );
  SharedSession copyWithCompanion(SharedSessionsCompanion data) {
    return SharedSession(
      id: data.id.present ? data.id.value : this.id,
      role: data.role.present ? data.role.value : this.role,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      name: data.name.present ? data.name.value : this.name,
      secret: data.secret.present ? data.secret.value : this.secret,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      cache: data.cache.present ? data.cache.value : this.cache,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedSession(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('tripId: $tripId, ')
          ..write('name: $name, ')
          ..write('secret: $secret, ')
          ..write('endpoint: $endpoint, ')
          ..write('cache: $cache')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, role, tripId, name, secret, endpoint, cache);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedSession &&
          other.id == this.id &&
          other.role == this.role &&
          other.tripId == this.tripId &&
          other.name == this.name &&
          other.secret == this.secret &&
          other.endpoint == this.endpoint &&
          other.cache == this.cache);
}

class SharedSessionsCompanion extends UpdateCompanion<SharedSession> {
  final Value<String> id;
  final Value<String> role;
  final Value<String?> tripId;
  final Value<String> name;
  final Value<String> secret;
  final Value<String> endpoint;
  final Value<String?> cache;
  final Value<int> rowid;
  const SharedSessionsCompanion({
    this.id = const Value.absent(),
    this.role = const Value.absent(),
    this.tripId = const Value.absent(),
    this.name = const Value.absent(),
    this.secret = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.cache = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedSessionsCompanion.insert({
    required String id,
    required String role,
    this.tripId = const Value.absent(),
    required String name,
    required String secret,
    required String endpoint,
    this.cache = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       role = Value(role),
       name = Value(name),
       secret = Value(secret),
       endpoint = Value(endpoint);
  static Insertable<SharedSession> custom({
    Expression<String>? id,
    Expression<String>? role,
    Expression<String>? tripId,
    Expression<String>? name,
    Expression<String>? secret,
    Expression<String>? endpoint,
    Expression<String>? cache,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (role != null) 'role': role,
      if (tripId != null) 'trip_id': tripId,
      if (name != null) 'name': name,
      if (secret != null) 'secret': secret,
      if (endpoint != null) 'endpoint': endpoint,
      if (cache != null) 'cache': cache,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? role,
    Value<String?>? tripId,
    Value<String>? name,
    Value<String>? secret,
    Value<String>? endpoint,
    Value<String?>? cache,
    Value<int>? rowid,
  }) {
    return SharedSessionsCompanion(
      id: id ?? this.id,
      role: role ?? this.role,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      secret: secret ?? this.secret,
      endpoint: endpoint ?? this.endpoint,
      cache: cache ?? this.cache,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (secret.present) {
      map['secret'] = Variable<String>(secret.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (cache.present) {
      map['cache'] = Variable<String>(cache.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedSessionsCompanion(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('tripId: $tripId, ')
          ..write('name: $name, ')
          ..write('secret: $secret, ')
          ..write('endpoint: $endpoint, ')
          ..write('cache: $cache, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SharedPending extends Table
    with TableInfo<SharedPending, SharedPendingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SharedPending(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES shared_sessions(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, payload, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_pending';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedPendingData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SharedPendingData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedPendingData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  SharedPending createAlias(String alias) {
    return SharedPending(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SharedPendingData extends DataClass
    implements Insertable<SharedPendingData> {
  final String id;
  final String sessionId;
  final String payload;
  final int createdAt;
  const SharedPendingData({
    required this.id,
    required this.sessionId,
    required this.payload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SharedPendingCompanion toCompanion(bool nullToAbsent) {
    return SharedPendingCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      payload: Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory SharedPendingData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedPendingData(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['session_id']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<int>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'session_id': serializer.toJson<String>(sessionId),
      'payload': serializer.toJson<String>(payload),
      'created_at': serializer.toJson<int>(createdAt),
    };
  }

  SharedPendingData copyWith({
    String? id,
    String? sessionId,
    String? payload,
    int? createdAt,
  }) => SharedPendingData(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
  SharedPendingData copyWithCompanion(SharedPendingCompanion data) {
    return SharedPendingData(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedPendingData(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedPendingData &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class SharedPendingCompanion extends UpdateCompanion<SharedPendingData> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> payload;
  final Value<int> createdAt;
  final Value<int> rowid;
  const SharedPendingCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedPendingCompanion.insert({
    required String id,
    required String sessionId,
    required String payload,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<SharedPendingData> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? payload,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedPendingCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? payload,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return SharedPendingCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedPendingCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SharedReceipts extends Table
    with TableInfo<SharedReceipts, SharedReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SharedReceipts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES shared_sessions(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [sessionId, requestId, transactionId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedReceipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, requestId};
  @override
  SharedReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedReceipt(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      )!,
    );
  }

  @override
  SharedReceipts createAlias(String alias) {
    return SharedReceipts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(session_id, request_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class SharedReceipt extends DataClass implements Insertable<SharedReceipt> {
  final String sessionId;
  final String requestId;
  final String transactionId;
  const SharedReceipt({
    required this.sessionId,
    required this.requestId,
    required this.transactionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['request_id'] = Variable<String>(requestId);
    map['transaction_id'] = Variable<String>(transactionId);
    return map;
  }

  SharedReceiptsCompanion toCompanion(bool nullToAbsent) {
    return SharedReceiptsCompanion(
      sessionId: Value(sessionId),
      requestId: Value(requestId),
      transactionId: Value(transactionId),
    );
  }

  factory SharedReceipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedReceipt(
      sessionId: serializer.fromJson<String>(json['session_id']),
      requestId: serializer.fromJson<String>(json['request_id']),
      transactionId: serializer.fromJson<String>(json['transaction_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'session_id': serializer.toJson<String>(sessionId),
      'request_id': serializer.toJson<String>(requestId),
      'transaction_id': serializer.toJson<String>(transactionId),
    };
  }

  SharedReceipt copyWith({
    String? sessionId,
    String? requestId,
    String? transactionId,
  }) => SharedReceipt(
    sessionId: sessionId ?? this.sessionId,
    requestId: requestId ?? this.requestId,
    transactionId: transactionId ?? this.transactionId,
  );
  SharedReceipt copyWithCompanion(SharedReceiptsCompanion data) {
    return SharedReceipt(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedReceipt(')
          ..write('sessionId: $sessionId, ')
          ..write('requestId: $requestId, ')
          ..write('transactionId: $transactionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, requestId, transactionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedReceipt &&
          other.sessionId == this.sessionId &&
          other.requestId == this.requestId &&
          other.transactionId == this.transactionId);
}

class SharedReceiptsCompanion extends UpdateCompanion<SharedReceipt> {
  final Value<String> sessionId;
  final Value<String> requestId;
  final Value<String> transactionId;
  final Value<int> rowid;
  const SharedReceiptsCompanion({
    this.sessionId = const Value.absent(),
    this.requestId = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedReceiptsCompanion.insert({
    required String sessionId,
    required String requestId,
    required String transactionId,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       requestId = Value(requestId),
       transactionId = Value(transactionId);
  static Insertable<SharedReceipt> custom({
    Expression<String>? sessionId,
    Expression<String>? requestId,
    Expression<String>? transactionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (requestId != null) 'request_id': requestId,
      if (transactionId != null) 'transaction_id': transactionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedReceiptsCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? requestId,
    Value<String>? transactionId,
    Value<int>? rowid,
  }) {
    return SharedReceiptsCompanion(
      sessionId: sessionId ?? this.sessionId,
      requestId: requestId ?? this.requestId,
      transactionId: transactionId ?? this.transactionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedReceiptsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('requestId: $requestId, ')
          ..write('transactionId: $transactionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final Categories categories = Categories(this);
  late final Currencies currencies = Currencies(this);
  late final Trips trips = Trips(this);
  late final CurrencyRates currencyRates = CurrencyRates(this);
  late final TripRates tripRates = TripRates(this);
  late final Transactions transactions = Transactions(this);
  late final AppSettings appSettings = AppSettings(this);
  late final Index transactionsTripDateIdx = Index(
    'transactions_trip_date_idx',
    'CREATE INDEX transactions_trip_date_idx ON transactions (trip_id, transaction_date DESC, id)',
  );
  late final Index transactionsDateIdx = Index(
    'transactions_date_idx',
    'CREATE INDEX transactions_date_idx ON transactions (transaction_date DESC, id)',
  );
  late final Index transactionsCategoryDateIdx = Index(
    'transactions_category_date_idx',
    'CREATE INDEX transactions_category_date_idx ON transactions (category_id, transaction_date)',
  );
  late final Index transactionsCurrencyDateIdx = Index(
    'transactions_currency_date_idx',
    'CREATE INDEX transactions_currency_date_idx ON transactions (currency_code, transaction_date)',
  );
  late final Index transactionsTypeDateIdx = Index(
    'transactions_type_date_idx',
    'CREATE INDEX transactions_type_date_idx ON transactions (type, transaction_date)',
  );
  late final Trigger protectMyrDelete = Trigger(
    'CREATE TRIGGER protect_myr_delete BEFORE DELETE ON currencies WHEN OLD.code = \'MYR\' BEGIN SELECT RAISE (ABORT, \'MYR cannot be deleted\');END',
    'protect_myr_delete',
  );
  late final Trigger protectMyrCode = Trigger(
    'CREATE TRIGGER protect_myr_code BEFORE UPDATE OF code ON currencies WHEN OLD.code = \'MYR\' AND NEW.code <> OLD.code BEGIN SELECT RAISE (ABORT, \'MYR code cannot change\');END',
    'protect_myr_code',
  );
  late final Trigger protectUsedCurrency = Trigger(
    'CREATE TRIGGER protect_used_currency BEFORE UPDATE OF code, decimal_places ON currencies WHEN(NEW.code <> OLD.code OR NEW.decimal_places <> OLD.decimal_places)AND EXISTS (SELECT 1 FROM transactions WHERE currency_code = OLD.code) BEGIN SELECT RAISE (ABORT, \'Used currency code and precision cannot change\');END',
    'protect_used_currency',
  );
  late final Trigger protectUsedCategoryType = Trigger(
    'CREATE TRIGGER protect_used_category_type BEFORE UPDATE OF type ON categories WHEN NEW.type <> OLD.type AND EXISTS (SELECT 1 FROM transactions WHERE category_id = OLD.id) BEGIN SELECT RAISE (ABORT, \'Used category type cannot change\');END',
    'protect_used_category_type',
  );
  late final Trigger validateTransactionInsert = Trigger(
    'CREATE TRIGGER validate_transaction_insert BEFORE INSERT ON transactions WHEN NOT EXISTS (SELECT 1 FROM categories WHERE id = NEW.category_id AND type = NEW.type) BEGIN SELECT RAISE (ABORT, \'Transaction category must match its type\');END',
    'validate_transaction_insert',
  );
  late final Trigger validateTransactionUpdate = Trigger(
    'CREATE TRIGGER validate_transaction_update BEFORE UPDATE OF category_id, type ON transactions WHEN NOT EXISTS (SELECT 1 FROM categories WHERE id = NEW.category_id AND type = NEW.type) BEGIN SELECT RAISE (ABORT, \'Transaction category must match its type\');END',
    'validate_transaction_update',
  );
  late final SharedSessions sharedSessions = SharedSessions(this);
  late final SharedPending sharedPending = SharedPending(this);
  late final SharedReceipts sharedReceipts = SharedReceipts(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    currencies,
    trips,
    currencyRates,
    tripRates,
    transactions,
    appSettings,
    transactionsTripDateIdx,
    transactionsDateIdx,
    transactionsCategoryDateIdx,
    transactionsCurrencyDateIdx,
    transactionsTypeDateIdx,
    protectMyrDelete,
    protectMyrCode,
    protectUsedCurrency,
    protectUsedCategoryType,
    validateTransactionInsert,
    validateTransactionUpdate,
    sharedSessions,
    sharedPending,
    sharedReceipts,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'currencies',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('currency_rates', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_rates', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'currencies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_rates', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'currencies',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('trip_rates', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'currencies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'currencies',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'currencies',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'categories',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transactions',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transactions',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shared_sessions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'shared_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shared_pending', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'shared_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shared_receipts', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $CategoriesCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String id,
      required String name,
      required String type,
      required String iconKey,
      required String colorHex,
      Value<int> sortOrder,
      Value<bool> isArchived,
      Value<int> rowid,
    });
typedef $CategoriesUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String> iconKey,
      Value<String> colorHex,
      Value<int> sortOrder,
      Value<bool> isArchived,
      Value<int> rowid,
    });

final class $CategoriesReferences
    extends BaseReferences<_$AppDatabase, Categories, Category> {
  $CategoriesReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<Transactions, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'categories__id__transactions__category_id',
  );

  $TransactionsProcessedTableManager get transactionsRefs {
    final manager = $TransactionsTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $CategoriesFilterComposer extends Composer<_$AppDatabase, Categories> {
  $CategoriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionsRefs(
    Expression<bool> Function($TransactionsFilterComposer f) f,
  ) {
    final $TransactionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TransactionsFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $CategoriesOrderingComposer extends Composer<_$AppDatabase, Categories> {
  $CategoriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $CategoriesAnnotationComposer
    extends Composer<_$AppDatabase, Categories> {
  $CategoriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($TransactionsAnnotationComposer a) f,
  ) {
    final $TransactionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TransactionsAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $CategoriesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Categories,
          Category,
          $CategoriesFilterComposer,
          $CategoriesOrderingComposer,
          $CategoriesAnnotationComposer,
          $CategoriesCreateCompanionBuilder,
          $CategoriesUpdateCompanionBuilder,
          (Category, $CategoriesReferences),
          Category,
          PrefetchHooks Function({bool transactionsRefs})
        > {
  $CategoriesTableManager(_$AppDatabase db, Categories table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CategoriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CategoriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CategoriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> iconKey = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                type: type,
                iconKey: iconKey,
                colorHex: colorHex,
                sortOrder: sortOrder,
                isArchived: isArchived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                required String iconKey,
                required String colorHex,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                type: type,
                iconKey: iconKey,
                colorHex: colorHex,
                sortOrder: sortOrder,
                isArchived: isArchived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Categories, Category>(table),
                  $CategoriesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (transactionsRefs) db.transactions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionsRefs)
                    await $_getPrefetchedDataByColumns<
                      Category,
                      Categories,
                      Transaction,
                      Transactions
                    >(
                      currentTable: table,
                      referencedTable: $CategoriesReferences
                          ._transactionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $CategoriesReferences(db, table, p0).transactionsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'category_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $CategoriesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Categories,
      Category,
      $CategoriesFilterComposer,
      $CategoriesOrderingComposer,
      $CategoriesAnnotationComposer,
      $CategoriesCreateCompanionBuilder,
      $CategoriesUpdateCompanionBuilder,
      (Category, $CategoriesReferences),
      Category,
      PrefetchHooks Function({bool transactionsRefs})
    >;
typedef $CurrenciesCreateCompanionBuilder =
    CurrenciesCompanion Function({
      required String code,
      required String name,
      required String symbol,
      required int decimalPlaces,
      required String rateToMyr,
      Value<bool> isActive,
      required int createdAtUtc,
      required int updatedAtUtc,
      Value<int> rowid,
    });
typedef $CurrenciesUpdateCompanionBuilder =
    CurrenciesCompanion Function({
      Value<String> code,
      Value<String> name,
      Value<String> symbol,
      Value<int> decimalPlaces,
      Value<String> rateToMyr,
      Value<bool> isActive,
      Value<int> createdAtUtc,
      Value<int> updatedAtUtc,
      Value<int> rowid,
    });

final class $CurrenciesReferences
    extends BaseReferences<_$AppDatabase, Currencies, Currency> {
  $CurrenciesReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<CurrencyRates, List<CurrencyRate>>
  _currencyRatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.currencyRates,
    aliasName: 'currencies__code__currency_rates__currency_code',
  );

  $CurrencyRatesProcessedTableManager get currencyRatesRefs {
    final manager = $CurrencyRatesTableManager($_db, $_db.currencyRates).filter(
      (f) => f.currencyCode.code.sqlEquals($_itemColumn<String>('code')!),
    );

    final cache = $_typedResult.readTableOrNull(_currencyRatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<TripRates, List<TripRate>> _tripRatesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tripRates,
    aliasName: 'currencies__code__trip_rates__currency_code',
  );

  $TripRatesProcessedTableManager get tripRatesRefs {
    final manager = $TripRatesTableManager($_db, $_db.tripRates).filter(
      (f) => f.currencyCode.code.sqlEquals($_itemColumn<String>('code')!),
    );

    final cache = $_typedResult.readTableOrNull(_tripRatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<Transactions, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'currencies__code__transactions__currency_code',
  );

  $TransactionsProcessedTableManager get transactionsRefs {
    final manager = $TransactionsTableManager($_db, $_db.transactions).filter(
      (f) => f.currencyCode.code.sqlEquals($_itemColumn<String>('code')!),
    );

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $CurrenciesFilterComposer extends Composer<_$AppDatabase, Currencies> {
  $CurrenciesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get decimalPlaces => $composableBuilder(
    column: $table.decimalPlaces,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rateToMyr => $composableBuilder(
    column: $table.rateToMyr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> currencyRatesRefs(
    Expression<bool> Function($CurrencyRatesFilterComposer f) f,
  ) {
    final $CurrencyRatesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.code,
      referencedTable: $db.currencyRates,
      getReferencedColumn: (t) => t.currencyCode,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrencyRatesFilterComposer(
            $db: $db,
            $table: $db.currencyRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tripRatesRefs(
    Expression<bool> Function($TripRatesFilterComposer f) f,
  ) {
    final $TripRatesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.code,
      referencedTable: $db.tripRates,
      getReferencedColumn: (t) => t.currencyCode,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripRatesFilterComposer(
            $db: $db,
            $table: $db.tripRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($TransactionsFilterComposer f) f,
  ) {
    final $TransactionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.code,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.currencyCode,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TransactionsFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $CurrenciesOrderingComposer extends Composer<_$AppDatabase, Currencies> {
  $CurrenciesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get decimalPlaces => $composableBuilder(
    column: $table.decimalPlaces,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rateToMyr => $composableBuilder(
    column: $table.rateToMyr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $CurrenciesAnnotationComposer
    extends Composer<_$AppDatabase, Currencies> {
  $CurrenciesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<int> get decimalPlaces => $composableBuilder(
    column: $table.decimalPlaces,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rateToMyr =>
      $composableBuilder(column: $table.rateToMyr, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  Expression<T> currencyRatesRefs<T extends Object>(
    Expression<T> Function($CurrencyRatesAnnotationComposer a) f,
  ) {
    final $CurrencyRatesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.code,
      referencedTable: $db.currencyRates,
      getReferencedColumn: (t) => t.currencyCode,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrencyRatesAnnotationComposer(
            $db: $db,
            $table: $db.currencyRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tripRatesRefs<T extends Object>(
    Expression<T> Function($TripRatesAnnotationComposer a) f,
  ) {
    final $TripRatesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.code,
      referencedTable: $db.tripRates,
      getReferencedColumn: (t) => t.currencyCode,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripRatesAnnotationComposer(
            $db: $db,
            $table: $db.tripRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($TransactionsAnnotationComposer a) f,
  ) {
    final $TransactionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.code,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.currencyCode,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TransactionsAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $CurrenciesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Currencies,
          Currency,
          $CurrenciesFilterComposer,
          $CurrenciesOrderingComposer,
          $CurrenciesAnnotationComposer,
          $CurrenciesCreateCompanionBuilder,
          $CurrenciesUpdateCompanionBuilder,
          (Currency, $CurrenciesReferences),
          Currency,
          PrefetchHooks Function({
            bool currencyRatesRefs,
            bool tripRatesRefs,
            bool transactionsRefs,
          })
        > {
  $CurrenciesTableManager(_$AppDatabase db, Currencies table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CurrenciesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CurrenciesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CurrenciesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<int> decimalPlaces = const Value.absent(),
                Value<String> rateToMyr = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurrenciesCompanion(
                code: code,
                name: name,
                symbol: symbol,
                decimalPlaces: decimalPlaces,
                rateToMyr: rateToMyr,
                isActive: isActive,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String code,
                required String name,
                required String symbol,
                required int decimalPlaces,
                required String rateToMyr,
                Value<bool> isActive = const Value.absent(),
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => CurrenciesCompanion.insert(
                code: code,
                name: name,
                symbol: symbol,
                decimalPlaces: decimalPlaces,
                rateToMyr: rateToMyr,
                isActive: isActive,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Currencies, Currency>(table),
                  $CurrenciesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                currencyRatesRefs = false,
                tripRatesRefs = false,
                transactionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (currencyRatesRefs) db.currencyRates,
                    if (tripRatesRefs) db.tripRates,
                    if (transactionsRefs) db.transactions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (currencyRatesRefs)
                        await $_getPrefetchedDataByColumns<
                          Currency,
                          Currencies,
                          CurrencyRate,
                          CurrencyRates
                        >(
                          currentTable: table,
                          referencedTable: $CurrenciesReferences
                              ._currencyRatesRefsTable(db),
                          managerFromTypedResult: (p0) => $CurrenciesReferences(
                            db,
                            table,
                            p0,
                          ).currencyRatesRefs,
                          currentColumn: 'code',
                          referencedColumn: 'currency_code',
                          typedResults: items,
                        ),
                      if (tripRatesRefs)
                        await $_getPrefetchedDataByColumns<
                          Currency,
                          Currencies,
                          TripRate,
                          TripRates
                        >(
                          currentTable: table,
                          referencedTable: $CurrenciesReferences
                              ._tripRatesRefsTable(db),
                          managerFromTypedResult: (p0) => $CurrenciesReferences(
                            db,
                            table,
                            p0,
                          ).tripRatesRefs,
                          currentColumn: 'code',
                          referencedColumn: 'currency_code',
                          typedResults: items,
                        ),
                      if (transactionsRefs)
                        await $_getPrefetchedDataByColumns<
                          Currency,
                          Currencies,
                          Transaction,
                          Transactions
                        >(
                          currentTable: table,
                          referencedTable: $CurrenciesReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) => $CurrenciesReferences(
                            db,
                            table,
                            p0,
                          ).transactionsRefs,
                          currentColumn: 'code',
                          referencedColumn: 'currency_code',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $CurrenciesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Currencies,
      Currency,
      $CurrenciesFilterComposer,
      $CurrenciesOrderingComposer,
      $CurrenciesAnnotationComposer,
      $CurrenciesCreateCompanionBuilder,
      $CurrenciesUpdateCompanionBuilder,
      (Currency, $CurrenciesReferences),
      Currency,
      PrefetchHooks Function({
        bool currencyRatesRefs,
        bool tripRatesRefs,
        bool transactionsRefs,
      })
    >;
typedef $TripsCreateCompanionBuilder =
    TripsCompanion Function({
      required String id,
      required String name,
      Value<int> rowid,
    });
typedef $TripsUpdateCompanionBuilder =
    TripsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> rowid,
    });

final class $TripsReferences
    extends BaseReferences<_$AppDatabase, Trips, Trip> {
  $TripsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<TripRates, List<TripRate>> _tripRatesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tripRates,
    aliasName: 'trips__id__trip_rates__trip_id',
  );

  $TripRatesProcessedTableManager get tripRatesRefs {
    final manager = $TripRatesTableManager(
      $_db,
      $_db.tripRates,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripRatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<Transactions, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'trips__id__transactions__trip_id',
  );

  $TransactionsProcessedTableManager get transactionsRefs {
    final manager = $TransactionsTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<SharedSessions, List<SharedSession>>
  _sharedSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sharedSessions,
    aliasName: 'trips__id__shared_sessions__trip_id',
  );

  $SharedSessionsProcessedTableManager get sharedSessionsRefs {
    final manager = $SharedSessionsTableManager(
      $_db,
      $_db.sharedSessions,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sharedSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $TripsFilterComposer extends Composer<_$AppDatabase, Trips> {
  $TripsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tripRatesRefs(
    Expression<bool> Function($TripRatesFilterComposer f) f,
  ) {
    final $TripRatesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripRates,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripRatesFilterComposer(
            $db: $db,
            $table: $db.tripRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($TransactionsFilterComposer f) f,
  ) {
    final $TransactionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TransactionsFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sharedSessionsRefs(
    Expression<bool> Function($SharedSessionsFilterComposer f) f,
  ) {
    final $SharedSessionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sharedSessions,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SharedSessionsFilterComposer(
            $db: $db,
            $table: $db.sharedSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $TripsOrderingComposer extends Composer<_$AppDatabase, Trips> {
  $TripsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $TripsAnnotationComposer extends Composer<_$AppDatabase, Trips> {
  $TripsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> tripRatesRefs<T extends Object>(
    Expression<T> Function($TripRatesAnnotationComposer a) f,
  ) {
    final $TripRatesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripRates,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripRatesAnnotationComposer(
            $db: $db,
            $table: $db.tripRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($TransactionsAnnotationComposer a) f,
  ) {
    final $TransactionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TransactionsAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> sharedSessionsRefs<T extends Object>(
    Expression<T> Function($SharedSessionsAnnotationComposer a) f,
  ) {
    final $SharedSessionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sharedSessions,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SharedSessionsAnnotationComposer(
            $db: $db,
            $table: $db.sharedSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $TripsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Trips,
          Trip,
          $TripsFilterComposer,
          $TripsOrderingComposer,
          $TripsAnnotationComposer,
          $TripsCreateCompanionBuilder,
          $TripsUpdateCompanionBuilder,
          (Trip, $TripsReferences),
          Trip,
          PrefetchHooks Function({
            bool tripRatesRefs,
            bool transactionsRefs,
            bool sharedSessionsRefs,
          })
        > {
  $TripsTableManager(_$AppDatabase db, Trips table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $TripsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $TripsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $TripsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripsCompanion(id: id, name: name, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => TripsCompanion.insert(id: id, name: name, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Trips, Trip>(table),
                  $TripsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tripRatesRefs = false,
                transactionsRefs = false,
                sharedSessionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (tripRatesRefs) db.tripRates,
                    if (transactionsRefs) db.transactions,
                    if (sharedSessionsRefs) db.sharedSessions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tripRatesRefs)
                        await $_getPrefetchedDataByColumns<
                          Trip,
                          Trips,
                          TripRate,
                          TripRates
                        >(
                          currentTable: table,
                          referencedTable: $TripsReferences._tripRatesRefsTable(
                            db,
                          ),
                          managerFromTypedResult: (p0) =>
                              $TripsReferences(db, table, p0).tripRatesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'trip_id',
                          typedResults: items,
                        ),
                      if (transactionsRefs)
                        await $_getPrefetchedDataByColumns<
                          Trip,
                          Trips,
                          Transaction,
                          Transactions
                        >(
                          currentTable: table,
                          referencedTable: $TripsReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $TripsReferences(db, table, p0).transactionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'trip_id',
                          typedResults: items,
                        ),
                      if (sharedSessionsRefs)
                        await $_getPrefetchedDataByColumns<
                          Trip,
                          Trips,
                          SharedSession,
                          SharedSessions
                        >(
                          currentTable: table,
                          referencedTable: $TripsReferences
                              ._sharedSessionsRefsTable(db),
                          managerFromTypedResult: (p0) => $TripsReferences(
                            db,
                            table,
                            p0,
                          ).sharedSessionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'trip_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $TripsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Trips,
      Trip,
      $TripsFilterComposer,
      $TripsOrderingComposer,
      $TripsAnnotationComposer,
      $TripsCreateCompanionBuilder,
      $TripsUpdateCompanionBuilder,
      (Trip, $TripsReferences),
      Trip,
      PrefetchHooks Function({
        bool tripRatesRefs,
        bool transactionsRefs,
        bool sharedSessionsRefs,
      })
    >;
typedef $CurrencyRatesCreateCompanionBuilder =
    CurrencyRatesCompanion Function({
      required String id,
      required String currencyCode,
      required String name,
      required String rateToMyr,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $CurrencyRatesUpdateCompanionBuilder =
    CurrencyRatesCompanion Function({
      Value<String> id,
      Value<String> currencyCode,
      Value<String> name,
      Value<String> rateToMyr,
      Value<bool> isActive,
      Value<int> rowid,
    });

final class $CurrencyRatesReferences
    extends BaseReferences<_$AppDatabase, CurrencyRates, CurrencyRate> {
  $CurrencyRatesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Currencies _currencyCodeTable(_$AppDatabase db) => db.currencies
      .createAlias('currency_rates__currency_code__currencies__code');

  $CurrenciesProcessedTableManager get currencyCode {
    final $_column = $_itemColumn<String>('currency_code')!;

    final manager = $CurrenciesTableManager(
      $_db,
      $_db.currencies,
    ).filter((f) => f.code.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_currencyCodeTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<TripRates, List<TripRate>> _tripRatesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tripRates,
    aliasName: 'currency_rates__id__trip_rates__rate_id',
  );

  $TripRatesProcessedTableManager get tripRatesRefs {
    final manager = $TripRatesTableManager(
      $_db,
      $_db.tripRates,
    ).filter((f) => f.rateId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripRatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $CurrencyRatesFilterComposer
    extends Composer<_$AppDatabase, CurrencyRates> {
  $CurrencyRatesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rateToMyr => $composableBuilder(
    column: $table.rateToMyr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  $CurrenciesFilterComposer get currencyCode {
    final $CurrenciesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currencyCode,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.code,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrenciesFilterComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> tripRatesRefs(
    Expression<bool> Function($TripRatesFilterComposer f) f,
  ) {
    final $TripRatesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripRates,
      getReferencedColumn: (t) => t.rateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripRatesFilterComposer(
            $db: $db,
            $table: $db.tripRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $CurrencyRatesOrderingComposer
    extends Composer<_$AppDatabase, CurrencyRates> {
  $CurrencyRatesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rateToMyr => $composableBuilder(
    column: $table.rateToMyr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  $CurrenciesOrderingComposer get currencyCode {
    final $CurrenciesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currencyCode,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.code,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrenciesOrderingComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $CurrencyRatesAnnotationComposer
    extends Composer<_$AppDatabase, CurrencyRates> {
  $CurrencyRatesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get rateToMyr =>
      $composableBuilder(column: $table.rateToMyr, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  $CurrenciesAnnotationComposer get currencyCode {
    final $CurrenciesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currencyCode,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.code,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrenciesAnnotationComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> tripRatesRefs<T extends Object>(
    Expression<T> Function($TripRatesAnnotationComposer a) f,
  ) {
    final $TripRatesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripRates,
      getReferencedColumn: (t) => t.rateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripRatesAnnotationComposer(
            $db: $db,
            $table: $db.tripRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $CurrencyRatesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          CurrencyRates,
          CurrencyRate,
          $CurrencyRatesFilterComposer,
          $CurrencyRatesOrderingComposer,
          $CurrencyRatesAnnotationComposer,
          $CurrencyRatesCreateCompanionBuilder,
          $CurrencyRatesUpdateCompanionBuilder,
          (CurrencyRate, $CurrencyRatesReferences),
          CurrencyRate,
          PrefetchHooks Function({bool currencyCode, bool tripRatesRefs})
        > {
  $CurrencyRatesTableManager(_$AppDatabase db, CurrencyRates table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CurrencyRatesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CurrencyRatesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CurrencyRatesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> rateToMyr = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurrencyRatesCompanion(
                id: id,
                currencyCode: currencyCode,
                name: name,
                rateToMyr: rateToMyr,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String currencyCode,
                required String name,
                required String rateToMyr,
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurrencyRatesCompanion.insert(
                id: id,
                currencyCode: currencyCode,
                name: name,
                rateToMyr: rateToMyr,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<CurrencyRates, CurrencyRate>(table),
                  $CurrencyRatesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({currencyCode = false, tripRatesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (tripRatesRefs) db.tripRates],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (currencyCode) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.currencyCode,
                                    referencedTable: $CurrencyRatesReferences
                                        ._currencyCodeTable(db),
                                    referencedColumn: $CurrencyRatesReferences
                                        ._currencyCodeTable(db)
                                        .code,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tripRatesRefs)
                        await $_getPrefetchedDataByColumns<
                          CurrencyRate,
                          CurrencyRates,
                          TripRate,
                          TripRates
                        >(
                          currentTable: table,
                          referencedTable: $CurrencyRatesReferences
                              ._tripRatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $CurrencyRatesReferences(
                                db,
                                table,
                                p0,
                              ).tripRatesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'rate_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $CurrencyRatesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      CurrencyRates,
      CurrencyRate,
      $CurrencyRatesFilterComposer,
      $CurrencyRatesOrderingComposer,
      $CurrencyRatesAnnotationComposer,
      $CurrencyRatesCreateCompanionBuilder,
      $CurrencyRatesUpdateCompanionBuilder,
      (CurrencyRate, $CurrencyRatesReferences),
      CurrencyRate,
      PrefetchHooks Function({bool currencyCode, bool tripRatesRefs})
    >;
typedef $TripRatesCreateCompanionBuilder =
    TripRatesCompanion Function({
      required String tripId,
      required String currencyCode,
      required String rateToMyr,
      Value<String?> name,
      Value<String?> rateId,
      Value<int> rowid,
    });
typedef $TripRatesUpdateCompanionBuilder =
    TripRatesCompanion Function({
      Value<String> tripId,
      Value<String> currencyCode,
      Value<String> rateToMyr,
      Value<String?> name,
      Value<String?> rateId,
      Value<int> rowid,
    });

final class $TripRatesReferences
    extends BaseReferences<_$AppDatabase, TripRates, TripRate> {
  $TripRatesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Trips _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('trip_rates__trip_id__trips__id');

  $TripsProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $TripsTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static Currencies _currencyCodeTable(_$AppDatabase db) =>
      db.currencies.createAlias('trip_rates__currency_code__currencies__code');

  $CurrenciesProcessedTableManager get currencyCode {
    final $_column = $_itemColumn<String>('currency_code')!;

    final manager = $CurrenciesTableManager(
      $_db,
      $_db.currencies,
    ).filter((f) => f.code.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_currencyCodeTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static CurrencyRates _rateIdTable(_$AppDatabase db) =>
      db.currencyRates.createAlias('trip_rates__rate_id__currency_rates__id');

  $CurrencyRatesProcessedTableManager? get rateId {
    final $_column = $_itemColumn<String>('rate_id');
    if ($_column == null) return null;
    final manager = $CurrencyRatesTableManager(
      $_db,
      $_db.currencyRates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_rateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $TripRatesFilterComposer extends Composer<_$AppDatabase, TripRates> {
  $TripRatesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get rateToMyr => $composableBuilder(
    column: $table.rateToMyr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  $TripsFilterComposer get tripId {
    final $TripsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripsFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $CurrenciesFilterComposer get currencyCode {
    final $CurrenciesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currencyCode,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.code,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrenciesFilterComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $CurrencyRatesFilterComposer get rateId {
    final $CurrencyRatesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rateId,
      referencedTable: $db.currencyRates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrencyRatesFilterComposer(
            $db: $db,
            $table: $db.currencyRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $TripRatesOrderingComposer extends Composer<_$AppDatabase, TripRates> {
  $TripRatesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get rateToMyr => $composableBuilder(
    column: $table.rateToMyr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  $TripsOrderingComposer get tripId {
    final $TripsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripsOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $CurrenciesOrderingComposer get currencyCode {
    final $CurrenciesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currencyCode,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.code,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrenciesOrderingComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $CurrencyRatesOrderingComposer get rateId {
    final $CurrencyRatesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rateId,
      referencedTable: $db.currencyRates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrencyRatesOrderingComposer(
            $db: $db,
            $table: $db.currencyRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $TripRatesAnnotationComposer extends Composer<_$AppDatabase, TripRates> {
  $TripRatesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rateToMyr =>
      $composableBuilder(column: $table.rateToMyr, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  $TripsAnnotationComposer get tripId {
    final $TripsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripsAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $CurrenciesAnnotationComposer get currencyCode {
    final $CurrenciesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currencyCode,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.code,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrenciesAnnotationComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $CurrencyRatesAnnotationComposer get rateId {
    final $CurrencyRatesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rateId,
      referencedTable: $db.currencyRates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrencyRatesAnnotationComposer(
            $db: $db,
            $table: $db.currencyRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $TripRatesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          TripRates,
          TripRate,
          $TripRatesFilterComposer,
          $TripRatesOrderingComposer,
          $TripRatesAnnotationComposer,
          $TripRatesCreateCompanionBuilder,
          $TripRatesUpdateCompanionBuilder,
          (TripRate, $TripRatesReferences),
          TripRate,
          PrefetchHooks Function({bool tripId, bool currencyCode, bool rateId})
        > {
  $TripRatesTableManager(_$AppDatabase db, TripRates table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $TripRatesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $TripRatesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $TripRatesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tripId = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String> rateToMyr = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> rateId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripRatesCompanion(
                tripId: tripId,
                currencyCode: currencyCode,
                rateToMyr: rateToMyr,
                name: name,
                rateId: rateId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tripId,
                required String currencyCode,
                required String rateToMyr,
                Value<String?> name = const Value.absent(),
                Value<String?> rateId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripRatesCompanion.insert(
                tripId: tripId,
                currencyCode: currencyCode,
                rateToMyr: rateToMyr,
                name: name,
                rateId: rateId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<TripRates, TripRate>(table),
                  $TripRatesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({tripId = false, currencyCode = false, rateId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (tripId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.tripId,
                                    referencedTable: $TripRatesReferences
                                        ._tripIdTable(db),
                                    referencedColumn: $TripRatesReferences
                                        ._tripIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (currencyCode) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.currencyCode,
                                    referencedTable: $TripRatesReferences
                                        ._currencyCodeTable(db),
                                    referencedColumn: $TripRatesReferences
                                        ._currencyCodeTable(db)
                                        .code,
                                  )
                                  as T;
                        }
                        if (rateId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.rateId,
                                    referencedTable: $TripRatesReferences
                                        ._rateIdTable(db),
                                    referencedColumn: $TripRatesReferences
                                        ._rateIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $TripRatesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      TripRates,
      TripRate,
      $TripRatesFilterComposer,
      $TripRatesOrderingComposer,
      $TripRatesAnnotationComposer,
      $TripRatesCreateCompanionBuilder,
      $TripRatesUpdateCompanionBuilder,
      (TripRate, $TripRatesReferences),
      TripRate,
      PrefetchHooks Function({bool tripId, bool currencyCode, bool rateId})
    >;
typedef $TransactionsCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      required String categoryId,
      required String type,
      required int amountMinor,
      required String currencyCode,
      required String exchangeRateSnapshot,
      required int amountMyrMinor,
      required String transactionDate,
      Value<String?> note,
      required int createdAtUtc,
      required int updatedAtUtc,
      Value<String> tripId,
      Value<int> rowid,
    });
typedef $TransactionsUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<String> categoryId,
      Value<String> type,
      Value<int> amountMinor,
      Value<String> currencyCode,
      Value<String> exchangeRateSnapshot,
      Value<int> amountMyrMinor,
      Value<String> transactionDate,
      Value<String?> note,
      Value<int> createdAtUtc,
      Value<int> updatedAtUtc,
      Value<String> tripId,
      Value<int> rowid,
    });

final class $TransactionsReferences
    extends BaseReferences<_$AppDatabase, Transactions, Transaction> {
  $TransactionsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Categories _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('transactions__category_id__categories__id');

  $CategoriesProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $CategoriesTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static Currencies _currencyCodeTable(_$AppDatabase db) => db.currencies
      .createAlias('transactions__currency_code__currencies__code');

  $CurrenciesProcessedTableManager get currencyCode {
    final $_column = $_itemColumn<String>('currency_code')!;

    final manager = $CurrenciesTableManager(
      $_db,
      $_db.currencies,
    ).filter((f) => f.code.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_currencyCodeTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static Trips _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('transactions__trip_id__trips__id');

  $TripsProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $TripsTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $TransactionsFilterComposer
    extends Composer<_$AppDatabase, Transactions> {
  $TransactionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchangeRateSnapshot => $composableBuilder(
    column: $table.exchangeRateSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMyrMinor => $composableBuilder(
    column: $table.amountMyrMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $CategoriesFilterComposer get categoryId {
    final $CategoriesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CategoriesFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $CurrenciesFilterComposer get currencyCode {
    final $CurrenciesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currencyCode,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.code,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrenciesFilterComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $TripsFilterComposer get tripId {
    final $TripsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripsFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $TransactionsOrderingComposer
    extends Composer<_$AppDatabase, Transactions> {
  $TransactionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchangeRateSnapshot => $composableBuilder(
    column: $table.exchangeRateSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMyrMinor => $composableBuilder(
    column: $table.amountMyrMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $CategoriesOrderingComposer get categoryId {
    final $CategoriesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CategoriesOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $CurrenciesOrderingComposer get currencyCode {
    final $CurrenciesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currencyCode,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.code,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrenciesOrderingComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $TripsOrderingComposer get tripId {
    final $TripsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripsOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $TransactionsAnnotationComposer
    extends Composer<_$AppDatabase, Transactions> {
  $TransactionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exchangeRateSnapshot => $composableBuilder(
    column: $table.exchangeRateSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountMyrMinor => $composableBuilder(
    column: $table.amountMyrMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  $CategoriesAnnotationComposer get categoryId {
    final $CategoriesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CategoriesAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $CurrenciesAnnotationComposer get currencyCode {
    final $CurrenciesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currencyCode,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.code,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $CurrenciesAnnotationComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $TripsAnnotationComposer get tripId {
    final $TripsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripsAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $TransactionsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Transactions,
          Transaction,
          $TransactionsFilterComposer,
          $TransactionsOrderingComposer,
          $TransactionsAnnotationComposer,
          $TransactionsCreateCompanionBuilder,
          $TransactionsUpdateCompanionBuilder,
          (Transaction, $TransactionsReferences),
          Transaction,
          PrefetchHooks Function({
            bool categoryId,
            bool currencyCode,
            bool tripId,
          })
        > {
  $TransactionsTableManager(_$AppDatabase db, Transactions table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $TransactionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $TransactionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $TransactionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String> exchangeRateSnapshot = const Value.absent(),
                Value<int> amountMyrMinor = const Value.absent(),
                Value<String> transactionDate = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                categoryId: categoryId,
                type: type,
                amountMinor: amountMinor,
                currencyCode: currencyCode,
                exchangeRateSnapshot: exchangeRateSnapshot,
                amountMyrMinor: amountMyrMinor,
                transactionDate: transactionDate,
                note: note,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                tripId: tripId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String categoryId,
                required String type,
                required int amountMinor,
                required String currencyCode,
                required String exchangeRateSnapshot,
                required int amountMyrMinor,
                required String transactionDate,
                Value<String?> note = const Value.absent(),
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<String> tripId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                categoryId: categoryId,
                type: type,
                amountMinor: amountMinor,
                currencyCode: currencyCode,
                exchangeRateSnapshot: exchangeRateSnapshot,
                amountMyrMinor: amountMyrMinor,
                transactionDate: transactionDate,
                note: note,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                tripId: tripId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Transactions, Transaction>(table),
                  $TransactionsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({categoryId = false, currencyCode = false, tripId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable: $TransactionsReferences
                                        ._categoryIdTable(db),
                                    referencedColumn: $TransactionsReferences
                                        ._categoryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (currencyCode) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.currencyCode,
                                    referencedTable: $TransactionsReferences
                                        ._currencyCodeTable(db),
                                    referencedColumn: $TransactionsReferences
                                        ._currencyCodeTable(db)
                                        .code,
                                  )
                                  as T;
                        }
                        if (tripId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.tripId,
                                    referencedTable: $TransactionsReferences
                                        ._tripIdTable(db),
                                    referencedColumn: $TransactionsReferences
                                        ._tripIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $TransactionsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Transactions,
      Transaction,
      $TransactionsFilterComposer,
      $TransactionsOrderingComposer,
      $TransactionsAnnotationComposer,
      $TransactionsCreateCompanionBuilder,
      $TransactionsUpdateCompanionBuilder,
      (Transaction, $TransactionsReferences),
      Transaction,
      PrefetchHooks Function({bool categoryId, bool currencyCode, bool tripId})
    >;
typedef $AppSettingsCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $AppSettingsUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $AppSettingsFilterComposer extends Composer<_$AppDatabase, AppSettings> {
  $AppSettingsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $AppSettingsOrderingComposer
    extends Composer<_$AppDatabase, AppSettings> {
  $AppSettingsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AppSettingsAnnotationComposer
    extends Composer<_$AppDatabase, AppSettings> {
  $AppSettingsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $AppSettingsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          AppSettings,
          AppSetting,
          $AppSettingsFilterComposer,
          $AppSettingsOrderingComposer,
          $AppSettingsAnnotationComposer,
          $AppSettingsCreateCompanionBuilder,
          $AppSettingsUpdateCompanionBuilder,
          (AppSetting, BaseReferences<_$AppDatabase, AppSettings, AppSetting>),
          AppSetting,
          PrefetchHooks Function()
        > {
  $AppSettingsTableManager(_$AppDatabase db, AppSettings table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AppSettingsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AppSettingsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AppSettingsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<AppSettings, AppSetting>(table),
                  BaseReferences<_$AppDatabase, AppSettings, AppSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AppSettingsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      AppSettings,
      AppSetting,
      $AppSettingsFilterComposer,
      $AppSettingsOrderingComposer,
      $AppSettingsAnnotationComposer,
      $AppSettingsCreateCompanionBuilder,
      $AppSettingsUpdateCompanionBuilder,
      (AppSetting, BaseReferences<_$AppDatabase, AppSettings, AppSetting>),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $SharedSessionsCreateCompanionBuilder =
    SharedSessionsCompanion Function({
      required String id,
      required String role,
      Value<String?> tripId,
      required String name,
      required String secret,
      required String endpoint,
      Value<String?> cache,
      Value<int> rowid,
    });
typedef $SharedSessionsUpdateCompanionBuilder =
    SharedSessionsCompanion Function({
      Value<String> id,
      Value<String> role,
      Value<String?> tripId,
      Value<String> name,
      Value<String> secret,
      Value<String> endpoint,
      Value<String?> cache,
      Value<int> rowid,
    });

final class $SharedSessionsReferences
    extends BaseReferences<_$AppDatabase, SharedSessions, SharedSession> {
  $SharedSessionsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Trips _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('shared_sessions__trip_id__trips__id');

  $TripsProcessedTableManager? get tripId {
    final $_column = $_itemColumn<String>('trip_id');
    if ($_column == null) return null;
    final manager = $TripsTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<SharedPending, List<SharedPendingData>>
  _sharedPendingRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sharedPending,
    aliasName: 'shared_sessions__id__shared_pending__session_id',
  );

  $SharedPendingProcessedTableManager get sharedPendingRefs {
    final manager = $SharedPendingTableManager(
      $_db,
      $_db.sharedPending,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sharedPendingRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<SharedReceipts, List<SharedReceipt>>
  _sharedReceiptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sharedReceipts,
    aliasName: 'shared_sessions__id__shared_receipts__session_id',
  );

  $SharedReceiptsProcessedTableManager get sharedReceiptsRefs {
    final manager = $SharedReceiptsTableManager(
      $_db,
      $_db.sharedReceipts,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sharedReceiptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $SharedSessionsFilterComposer
    extends Composer<_$AppDatabase, SharedSessions> {
  $SharedSessionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secret => $composableBuilder(
    column: $table.secret,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cache => $composableBuilder(
    column: $table.cache,
    builder: (column) => ColumnFilters(column),
  );

  $TripsFilterComposer get tripId {
    final $TripsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripsFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sharedPendingRefs(
    Expression<bool> Function($SharedPendingFilterComposer f) f,
  ) {
    final $SharedPendingFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sharedPending,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SharedPendingFilterComposer(
            $db: $db,
            $table: $db.sharedPending,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sharedReceiptsRefs(
    Expression<bool> Function($SharedReceiptsFilterComposer f) f,
  ) {
    final $SharedReceiptsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sharedReceipts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SharedReceiptsFilterComposer(
            $db: $db,
            $table: $db.sharedReceipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $SharedSessionsOrderingComposer
    extends Composer<_$AppDatabase, SharedSessions> {
  $SharedSessionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secret => $composableBuilder(
    column: $table.secret,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cache => $composableBuilder(
    column: $table.cache,
    builder: (column) => ColumnOrderings(column),
  );

  $TripsOrderingComposer get tripId {
    final $TripsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripsOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SharedSessionsAnnotationComposer
    extends Composer<_$AppDatabase, SharedSessions> {
  $SharedSessionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get secret =>
      $composableBuilder(column: $table.secret, builder: (column) => column);

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<String> get cache =>
      $composableBuilder(column: $table.cache, builder: (column) => column);

  $TripsAnnotationComposer get tripId {
    final $TripsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TripsAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sharedPendingRefs<T extends Object>(
    Expression<T> Function($SharedPendingAnnotationComposer a) f,
  ) {
    final $SharedPendingAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sharedPending,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SharedPendingAnnotationComposer(
            $db: $db,
            $table: $db.sharedPending,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> sharedReceiptsRefs<T extends Object>(
    Expression<T> Function($SharedReceiptsAnnotationComposer a) f,
  ) {
    final $SharedReceiptsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sharedReceipts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SharedReceiptsAnnotationComposer(
            $db: $db,
            $table: $db.sharedReceipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $SharedSessionsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          SharedSessions,
          SharedSession,
          $SharedSessionsFilterComposer,
          $SharedSessionsOrderingComposer,
          $SharedSessionsAnnotationComposer,
          $SharedSessionsCreateCompanionBuilder,
          $SharedSessionsUpdateCompanionBuilder,
          (SharedSession, $SharedSessionsReferences),
          SharedSession,
          PrefetchHooks Function({
            bool tripId,
            bool sharedPendingRefs,
            bool sharedReceiptsRefs,
          })
        > {
  $SharedSessionsTableManager(_$AppDatabase db, SharedSessions table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SharedSessionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SharedSessionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SharedSessionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String?> tripId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> secret = const Value.absent(),
                Value<String> endpoint = const Value.absent(),
                Value<String?> cache = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedSessionsCompanion(
                id: id,
                role: role,
                tripId: tripId,
                name: name,
                secret: secret,
                endpoint: endpoint,
                cache: cache,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String role,
                Value<String?> tripId = const Value.absent(),
                required String name,
                required String secret,
                required String endpoint,
                Value<String?> cache = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedSessionsCompanion.insert(
                id: id,
                role: role,
                tripId: tripId,
                name: name,
                secret: secret,
                endpoint: endpoint,
                cache: cache,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SharedSessions, SharedSession>(table),
                  $SharedSessionsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tripId = false,
                sharedPendingRefs = false,
                sharedReceiptsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sharedPendingRefs) db.sharedPending,
                    if (sharedReceiptsRefs) db.sharedReceipts,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (tripId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.tripId,
                                    referencedTable: $SharedSessionsReferences
                                        ._tripIdTable(db),
                                    referencedColumn: $SharedSessionsReferences
                                        ._tripIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sharedPendingRefs)
                        await $_getPrefetchedDataByColumns<
                          SharedSession,
                          SharedSessions,
                          SharedPendingData,
                          SharedPending
                        >(
                          currentTable: table,
                          referencedTable: $SharedSessionsReferences
                              ._sharedPendingRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $SharedSessionsReferences(
                                db,
                                table,
                                p0,
                              ).sharedPendingRefs,
                          currentColumn: 'id',
                          referencedColumn: 'session_id',
                          typedResults: items,
                        ),
                      if (sharedReceiptsRefs)
                        await $_getPrefetchedDataByColumns<
                          SharedSession,
                          SharedSessions,
                          SharedReceipt,
                          SharedReceipts
                        >(
                          currentTable: table,
                          referencedTable: $SharedSessionsReferences
                              ._sharedReceiptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $SharedSessionsReferences(
                                db,
                                table,
                                p0,
                              ).sharedReceiptsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'session_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $SharedSessionsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      SharedSessions,
      SharedSession,
      $SharedSessionsFilterComposer,
      $SharedSessionsOrderingComposer,
      $SharedSessionsAnnotationComposer,
      $SharedSessionsCreateCompanionBuilder,
      $SharedSessionsUpdateCompanionBuilder,
      (SharedSession, $SharedSessionsReferences),
      SharedSession,
      PrefetchHooks Function({
        bool tripId,
        bool sharedPendingRefs,
        bool sharedReceiptsRefs,
      })
    >;
typedef $SharedPendingCreateCompanionBuilder =
    SharedPendingCompanion Function({
      required String id,
      required String sessionId,
      required String payload,
      required int createdAt,
      Value<int> rowid,
    });
typedef $SharedPendingUpdateCompanionBuilder =
    SharedPendingCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> payload,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $SharedPendingReferences
    extends BaseReferences<_$AppDatabase, SharedPending, SharedPendingData> {
  $SharedPendingReferences(super.$_db, super.$_table, super.$_typedResult);

  static SharedSessions _sessionIdTable(_$AppDatabase db) => db.sharedSessions
      .createAlias('shared_pending__session_id__shared_sessions__id');

  $SharedSessionsProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $SharedSessionsTableManager(
      $_db,
      $_db.sharedSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $SharedPendingFilterComposer
    extends Composer<_$AppDatabase, SharedPending> {
  $SharedPendingFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $SharedSessionsFilterComposer get sessionId {
    final $SharedSessionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sharedSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SharedSessionsFilterComposer(
            $db: $db,
            $table: $db.sharedSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SharedPendingOrderingComposer
    extends Composer<_$AppDatabase, SharedPending> {
  $SharedPendingOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $SharedSessionsOrderingComposer get sessionId {
    final $SharedSessionsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sharedSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SharedSessionsOrderingComposer(
            $db: $db,
            $table: $db.sharedSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SharedPendingAnnotationComposer
    extends Composer<_$AppDatabase, SharedPending> {
  $SharedPendingAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $SharedSessionsAnnotationComposer get sessionId {
    final $SharedSessionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sharedSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SharedSessionsAnnotationComposer(
            $db: $db,
            $table: $db.sharedSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SharedPendingTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          SharedPending,
          SharedPendingData,
          $SharedPendingFilterComposer,
          $SharedPendingOrderingComposer,
          $SharedPendingAnnotationComposer,
          $SharedPendingCreateCompanionBuilder,
          $SharedPendingUpdateCompanionBuilder,
          (SharedPendingData, $SharedPendingReferences),
          SharedPendingData,
          PrefetchHooks Function({bool sessionId})
        > {
  $SharedPendingTableManager(_$AppDatabase db, SharedPending table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SharedPendingFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SharedPendingOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SharedPendingAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedPendingCompanion(
                id: id,
                sessionId: sessionId,
                payload: payload,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String payload,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SharedPendingCompanion.insert(
                id: id,
                sessionId: sessionId,
                payload: payload,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SharedPending, SharedPendingData>(table),
                  $SharedPendingReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $SharedPendingReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $SharedPendingReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $SharedPendingProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      SharedPending,
      SharedPendingData,
      $SharedPendingFilterComposer,
      $SharedPendingOrderingComposer,
      $SharedPendingAnnotationComposer,
      $SharedPendingCreateCompanionBuilder,
      $SharedPendingUpdateCompanionBuilder,
      (SharedPendingData, $SharedPendingReferences),
      SharedPendingData,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $SharedReceiptsCreateCompanionBuilder =
    SharedReceiptsCompanion Function({
      required String sessionId,
      required String requestId,
      required String transactionId,
      Value<int> rowid,
    });
typedef $SharedReceiptsUpdateCompanionBuilder =
    SharedReceiptsCompanion Function({
      Value<String> sessionId,
      Value<String> requestId,
      Value<String> transactionId,
      Value<int> rowid,
    });

final class $SharedReceiptsReferences
    extends BaseReferences<_$AppDatabase, SharedReceipts, SharedReceipt> {
  $SharedReceiptsReferences(super.$_db, super.$_table, super.$_typedResult);

  static SharedSessions _sessionIdTable(_$AppDatabase db) => db.sharedSessions
      .createAlias('shared_receipts__session_id__shared_sessions__id');

  $SharedSessionsProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $SharedSessionsTableManager(
      $_db,
      $_db.sharedSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $SharedReceiptsFilterComposer
    extends Composer<_$AppDatabase, SharedReceipts> {
  $SharedReceiptsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnFilters(column),
  );

  $SharedSessionsFilterComposer get sessionId {
    final $SharedSessionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sharedSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SharedSessionsFilterComposer(
            $db: $db,
            $table: $db.sharedSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SharedReceiptsOrderingComposer
    extends Composer<_$AppDatabase, SharedReceipts> {
  $SharedReceiptsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnOrderings(column),
  );

  $SharedSessionsOrderingComposer get sessionId {
    final $SharedSessionsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sharedSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SharedSessionsOrderingComposer(
            $db: $db,
            $table: $db.sharedSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SharedReceiptsAnnotationComposer
    extends Composer<_$AppDatabase, SharedReceipts> {
  $SharedReceiptsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => column,
  );

  $SharedSessionsAnnotationComposer get sessionId {
    final $SharedSessionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sharedSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SharedSessionsAnnotationComposer(
            $db: $db,
            $table: $db.sharedSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SharedReceiptsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          SharedReceipts,
          SharedReceipt,
          $SharedReceiptsFilterComposer,
          $SharedReceiptsOrderingComposer,
          $SharedReceiptsAnnotationComposer,
          $SharedReceiptsCreateCompanionBuilder,
          $SharedReceiptsUpdateCompanionBuilder,
          (SharedReceipt, $SharedReceiptsReferences),
          SharedReceipt,
          PrefetchHooks Function({bool sessionId})
        > {
  $SharedReceiptsTableManager(_$AppDatabase db, SharedReceipts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SharedReceiptsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SharedReceiptsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SharedReceiptsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> requestId = const Value.absent(),
                Value<String> transactionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedReceiptsCompanion(
                sessionId: sessionId,
                requestId: requestId,
                transactionId: transactionId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String requestId,
                required String transactionId,
                Value<int> rowid = const Value.absent(),
              }) => SharedReceiptsCompanion.insert(
                sessionId: sessionId,
                requestId: requestId,
                transactionId: transactionId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SharedReceipts, SharedReceipt>(table),
                  $SharedReceiptsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $SharedReceiptsReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $SharedReceiptsReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $SharedReceiptsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      SharedReceipts,
      SharedReceipt,
      $SharedReceiptsFilterComposer,
      $SharedReceiptsOrderingComposer,
      $SharedReceiptsAnnotationComposer,
      $SharedReceiptsCreateCompanionBuilder,
      $SharedReceiptsUpdateCompanionBuilder,
      (SharedReceipt, $SharedReceiptsReferences),
      SharedReceipt,
      PrefetchHooks Function({bool sessionId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $CategoriesTableManager get categories =>
      $CategoriesTableManager(_db, _db.categories);
  $CurrenciesTableManager get currencies =>
      $CurrenciesTableManager(_db, _db.currencies);
  $TripsTableManager get trips => $TripsTableManager(_db, _db.trips);
  $CurrencyRatesTableManager get currencyRates =>
      $CurrencyRatesTableManager(_db, _db.currencyRates);
  $TripRatesTableManager get tripRates =>
      $TripRatesTableManager(_db, _db.tripRates);
  $TransactionsTableManager get transactions =>
      $TransactionsTableManager(_db, _db.transactions);
  $AppSettingsTableManager get appSettings =>
      $AppSettingsTableManager(_db, _db.appSettings);
  $SharedSessionsTableManager get sharedSessions =>
      $SharedSessionsTableManager(_db, _db.sharedSessions);
  $SharedPendingTableManager get sharedPending =>
      $SharedPendingTableManager(_db, _db.sharedPending);
  $SharedReceiptsTableManager get sharedReceipts =>
      $SharedReceiptsTableManager(_db, _db.sharedReceipts);
}
