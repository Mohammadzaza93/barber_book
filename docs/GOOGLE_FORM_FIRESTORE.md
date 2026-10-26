# ربط Google Form → Sheets → Firestore (مجاني)

الهدف: العميل يحجز عبر **Google Form**، والإجابة تُحفظ في **Sheets**، و**Apps Script** يرسل الحجز فوراً إلى `shops/{shopId}/appointments` فيظهر عندك في التطبيق بحالة `requested` (معلّق للموافقة).

> الكود النموذجي الشائع الذي يستخدم `https://googleapis.com` **لا يعمل**. Firestore REST يحتاج:
> 1) رابط المشروع الصحيح  
> 2) **رمز وصول (access token)** من حساب خدمة  
> 3) حقول بنفس أسماء نموذج `Appointment` في التطبيق

---

## 1) جهّز Google Form

أنشئ نموذجاً بهذه الأسئلة (أو عدّل أسماء الأعمدة في السكربت):

| السؤال | نوع |
|--------|------|
| الاسم الكامل | نص قصير |
| رقم الهاتف | نص قصير |
| الخدمة المطلوبة | قائمة منسدلة (حلاقة شعر، ذقن، صبغة...) |
| التاريخ والوقت المفضّل | تاريخ + وقت أو نص |
| ملاحظات | فقرة (اختياري) |

اربط النموذج بـ **جدول بيانات جديد** (Responses → Link to Sheets).

انسخ **رابط النموذج** والصقه في التطبيق:  
**الإعدادات → رابط الحجز (Google Form)**.

---

## 2) حساب خدمة Firebase (مرة واحدة)

1. افتح [Google Cloud Console](https://console.cloud.google.com/) → نفس مشروع Firebase.
2. **IAM & Admin → Service Accounts → Create**.
3. الاسم مثلاً `sheets-to-firestore`.
4. Role: **Cloud Datastore User** أو **Firebase Admin SDK Administrator Service Agent**.
5. Keys → Add key → JSON → حمّل الملف.
6. من JSON احتفظ بـ:
   - `client_email`
   - `private_key`
   - و`project_id` من Firebase

---

## 3) Apps Script داخل الـ Sheet

1. من جدول الردود: **Extensions → Apps Script**.
2. الصق السكربت من الملف `scripts/google_form_to_firestore.gs` (أو القسم أدناه).
3. **Project Settings → Script properties** وأضف:

| Property | Value |
|----------|--------|
| `FIREBASE_PROJECT_ID` | معرف مشروع Firebase |
| `SHOP_ID` | معرّف الصالون في Firestore (`shops/{id}`) |
| `SERVICE_ACCOUNT_EMAIL` | `client_email` من JSON |
| `PRIVATE_KEY` | `private_key` كاملاً (بما فيه `-----BEGIN...`) |

4. احفظ → **Triggers** → Add trigger:
   - Function: `onFormSubmit`
   - Event: From spreadsheet → **On form submit**
5. اسمح بالصلاحيات عند أول تشغيل.

---

## 4) ما الذي يُكتب في Firestore؟

المسار:

```text
shops/{SHOP_ID}/appointments/{autoId}
```

حقول متوافقة مع التطبيق:

| حقل | قيمة |
|-----|------|
| `shopId` | SHOP_ID |
| `reference` | رمز قصير (مثل `GF-xxxx`) |
| `customerName` / `customerPhone` | من النموذج |
| `serviceIds` | قائمة نصية لاسم الخدمة (يمكن مطابقتها لاحقاً يدوياً) |
| `startTime` / `endTime` | وقت الموعد (+ مدة افتراضية 30 د) |
| `status` | `requested` |
| `paymentStatus` | `unpaid` |
| `employeeId` | فارغ أو قيمة افتراضية تعدّلها من التطبيق |
| `notes` | يذكر أن المصدر Google Form |
| `createdAt` | وقت الإرسال |

في التطبيق تظهر ضمن **المواعيد** بحالة طلب معلّق → تؤكّد أو تعدّل الحلاق/الوقت.

> قواعد الأمان الحالية تسمح بـ `create` للحجوزات لـ **admin/staff فقط**. لذلك **يجب** استخدام حساب الخدمة (Admin). لا تفتح الكتابة للعامة.

---

## 5) اختبار

1. أرسل رداً تجريبياً من النموذج.
2. Apps Script → Executions: يجب أن ترى نجاحاً.
3. Firebase Console → Firestore → `shops/.../appointments`.
4. افتح التطبيق → المواعيد → فلتر «معلّق / requested».

---

## استكشاف أخطاء شائعة

| خطأ | سبب |
|-----|------|
| 401 / 403 | PRIVATE_KEY أو الصلاحيات خاطئة |
| 404 | `FIREBASE_PROJECT_ID` أو `SHOP_ID` خطأ |
| الحجز لا يظهر في التطبيق | `status` ليس `requested` أو `shopId` مختلف عن جلسة الدخول |
| أعمدة فارغة | رتّب أرقام الأعمدة في السكربت حسب جدول الردود |

---

## بدائل

- **يدوياً:** انسخ من Sheets إلى التطبيق (بدون سكربت).
- **Cloud Function HTTP:** نفس الفكرة بتكلفة مجانية ضمن الحصة، مع مفتاح سري في رأس الطلب.
