# تطبيق منصة الليموزين والشحن
## Limousine & Shipping Platform - Implementation Summary

---

## 📋 نظرة عامة على النظام

### الفكرة الأساسية
منصة موحدة تقدم خدمتي **الليموزين** و**الشحن** من خلال تطبيق واحد.

### أنواع المستخدمين
1. **العميل (Customer)**
   - يختار الخدمة (ليموزين أو شحن)
   - ينشئ طلب مع اقتراح سعر
   - يتفاوض على السعر مع الشركات
   - يوافق على السعر النهائي

2. **الشركة (Company)**
   - تسجيل كشركة ليموزين أو شحن
   - مراجعة طلبات الخدمة الخاصة بها فقط
   - قبول/رفض/تقديم عرض سعر جديد
   - مشاهدة تفاصيل العميل بعد موافقته على السعر فقط

3. **المسؤول الأساسي (Super Admin)**
   - رؤية كل شيء في النظام
   - إدارة الشركات والعملاء
   - إدارة الطلبات والأسعار
   - عرض الإحصائيات الشاملة

---

## 🔄 دورة حياة الطلب

```
NEW
  ↓
COMPANY_REVIEWING
  ├─→ COMPANY_ACCEPTED (قبول السعر المقترح من العميل)
  │    ↓
  │  CONFIRMED ←─ CUSTOMER_APPROVED
  │    ↓
  │  COMPLETED
  │
  ├─→ COMPANY_REJECTED (رفض الطلب)
  │
  └─→ PRICE_SENT (إرسال عرض سعر جديد)
       ├─→ CUSTOMER_APPROVED (موافقة العميل)
       │    ↓
       │  CONFIRMED
       │    ↓
       │  COMPLETED
       │
       └─→ CUSTOMER_REJECTED (رفض العميل)

CANCELLED (يمكن من أي حالة - من قبل العميل)
```

---

## 📁 الملفات المعدلة والمضافة

### Backend Files

#### Prisma Schema
- **File**: `backend/prisma/schema.prisma`
- **Changes**: 
  - إضافة `Company` و `CompanyEmployee` models
  - تحديث `User` role field
  - إضافة `Order` و `PriceOffer` models
  - تحديث علاقات `Payment`, `Rating`, `Notification`

#### Controllers
- **NEW** `backend/src/controllers/companyController.js`
  - `registerCompany()` - تسجيل شركة جديدة
  - `companyLogin()` - تسجيل دخول الشركة
  - `getCompanyDashboard()` - لوحة تحكم الشركة
  - `getCompanyOrders()` - الحصول على طلبات الشركة
  - `reviewOrder()` - مراجعة طلب
  - `acceptOrder()` - قبول الطلب بالسعر المقترح
  - `rejectOrder()` - رفض الطلب
  - `sendCounterOffer()` - إرسال عرض سعر جديد

- **NEW** `backend/src/controllers/orderController.js`
  - `createLimousineOrder()` - إنشاء طلب ليموزين
  - `createShippingOrder()` - إنشاء طلب شحن
  - `getCustomerOrders()` - الحصول على طلبات العميل
  - `getOrderDetails()` - الحصول على تفاصيل الطلب
  - `approveCustomerPrice()` - موافقة العميل على السعر
  - `rejectCustomerPrice()` - رفض العميل للسعر
  - `confirmOrder()` - تأكيد الطلب
  - `completeOrder()` - إنهاء الطلب
  - `cancelOrder()` - إلغاء الطلب

- **UPDATED** `backend/src/controllers/adminController.js`
  - إضافة `getPendingCompanies()` - الشركات المعلقة
  - إضافة `approveCompany()` - موافقة على الشركة
  - إضافة `rejectCompany()` - رفض الشركة
  - إضافة `getAllOrders()` - كل الطلبات
  - إضافة `getAllCustomers()` - كل العملاء
  - إضافة `getAllCompanies()` - كل الشركات
  - إضافة `getAdminStats()` - إحصائيات شاملة

#### Routes
- **NEW** `backend/src/routes/orderRoutes.js`
- **NEW** `backend/src/routes/companyRoutes.js`

#### Middleware
- **UPDATED** `backend/src/middlewares/authMiddleware.js`
  - `maskSensitiveData()` - إخفاء بيانات العميل الحساسة
  - `requireCompanyOrderAccess()` - التحقق من وصول الشركة

#### App
- **UPDATED** `backend/src/app.js`
  - إضافة روutes الشركات والطلبات الجديدة

### Frontend Files

#### Home Screen
- **UPDATED** `flutter_app/lib/features/home/home_screen.dart`
  - إضافة اختيار الخدمة (Limousine/Shipping)
  - دعم نماذج منفصلة لكل خدمة
  - تحديث الاتصال بـ API الجديد
  - دعم RTL العربي

