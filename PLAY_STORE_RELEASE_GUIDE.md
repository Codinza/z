# 🚀 دليل نشر تطبيق RideFlow على Google Play Store
## Google Play Store Release Guide

---

## 📋 المتطلبات الأساسية

✅ **لديك بالفعل:**
- Keystore file للتوقيع
- Flutter SDK محدث
- Android SDK محدث

---

## 🔧 المرحلة الأولى: إعداد التطبيق

### 1️⃣ تحديث معرف التطبيق (Package ID)

**الحالية:** `com.example.rideflow.rideflow_app`  
**المقترح:** `com.rideflow.app` (أو أي معرف يناسب شركتك)

**الملفات التي تحتاج للتحديث:**
- `android/app/build.gradle` - `applicationId`
- `android/app/src/debug/AndroidManifest.xml`
- `android/app/src/profile/AndroidManifest.xml`
- `android/app/src/main/AndroidManifest.xml`

### 2️⃣ تحديث معلومات الإصدار

**الملف:** `flutter_app/pubspec.yaml`
```yaml
version: 1.0.0+1  # Major.Minor.Patch+BuildNumber
```

**ملاحظة:** 
- الرقم الأول بعد `+` هو `versionCode` (يجب أن يزيد مع كل نشر)
- الباقي هو `versionName` (يراه المستخدمون)

### 3️⃣ تحديث `build.gradle` للتوقيع

ستحتاج إلى:
```gradle
signingConfigs {
    release {
        keyAlias = 'keyalias'           // من keystore
        keyPassword = 'password'         // كلمة مرور المفتاح
        storeFile = file('keystore.jks') // مسار الـ keystore
        storePassword = 'password'       // كلمة مرور الـ keystore
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.release
        // ... باقي الإعدادات
    }
}
```

---

## 🛠️ المرحلة الثانية: بناء التطبيق

### أ) بناء App Bundle (AAB) - **الأفضل للـ Play Store**

```bash
cd flutter_app
flutter build appbundle --release
```

**الناتج:**
- المسار: `build/app/outputs/bundle/release/app-release.aab`
- الحجم: حوالي 50-100 MB (قبل التحسين)

### ب) بناء APK (إذا احتجت لاختبار قبل الرفع)

```bash
# APK واحد
flutter build apk --release

# APKs متعددة (حسب الأجهزة)
flutter build apks --release
```

---

## 📱 المرحلة الثالثة: إعداد Google Play Console

### خطوات إنشاء التطبيق:

