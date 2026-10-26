# تحسين الأداء وحجم التطبيق — barber_book

مرجع سريع لما طُبّق وما يُفضّل مراعاته لاحقاً.

## 1. أداء البناء (UI)

| ممارسة | الحالة في المشروع |
|--------|-------------------|
| `const` على الـ widgets الثابتة | مفعّل عبر `prefer_const_constructors` في `analysis_options.yaml` |
| تقسيم الشاشات الكبيرة | شاشة **وارد الزبائن** قُسّمت إلى ملخص / نموذج / سجل؛ `setState` محلي داخل النموذج فقط |
| عدم رفع `setState` لأعلى الشجرة | النموذج لا يعيد بناء قائمة السجل عند الكتابة في الحقول |
| `context.select` بدل `watch` الكامل | رأس السجل والقائمة يستمعان للحقول المطلوبة فقط |

### عند إضافة شاشات جديدة

```dart
// جيد: ثابت
const Text('عنوان');
const SizedBox(height: 12);

// جيد: فصل النموذج عن القائمة
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [_Summary(), _Form(), _List()],
  );
}

// تجنّب: setState في أعلى الشاشة يعيد بناء كل شيء
```

## 2. حجم التطبيق

| بند | ملاحظة |
|-----|--------|
| `cross_file` | حُذف من `pubspec.yaml` (غير مستخدم في `lib/`) |
| `icon_full.png` (~450KB) | يُفضّل ضغطه أو تحويله لـ WebP قبل إعادة توليد الأيقونات |
| الأصول | حالياً `logo.svg` فقط في `flutter.assets` — جيد |
| الحزم | `firebase_storage` / `image_picker` / `qr_flutter` مستخدمة في الإعدادات فقط — أبقِها إن بقيت الميزة |

```powershell
# بعد حذف حزم:
flutter pub get
flutter build apk --analyze-size
```

## 3. الهيكل وإدارة الحالة

- **Provider** هو الاختيار الحالي (مناسب لحجم المشروع).
- المنطق في `providers/` و`services/`؛ الواجهة في `screens/`.
- المالية: مصدر وحيد `FinanceProvider` + `OperatingExpense` / `DailyFinanceEntry`.
- لا حاجة لـ Bloc/Riverpod الآن إلا إذا كبر التعقيد (نماذج متعددة متزامنة، offline queue معقّد).

## 4. أوامر تحقق

```powershell
flutter analyze
flutter test
# اختياري — حجم الإصدار:
flutter build apk --release
```