---

## 🔐 حماية البيانات

### مبدأ الخصوصية
- **قبل موافقة العميل**: رقم الهاتف مخفي (مثال: +20123****45)
- **بعد موافقة العميل**: رقم الهاتف ظاهر للشركة المختصة فقط
- **للمسؤول الأساسي**: كل البيانات ظاهرة دائماً

### الحماية تم تطبيقها على مستويين:
1. **Frontend**: إخفاء رقم الهاتف من الواجهة
2. **Backend**: التحقق من الصلاحيات قبل إرجاع البيانات الحساسة

---

## 📊 نظام الإشعارات

تم تطوير نظام الإشعارات الموجود مع إضافة:
- إشعارات للشركات عند طلبات جديدة
- إشعارات للعملاء عند قبول/رفض الطلب
- إشعارات للعملاء عند عروض أسعار جديدة
- إشعارات للشركات عند موافقة/رفض السعر من العميل

---

## 🔌 API Endpoints

### Company Authentication
```
POST /api/company/register - تسجيل شركة جديدة
POST /api/company/login - تسجيل دخول الشركة
```

### Company Management
```
GET /api/company/dashboard - لوحة التحكم
GET /api/company/orders - الطلبات
POST /api/company/orders/:orderId/review - مراجعة الطلب
POST /api/company/orders/:orderId/accept - قبول الطلب
POST /api/company/orders/:orderId/reject - رفض الطلب
POST /api/company/orders/:orderId/counter-offer - عرض سعر جديد
```

### Order Management (Customer)
```
POST /api/orders/limousine - طلب ليموزين
POST /api/orders/shipping - طلب شحن
GET /api/orders - الطلبات الخاصة بي
GET /api/orders/:orderId - تفاصيل الطلب
POST /api/orders/:orderId/approve-price - موافقة على السعر
POST /api/orders/:orderId/reject-price - رفض السعر
POST /api/orders/:orderId/confirm - تأكيد الطلب
POST /api/orders/:orderId/cancel - إلغاء الطلب
```

### Admin Management
```
GET /api/admin/companies/pending - الشركات المعلقة
POST /api/admin/companies/:id/approve - موافقة على الشركة
POST /api/admin/companies/:id/reject - رفض الشركة
GET /api/admin/orders - كل الطلبات
GET /api/admin/customers - كل العملاء
GET /api/admin/companies - كل الشركات
GET /api/admin/stats - الإحصائيات
```

---

## 🚀 متطلبات التشغيل

### Backend
```bash
cd backend
npm install
npm run prisma:generate
npm run prisma:migrate
npm run dev
```

### Frontend
```bash
cd flutter_app
flutter pub get
flutter run
```

---

## 📝 ملاحظات هامة

### عدم كسر الميزات القديمة
- نموذج `Trip` القديم محفوظ للتوافقية العكسية
- نموذج `Driver` والرحلات القديمة لا تزال تعمل

### التوسع المستقبلي
- النظام مصمم بشكل يسهل إضافة خدمات جديدة
- يمكن إضافة نماذج وطلب تدفق جديدة بسهولة

### نقاط الأمان
- التحقق من الصلاحيات على مستوى API
- إخفاء البيانات الحساسة بناءً على حالة الطلب
- استخدام JWT للمصادقة

---

## 🔄 التدفق الكامل لطلب ليموزين

1. **العميل ينشئ طلب**
   - يختار: "🚘 ليموزين"
   - يحدد: الموقع الحالي والوجهة
   - يقترح: سعر الرحلة

2. **الشركة ترى الطلب**
   - الشركة تتلقى إشعار
   - ترى تفاصيل الطلب بدون رقم هاتف العميل
   - لديها 3 خيارات:
     - قبول السعر المقترح
     - رفض الطلب
     - إرسال عرض سعر جديد

3. **عند إرسال عرض سعر جديد**
   - يتغير حالة الطلب إلى "PRICE_SENT"
   - العميل يتلقى إشعار
   - يمكن للعميل:
     - قبول العرض
     - رفض العرض

4. **عند موافقة العميل**
   - تظهر بيانات العميل الكاملة للشركة
   - يتغير حالة الطلب إلى "CONFIRMED"
   - تُنشأ سجل الدفع

5. **إنهاء الطلب**
   - الشركة تحدّث حالة الطلب إلى "COMPLETED"
   - يمكن إضافة تقييم وتعليق

---

## 📞 معلومات الاتصال

للدعم الفني أو الأسئلة عن النظام، يرجى التواصل عبر:
- البريد الإلكتروني: support@rideflow.app
- الهاتف: +20XXXXXXXXX
