class Service {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationMinutes;
  final String category;
  final bool active;
  final bool highDemand;
  final double depositAmount;
  final int colorValue;
  final int sortOrder;
  final String? imageUrl;
  final Map<String, double> materialRequirements;

  const Service({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    required this.durationMinutes,
    this.category = 'other',
    this.active = true,
    this.highDemand = false,
    this.depositAmount = 0,
    this.colorValue = 0xFF3949AB,
    this.sortOrder = 0,
    this.imageUrl,
    this.materialRequirements = const {},
  });

  Service copyWith({
    String? name,
    String? description,
    double? price,
    int? durationMinutes,
    String? category,
    bool? active,
    bool? highDemand,
    double? depositAmount,
    int? colorValue,
    int? sortOrder,
    String? imageUrl,
    Map<String, double>? materialRequirements,
  }) {
    return Service(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      category: category ?? this.category,
      active: active ?? this.active,
      highDemand: highDemand ?? this.highDemand,
      depositAmount: depositAmount ?? this.depositAmount,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      imageUrl: imageUrl ?? this.imageUrl,
      materialRequirements: materialRequirements ?? this.materialRequirements,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'price': price,
        'durationMinutes': durationMinutes,
        'category': category,
        'active': active,
        'highDemand': highDemand,
        'depositAmount': depositAmount,
        'colorValue': colorValue,
        'sortOrder': sortOrder,
        'imageUrl': imageUrl,
        'materialRequirements': materialRequirements,
      };

  factory Service.fromMap(String id, Map<String, dynamic> m) => Service(
        id: id,
        name: (m['name'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        price: ((m['price'] as num?) ?? 0).toDouble(),
        durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 30,
        category: (m['category'] as String?) ?? 'other',
        active: (m['active'] as bool?) ?? true,
        highDemand: (m['highDemand'] as bool?) ?? false,
        depositAmount: ((m['depositAmount'] as num?) ?? 0).toDouble(),
        colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFF3949AB,
        sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
        imageUrl: m['imageUrl'] as String?,
        materialRequirements: ((m['materialRequirements'] as Map?) ?? {}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
      );
}
