# BarberBook — تطبيق حجوزات صالونات الحلاقة

تطبيق Flutter لإدارة حجوزات صالونات الحلاقة، بواجهة عربية/إنجليزية (RTL) وقاعدة بيانات Firebase.
يشمل لوحة تحكم كاملة للموظفين: مواعيد، خدمات، حلاقون، خصومات، نفقات، تقييمات، تقارير، إعدادات،
بالإضافة إلى صفحة حجز إلكترونية عامة يستخدمها العملاء.

## المميزات

- تسجيل دخول وإنشاء صالون جديد (معالج إعداد من 5 خطوات)
- شاشة رئيسية بإحصائيات ورسم بياني شهري
- إدارة المواعيد: إنشاء/تعديل/إلغاء/تأكيد، حالات متعددة، حجوزات عامة قيد المراجعة
- إدارة الخدمات، الحلاقين وساعات عملهم الأسبوعية، أوقات عدم التوفر
- خصومات (نسبة أو مبلغ، كود قابل للاستخدام من صفحة الحجز)
- نفقات وتقارير شهرية (أرباح، رسوم الحلاقين، مصاريف، خدمات شائعة)
- تقييمات العملاء ومراجعتها
- صفحة حجز عامة: خدمات متعددة + اختيار حلاق + مواعيد متاحة + كود خصم + وديعة
- طلب موعد خارج ساعات العمل (يظهر للإدارة كطلب قيد المراجعة)
- تتبع الحجز برقم الهاتف مع إمكانية التقييم
- تذكيرات (WhatsApp/بريد إلكتروني) وإشعارات محلية عند الحجز
- تصدير موعد بصيغة ICS / فتحه في Google Calendar
- اللغتان العربية (افتراضية) والإنجليزية

## المتطلبات

- Flutter SDK (3.27 أو أحدث) مع Dart 3.x
- مشروع Firebase (خطة Blaze اختيارية للاستفادة من التحديثات في الوقت الحقيقي)
- `flutterfire_cli` (أحدث إصدار)

## خطوات التشغيل

```bash
# 1) تنفيذ داخل مجلد المشروع
flutter pub get

# 2) إنشاء مجلدات المنصات (مرة واحدة فقط إذا لم تكن موجودة)
flutter create . --platforms=android,ios --org com.yourorg

# 3) إنشاء lib/firebase_options.dart الفعلي
#    (يتطلب أن تكون مسجلاً في Google Cloud)
dart pub global activate flutterfire_cli
flutterfire configure

# 4) توليد ملفات الترجمة
flutter gen-l10n

# 5) التحليل والبناء
flutter analyze
flutter run
```

## بنية المشروع

```
lib/
├── main.dart                 # تهيئة Firebase + الإشعارات + تشغيل التطبيق
├── app.dart                  # جميع Providers في الأعلى + MaterialApp مع الترجمة
├── firebase_options.dart     # يُنشأ تلقائياً عبر flutterfire configure
├── l10n/                     # app_ar.arb + app_en.arb + strings.dart (t(context))
├── models/                   # Service, Employee, Appointment, BookingSettings,
│                             # Discount, Expense, Feedback, UnavailabilityRequest, enums
├── providers/                # Auth, Shop, Appointment, Discount, Expense, Feedback, Language
├── services/                 # Auth, Firestore, Notifications, Calendar, Reminders,
│                             # Analytics, Seeding, حساب السعر (BookingCalc), ShopManager
├── screens/
│   ├── auth/                 # تسجيل دخول + معالج إعداد الصالون
│   ├── admin/                # لوحة التحكم وأقسامها العشرة
│   └── customer/             # صفحة الحجز + تأكيد الحجز + تتبع الحجز
├── widgets/                  # مكونات مشتركة (StatusChip, SlotPicker, ...)
└── theme/app_theme.dart      # الثيم مع parseHexColor
```

## نموذج بيانات Firestore

```
shops/{shopId}
├── ownerId, createdAt
├── ساعات العمل والإعدادات (BookingSettings)
├── services/   → وثيقة لكل خدمة
├── employees/  → وثيقة لكل حلاق (مع جدول ساعات أسبوعي)
├── appointments/ → وثيقة لكل موعد
├── discounts/  → أكواد الخصم
├── expenses/   → النفقات
├── feedback/   → تقييمات العملاء
└── requests/      → طلبات المواعيد خارج الأوقات (تُحوَّل إلى مواعيد عند الموافقة)
```

## ملاحظات

- صفحة الحجز العامة متاحة من زر التقويم في الشاشة الرئيسية ومن إعدادات صفحة الحجز (معاينة).
  لإتاحتها للعملاء خارج التطبيق، تحتاج ربطها برابط ويب (Firebase Hosting + Dynamic Links).
- الإشعارات المحلية والتذكيرات تعتمد على المنطقة الزمنية `Asia/Riyadh`.
- قبل أول تشغيل فعلي على جهاز، ثبّت Flutter ثم نفّذ خطوات "خطوات التشغيل" أعلاه — لا يزال
  `lib/firebase_options.dart` يحوي قيماً وهمية إلى أن تنفّذ `flutterfire configure`.


## الأمان قبل النشر

قواعد Firestore وStorage في هذا المستودع مقفلة افتراضيًا، وتسمح بإدارة بيانات المحل فقط للمستخدم المصادق عليه الذي يطابق `ownerId` في وثيقة `shops/{shopId}`. لا تعِد إلى استخدام `allow read, write: if true`.

قبل النشر، راجع القواعد باستخدام Firebase Emulator أو Firebase CLI، ثم انشرها من حساب المشروع الصحيح فقط:

```bash
firebase use <your-firebase-project-id>
firebase deploy --only firestore:rules,storage
```

مسار الشعار المسموح به هو `shops/{shopId}/logo`، وتُقبل ملفات الصور فقط بحجم أقل من 5MB. إذا أُضيفت صفحة حجز عامة لاحقًا، فيجب تصميم صلاحيات عميل منفصلة أو استخدام Cloud Functions؛ لا تفتح مجموعات المواعيد كاملة للزوار.

## الاختبارات والتحقق

بعد تثبيت Flutter وتشغيل `flutter pub get`، نفّذ:

```bash
flutter analyze
flutter test
flutter test test/booking_calc_test.dart
```

اختبارات الحسابات تغطي الخصم النسبي، الحد الأعلى للخصم، تعطيل العربون، نسبة العربون، والعربون الثابت للخدمات عالية الطلب. كما تم إصلاح شرط تحديث سلسلة المواعيد بحيث لا يؤثر على سلسلة أخرى بسبب أولوية العمليات المنطقية.

## إعداد Firebase الفعلي

لا تستخدم القيم الوهمية في `lib/firebase_options.dart` في بيئة الإنتاج. نفّذ `flutterfire configure` بعد تسجيل الدخول إلى مشروع Firebase الصحيح، ثم تحقق من تفعيل Email/Password Authentication وFirestore وStorage وCloud Messaging حسب المنصة المستهدفة. لا تُرسل ملفات إعداد الإنتاج إلى مستودع عام إذا كانت سياسة المشروع تمنع ذلك؛ مفاتيح Firebase العامة ليست بديلًا عن قواعد الأمان.
