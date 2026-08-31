# دليل التشغيل والإعداد
## Setup & Deployment Guide

---

## 🔧 المتطلبات الأساسية

### Backend Requirements
- Node.js >= 18.0.0
- PostgreSQL >= 12
- npm أو yarn

### Frontend Requirements
- Flutter >= 3.3.0
- Android SDK (لـ Android)
- Xcode (لـ iOS)

---

## 📦 خطوات التثبيت والتشغيل

### 1️⃣ Backend Setup

#### أ) التثبيت الأولي
```bash
cd backend
npm install
```

#### ب) إعداد قاعدة البيانات
```bash
# نسخ ملف الـenvironment
cp .env.example .env

# تحديث DATABASE_URL في .env
DATABASE_URL="postgresql://user:password@localhost:5432/rideflow_db"

# تشغيل الـmigration
npm run prisma:migrate

# توليد Prisma client
npm run prisma:generate
```

#### ج) تشغيل السيرفر
```bash
# للتطوير
npm run dev

# للإنتاج
npm run build
npm start
```

السيرفر سيعمل على: `http://localhost:4000`

### 2️⃣ Frontend Setup

#### أ) التثبيت الأولي
```bash
cd flutter_app
flutter pub get
```

#### ب) تحديث API Configuration
تحديث الملف: `lib/core/config/app_config.dart`
```dart
class AppConfig {
  static const String apiBaseUrl = 'http://localhost:4000/api';
  static const String websocketUrl = 'http://localhost:4000';
  static const String googleMapsApiKey = 'YOUR_API_KEY';
}
```

#### ج) تشغيل التطبيق
```bash
# للنمو (Development)
flutter run

# لـ release
flutter run --release
```

---

## 🗄️ Database Migration

### الخطوة الأولى - التحقق من الـschema
```bash
cd backend
npm run prisma:studio
```

هذا سيفتح واجهة بصرية لـ Prisma لمراجعة البيانات.

### الخطوة الثانية - إنشاء migration جديد (إذا لزم الأمر)
```bash
npm run prisma:migrate -- --name init
```

### الخطوة الثالثة - Seed البيانات الأولية (اختياري)
```bash
# يمكنك إنشاء ملف seed وتشغيله
npm run prisma:seed
```

---

## 👤 إنشاء Super Admin

بعد تشغيل الـserver، قم بإنشاء حساب super admin عبر API:

```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Admin",
    "phone": "+201001234567",
    "password": "admin_password",
    "email": "admin@rideflow.app",
    "role": "super_admin"
  }'
```

**ملاحظة**: يجب تحديث الـcontroller لدعم إنشاء super_admin مباشرة أو تعديل الـdatabase يدويًا.

---

## 🧪 اختبار API

### 1. تسجيل دخول العميل
```bash
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+201001234567",
    "password": "password123"
  }'
```

### 2. تسجيل شركة ليموزين
```bash
curl -X POST http://localhost:4000/api/company/register \
  -H "Content-Type: application/json" \
  -d '{
    "companyName": "Luxury Limousine Co.",
    "companyType": "LIMOUSINE",
    "contactPerson": "Ahmed Hassan",
    "phone": "+201109876543",
    "password": "company_password123",
    "address": "Cairo, Egypt"
  }'
```

### 3. إنشاء طلب ليموزين
```bash
curl -X POST http://localhost:4000/api/orders/limousine \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "pickupAddress": "Tahrir Square, Cairo",
    "dropoffAddress": "Giza Pyramids",
    "offerPrice": 500,
    "notes": "Please arrive in 10 minutes"
  }'
```

---

## 🔑 متغيرات البيئة (.env)

```env
# Database
DATABASE_URL="postgresql://user:password@localhost:5432/rideflow_db"

# JWT
JWT_SECRET="your_jwt_secret_key_here"
JWT_REFRESH_SECRET="your_jwt_refresh_secret_key_here"

# Server
PORT=4000
NODE_ENV=development

# Socket.IO
SOCKET_IO_PORT=4000
```

---

## 📋 قائمة التحقق قبل الإنتاج

- [ ] تحديث متغيرات البيئة بـ production values
- [ ] تفعيل HTTPS للـ API
- [ ] إعداد CORS بشكل صحيح
- [ ] تفعيل جدار الحماية (Firewall)
- [ ] إعداد نسخ احتياطية (Backups) للـ Database
- [ ] اختبار جميع API endpoints
- [ ] اختبار جميع user flows
- [ ] تحديث رسالة خطأ المستخدم (لا تعرض تفاصيل خادم)
- [ ] تفعيل logging والـmonitoring
- [ ] اختبار الأداء (Performance testing)

---

## 🐛 استكشاف الأخطاء

### المشكلة: خطأ الاتصال بـ Database
**الحل**: 
- تأكد من أن PostgreSQL يعمل
- تحقق من DATABASE_URL الصحيحة
- تأكد من أن كلمة المرور صحيحة

### المشكلة: JWT token invalid
**الحل**:
- تأكد من نسخ token بشكل صحيح في header
- تحقق من أن التوكن لم ينتهي
- تحقق من أن JWT_SECRET متطابق في .env

### المشكلة: CORS errors
**الحل**:
- تحديث CORS configuration في app.js
- السماح للـ origin الصحيح

### المشكلة: Flutter app لا يتصل بـ API
**الحل**:
- تأكد من أن اللـ localhost أو IP الصحيح في app_config.dart
- تحقق من أن الـ firewall لا يحجب المنفذ 4000
- جرب استخدام IP بدلاً من localhost

---

## 📱 Building for Production

### Backend
```bash
npm run build
npm start
```

### Flutter - Android
```bash
flutter build apk --release
# أو
flutter build appbundle --release
```

### Flutter - iOS
```bash
flutter build ios --release
```

---

## 📊 Monitoring و Logging

يُنصح بـ:
- استخدام Winston أو morgan للـ logging
- استخدام Sentry للـ error tracking
- استخدام New Relic أو DataDog للـ monitoring
- إعداد alerts للـ errors الحرجة

---

## 🔄 التحديثات المستقبلية

سيتم إضافة:
1. نظام الدفع الكامل (Stripe/Apple Pay)
2. تطبيق Driver منفصل (للسائقين)
3. تطبيق Admin Dashboard (ويب)
4. push notifications
5. تقييمات وتعليقات محسّنة
6. تاريخ الطلبات والفواتير

---

## 📞 الدعم الفني

للمساعدة والدعم:
- اطلع على المستندات الكاملة: docs/README.md
- اسأل في القنوات المخصصة
- أرسل bug report مع التفاصيل
