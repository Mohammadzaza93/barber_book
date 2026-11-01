# حماية مجانية (بدون خدمات مدفوعة)

كل ما في هذا الملف **مجاني** ضمن Firebase/Android العادي.

## 1) نشر القواعد (مرة بعد كل تعديل)

```bash
firebase login
firebase deploy --only firestore:rules,storage
```

في Console: Firestore → Rules و Storage → Rules يجب أن تطابق الملفات في المشروع.

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
