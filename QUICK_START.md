# 🚀 Quick Start Guide - دليل البدء السريع

---

## ⚡ ابدأ في 5 دقائق

### 1️⃣ تثبيت الـ Backend

```bash
cd backend
npm install
npm run prisma:generate
npm run prisma:migrate
npm run dev
```

**✅ Backend ready at**: `http://localhost:4000`

---

### 2️⃣ تثبيت الـ Frontend

```bash
cd flutter_app
flutter pub get
flutter run
```

**✅ App ready**

---

## 📱 اختبر الـ System

### أ) نسخ Authorization Token

بعد تسجيل الدخول، انسخ ال token من الـ response

### ب) اختبر طلب ليموزين

```bash
curl -X POST http://localhost:4000/api/orders/limousine \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "pickupAddress": "Cairo",
    "dropoffAddress": "Giza",
    "offerPrice": 300
  }'
```

### ج) اختبر تسجيل شركة

```bash
curl -X POST http://localhost:4000/api/company/register \
  -H "Content-Type: application/json" \
  -d '{
    "companyName": "Best Limousine",
    "companyType": "LIMOUSINE",
    "contactPerson": "Ahmed",
    "phone": "+201001234567",
    "password": "password123",
    "address": "Cairo"
  }'
```

---

## 🎯 دورة عمل كاملة

1. **العميل**: ينشئ طلب ليموزين
2. **الشركة**: ترى الطلب (بدون رقم الهاتف)
3. **الشركة**: ترسل عرض سعر جديد
4. **العميل**: يوافق على السعر
5. **الشركة**: ترى رقم الهاتف الآن
6. **الشركة**: تنهي الطلب

---

## 📁 الملفات الأساسية

### Backend
- `backend/prisma/schema.prisma` - قاعدة البيانات
- `backend/src/controllers/companyController.js` - منطق الشركات
- `backend/src/controllers/orderController.js` - منطق الطلبات
- `backend/src/app.js` - تطبيق رئيسي

### Frontend  
- `flutter_app/lib/features/home/home_screen.dart` - الشاشة الرئيسية

---

## 🔑 متغيرات البيئة الأساسية

في `backend/.env`:
```env
DATABASE_URL="postgresql://user:pass@localhost:5432/rideflow_db"
JWT_SECRET="your_secret_key"
PORT=4000
NODE_ENV=development
```

---

## 🐛 المشاكل الشائعة

### Error: Cannot find database
```bash
# تأكد من أن PostgreSQL يعمل
psql -U postgres -d rideflow_db
```

### Error: JWT token invalid
- تأكد من نسخ التوكن بشكل صحيح
- تحقق من أنه لم ينتهي

### Error: CORS issue
- تحقق من `app.js` وأن CORS مفعل
- تأكد من أن frontend يرسل من نفس origin أو معرّف CORS

---

## ✅ Test Checklist

- [ ] Backend يعمل على 4000
- [ ] Database متصل
- [ ] تسجيل عميل جديد يعمل
- [ ] تسجيل شركة جديدة يعمل
- [ ] إنشاء طلب يعمل
- [ ] Flutter app متصل بـ API

---

## 📊 Structure

```
.
├── backend/
│   ├── src/
│   │   ├── controllers/
│   │   ├── routes/
│   │   ├── middlewares/
│   │   └── app.js
│   └── prisma/
│       └── schema.prisma
├── flutter_app/
│   └── lib/
│       └── features/
│           └── home/
│               └── home_screen.dart
└── docs/
    ├── IMPLEMENTATION_SUMMARY.md
    ├── SETUP_GUIDE.md
    └── FINAL_SUMMARY.md
```

---

## 🎓 مفاهيم أساسية

### Status Flow
```
NEW → COMPANY_REVIEWING → COMPANY_ACCEPTED/REJECTED
                       → PRICE_SENT → CUSTOMER_APPROVED/REJECTED
                                   → CONFIRMED → COMPLETED
```

### Data Visibility
- ❌ قبل: رقم الهاتف مخفي
- ✅ بعد: رقم الهاتف ظاهر

### User Types
- **Customer**: ينشئ طلبات
- **Company**: تدير الطلبات
- **Admin**: يدير كل شيء

---

## 🔗 الروابط المهمة

- [Prisma Docs](https://www.prisma.io/docs/)
- [Express Docs](https://expressjs.com/)
- [Flutter Docs](https://flutter.dev/docs)

---

## 📞 احتاج مساعدة؟

اقرأ:
1. `SETUP_GUIDE.md` - للتثبيت المفصل
2. `IMPLEMENTATION_SUMMARY.md` - لفهم النظام
3. `FILES_CHANGED_SUMMARY.md` - لقائمة التغييرات

---

**Happy coding! 🎉**
