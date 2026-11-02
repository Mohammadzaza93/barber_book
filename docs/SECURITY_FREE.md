# حماية مجانية (بدون خدمات مدفوعة)

كل ما في هذا الملف **مجاني** ضمن Firebase/Android العادي.

## 1) نشر القواعد (مرة بعد كل تعديل)

```bash
firebase login
firebase deploy --only firestore:rules,firestore:indexes
```

> **مهم:** انشر الفهارس مع القواعد (`firestore:indexes`). بدونها يفشل ربط حسابات
> الموظفين (شاشة «الحساب غير مرتبط بأي محل»). ولا تنشر `storage` إلا إذا كان
> مشروعك يدعمه فعلاً على الخطة المجانية.

في Console: Firestore → Rules يجب أن تطابق الملف في المشروع.

### اختبار القواعد مجاناً قبل النشر

```bash
cd rules-test
npm install
npm test        # يحتاج Java؛ يعمل على محاكي محلي بلا أي تكلفة
```

## 2) المصادقة

- حسابات معروفة فقط (صاحب الصالون + موظفون)
- كلمات مرور قوية
- تحقق بخطوتين على حساب Google الخاص بـ Firebase Console
- لا تشارك حساب المالك

## 3) أسرار Git

لا ترفع أبداً:

- `android/key.properties`
- `*.jks` / `*.keystore`
- `service-account*.json`
- `.env`

## 4) بناء نسخة محصّنة

```bash
flutter build apk --release
# أو
flutter build appbundle --release
```

الإصدار Release يفعّل minify + shrink تلقائياً من `android/app/build.gradle`.

## 5) الجهاز

- قفل شاشة على جهاز الصالون
- لا تثبت نسخة debug للاستخدام اليومي

## ملاحظة عن حدود Firebase المجانية

القواعد والأدوار والتشويش **بلا رسوم**.
حصة Spark المجانية تكفي عادة لصالون واحد؛ تجاوز الحصة نادر مع استخدام داخلي.