1. **قم بتسجيل الدخول** إلى [Google Play Console](https://play.google.com/console)

2. **اختر "تطبيق جديد"** (Create app)
   - الاسم: "RideFlow" (أو الاسم التسويقي)
   - اللغة الافتراضية: العربية
   - النوع: تطبيق (Application)
   - مجاني/مدفوع: اختر حسب نموذج عملك

3. **ملأ التفاصيل الأساسية** (على الجانب الأيسر):
   - ```
     ℹ️ إعداد التطبيق → التطبيق الأساسي
     ```
   - معرف التطبيق: `com.rideflow.app`
   - اسم التطبيق: `RideFlow`
   - النوع: اختر المناسب
   - الفئة: Transportation/Lifestyle

---

## 📝 المرحلة الرابعة: ملء الـ Store Listing

### في القسم **📋 Store listing**:

#### أ) المعلومات الأساسية
- **العنوان:** RideFlow - الليموزين والشحن
- **الوصف المختصر (80 حرف):**
  ```
  تطبيق ليموزين وشحن متقدم مع تفاوض السعر الحي
  ```

- **الوصف الكامل:**
  ```
  🚘 RideFlow - منصة الليموزين والشحن الموحدة
  
  ✨ المميزات:
  • اختيار من خدمات الليموزين أو الشحن
  • عرض وتفاوض أسعار حقيقي مع الشركات
  • تتبع طلبك بالخريطة المباشرة
  • دفع آمن وشفاف
  • تقييمات حقيقية من المستخدمين
  
  🔒 أمان وخصوصية:
  • بيانات محمية بـ encryption
  • رقم الهاتف مخفي حتى موافقة الشركة
  • نظام تقييمات شفاف
  ```

#### ب) الصور والفيديوهات
- **الصور**: 4-8 صور عالية الدقة (1080x1920 أو 1440x2560)
  - لقطة من واجهة التطبيق
  - شاشة البحث عن الخدمة
  - شاشة التفاوض على السعر
  - شاشة التتبع المباشر
  - شاشة التقييم

- **الصورة الرئيسية** (Icon): 512x512 بصيغة PNG
- **لقطات الشاشة**: حد أدنى 2، حد أقصى 8

#### ج) الفئة والمحتوى
- الفئة: `Transportation` أو `Lifestyle`
- تقييم المحتوى: اختر المناسب (عادة G أو PG)
- البيانات الحساسة: اختر ما ينطبق

#### د) معلومات الاتصال
- البريد الإلكتروني للدعم
- موقع الويب (إن وجد)
- سياسة الخصوصية (إلزامي)

---

## 📋 المرحلة الخامسة: اختبار الإصدار (Pre-launch Report)

### 1. تحميل AAB المبدئي

```
إدارة الإصدارات → نسخة مبدئية من الاختبار (Testing → Internal testing)
```

- اضغط "إنشاء نسخة" (Create release)
- اختر "أضف AAB أو APK جديد"
- حمل الملف من: `flutter_app/build/app/outputs/bundle/release/app-release.aab`

### 2. اختبر مع Internal Testing
- أضف حسابات اختبار (نماذج بريد)
- جرب التطبيق على أجهزة مختلفة
- تحقق من:
  - تسجيل الدخول
  - الاتصال بالـ API
  - الخدمات الأساسية

---

## 🚀 المرحلة السادسة: الإطلاق الفعلي

### 1. إنشاء Release النهائي

```
إدارة الإصدارات → الإنتاج (Production)
```

### 2. تحميل AAB النهائي

- تأكد من أن `versionCode` جديد (1.0.0+2 على الأقل)
- حمل AAB من:
  ```bash
  flutter_app/build/app/outputs/bundle/release/app-release.aab
  ```

### 3. ملراجعة المتطلبات

قبل النشر، تحقق من:

- ☑️ **السياسات:**
  - سياسة الخصوصية (رابط صحيح)
  - الشروط والأحكام
  - سياسة الاستعادة

- ☑️ **المحتوى:**
  - جميع الصور محملة
  - لا توجد أخطاء إملائية
  - الأيقونة واضحة ومناسبة

- ☑️ **التطبيق:**
  - لا يوجد رسائل خطأ عند الفتح
  - جميع الأذونات معلنة
  - لا يستخدم واجهات APIs محظورة

### 4. ارسل للمراجعة

- اضغط **Submit for Review** (إرسال للمراجعة)
- سيستغرق عادة 3-24 ساعة

---

## 📊 الأذونات المطلوبة (Permissions)

تأكد من `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- مطلوب للموقع الجغرافي -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- مطلوب للصور -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- مطلوب للإنترنت -->
<uses-permission android:name="android.permission.INTERNET" />
```

---

## 🔐 ملاحظات أمنية

⚠️ **قبل النشر:**

1. **تحديث API Base URL**
   - تأكد من استخدام production server (ليس localhost)
   - الملف: `lib/core/config/app_config.dart`

2. **إزالة debug flags**
   ```dart
   debugShowCheckedModeBanner: false,
   debugShowMaterialGrid: false,
   ```

3. **تفعيل ProGuard/R8**
   - في `android/app/build.gradle`:
   ```gradle
   buildTypes {
       release {
           minifyEnabled true
           shrinkResources true
       }
   }
   ```

4. **حماية الـ Keystore**
   - لا تشارك ملف `keystore.jks` مع أي أحد
   - احفظه في مكان آمن

---

## 📈 بعد النشر

### المراقبة والتحديثات:

1. **راقب الـ Crashes**
   ```
   Crashes and ANRs → تحليل الأخطاء
   ```

2. **اقرأ التقييمات**
   ```
   Ratings and reviews → إجابة على التعليقات
   ```

3. **حدث الإصدار**
   - أضف ميزات جديدة
   - أصلح الأخطاء المبلغ عنها
   - كل تحديث: `versionCode++`

---

## 🆘 استكشاف الأخطاء

### "الرفض من قبل فريق المراجعة"

**الأسباب الشائعة:**
- سياسة الخصوصية غير صحيحة
- الأذونات المطلوبة غير مبررة
- استخدام APIs محظورة
- الرسوم الإضافية غير واضحة

**الحل:**
- اقرأ بريد الرفض بعناية
- صحح المشاكل
- أعد الإرسال

### "الخطأ: Keytool not found"

```bash
# تأكد من وجود keytool
# عادة يكون في: JDK/bin/
```

---

## 📞 طلب الدعم

- **دعم Google Play:** [support.google.com/googleplay](https://support.google.com/googleplay)
- **دعم Flutter:** [flutter.dev/support](https://flutter.dev/support)

---

**آخر تحديث:** 2026-08-29
