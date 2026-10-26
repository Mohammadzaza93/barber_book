# تحسين الأداء — barber_book (شامل التطبيق)

## ما طُبّق على مستوى المشروع

### 1. قواعد التحليل (`analysis_options.yaml`)
- `prefer_const_constructors`
- `prefer_const_literals_to_create_immutables`
- `prefer_const_declarations`
- `avoid_unnecessary_containers` / `sized_box_for_whitespace`

شغّل `flutter analyze` وأصلح تحذيرات `const` تدريجياً — لا تكسر التشغيل.

### 2. شاشات أُعيدت هيكلتها (تقسيم + setState محدود)

| الشاشة | التحسين |
|--------|----------|
| **وارد الزبائن** (`daily_sales_screen`) | ملخص / نموذج / سجل منفصلين؛ `setState` داخل النموذج فقط |
| **المصاريف التشغيلية** | نموذج + قائمة + مجموع؛ القائمة لا تُعاد عند الكتابة |
| **لوحة التحكم** | أقسام مستقلة (`_Header`, `_StatsGrid`, charts…) مع `select`/`watch` محلي |
| **الحجوزات** | شريط فلاتر + قائمة؛ البطاقة `StatelessWidget` |
| **القشرة الرئيسية** | `IndexedStack` + `_visited` لا يبني تبويباً قبل فتحه |
| **أدوات الأعمال** | `TabBarView` أصلاً يعزل التبويبات |

### 3. حجم التطبيق
- حذف `cross_file` (غير مستخدم)
- الأصول: `logo.svg` فقط في `flutter.assets`
- `icon_full.png` ~450KB → يُفضّل ضغطه قبل إعادة توليد الأيقونات

### 4. إدارة الحالة
- **Provider** يبقى المعيار (مناسب للحجم الحالي)
- لا ترفع `watch` لأعلى شجرة إذا احتجت حقلاً واحداً — استخدم `context.select`
- المنطق في `providers/` و`services/`؛ الواجهة في `screens/`

## نمط يُتبع لأي شاشة جديدة

```dart
class FooScreen extends StatelessWidget {
  const FooScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _FooForm(),   // Stateful محلي إن لزم
        _FooList(),   // select على القائمة فقط
      ],
    );
  }
}

// setState هنا فقط — لا يعيد بناء القائمة
class _FooForm extends StatefulWidget {
  const _FooForm();
  @override
  State<_FooForm> createState() => _FooFormState();
}
```

## أوامر

```powershell
git pull origin main
flutter pub get
flutter analyze
flutter run --profile   # قياس أداء حقيقي
```

## متبقي اختياري (لاحقاً)
- تقسيم `business_management_tabs.dart` (~44KB) لملفات تبويب منفصلة
- ضغط `assets/brand/icon_full.png`
- `RepaintBoundary` حول الرسوم البيانية الثقيلة إن ظهر بطء على أجهزة ضعيفة
