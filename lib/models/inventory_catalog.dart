/// تصنيفات ووحدات المخزون المشتركة بين المحرر والقوائم والتقارير.
const inventoryCategories = [
  ('general', 'عام'),
  ('shampoo', 'شامبو وبلسم'),
  ('dye', 'صبغات وكيماويات'),
  ('styling', 'جل وسبراي'),
  ('shaving', 'حلاقة'),
  ('blades', 'شفرات ومواد استهلاكية'),
  ('hygiene', 'نظافة وتعقيم'),
  ('retail', 'منتجات للبيع'),
];

const inventoryUnits = [
  ('piece', 'قطعة'),
  ('bottle', 'زجاجة'),
  ('box', 'علبة'),
  ('pack', 'عبوة'),
  ('ml', 'مل'),
  ('liter', 'لتر'),
  ('g', 'غرام'),
  ('kg', 'كغ'),
];

String inventoryCategoryLabel(String code) =>
    inventoryCategories
        .where((c) => c.$1 == code)
        .map((c) => c.$2)
        .firstOrNull ??
    code;

String inventoryUnitLabel(String code) =>
    inventoryUnits.where((u) => u.$1 == code).map((u) => u.$2).firstOrNull ??
    code;

/// أنواع حركات المخزون المتاحة في الواجهة.
const inventoryMovementTypes = [
  ('purchase', 'شراء'),
  ('usage', 'صرف'),
  ('waste', 'هدر'),
  ('damage', 'تلف'),
  ('expiry', 'انتهاء صلاحية'),
  ('adjustment', 'جرد'),
];

String inventoryMovementLabel(String type) => switch (type) {
      'purchase' => 'شراء',
      'usage' => 'صرف',
      'waste' => 'هدر',
      'damage' => 'تلف',
      'expiry' => 'انتهاء صلاحية',
      'adjustment' => 'جرد',
      _ => 'حركة',
    };
