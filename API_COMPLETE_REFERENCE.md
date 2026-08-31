# 🔌 Complete API Documentation
# التوثيق الشامل لجميع الـ API Endpoints

---

## 📌 أساسيات الـ API

### Base URL
```
Development: http://localhost:4000
Production: https://api.rideflow.app (مثال)
```

### Authentication
جميع الطلبات (ما عدا Register/Login) تحتاج:
```
Authorization: Bearer {accessToken}
```

### Response Format
```json
{
  "success": true,
  "data": { ... },
  "message": "...",
  "statusCode": 200
}
```

---

## 👥 Company Endpoints - نقاط نهاية الشركات

### 1. Register Company (تسجيل شركة جديدة)
```
POST /api/company/register
```

**Request Body:**
```json
{
  "companyName": "Best Limousine",
  "companyType": "LIMOUSINE",  // LIMOUSINE or SHIPPING
  "contactPerson": "Ahmed Mohamed",
  "phone": "+201001234567",
  "password": "StrongPassword123",
  "address": "Cairo, Egypt"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "userId": "user123",
    "companyId": "company123",
    "companyType": "LIMOUSINE",
    "status": "pending"
  },
  "message": "Company registered successfully. Awaiting admin approval."
}
```

**Status Codes:**
- `201` - Company created, awaiting approval
- `400` - Invalid input
- `409` - Company already exists

---

### 2. Company Login (تسجيل دخول الشركة)
```
POST /api/company/login
```

**Request Body:**
```json
{
  "email": "company@email.com",
  "password": "StrongPassword123"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
    "companyId": "company123",
    "companyType": "LIMOUSINE"
  },
  "message": "Login successful"
}
```

**Status Codes:**
- `200` - Login successful
- `401` - Invalid credentials
- `403` - Company not approved

---

### 3. Get Company Dashboard (لوحة تحكم الشركة)
```
GET /api/company/dashboard
Authorization: Bearer {token}
```

**Query Parameters:**
```
?status=NEW&page=1&limit=10
```

**Response:**
```json
{
  "success": true,
  "data": {
    "company": {
      "id": "company123",
      "name": "Best Limousine",
      "type": "LIMOUSINE",
      "status": "active"
    },
    "statistics": {
      "totalOrders": 45,
      "newOrders": 5,
      "reviewingOrders": 2,
      "acceptedOrders": 15,
      "confirmedOrders": 20,
      "completedOrders": 3
    },
    "recentOrders": [...]
  }
}
```

---

### 4. Get Company Orders (الطلبات المتاحة)
```
GET /api/company/orders
Authorization: Bearer {token}
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "order123",
      "status": "NEW",
      "serviceType": "LIMOUSINE",
      "customerOfferPrice": 300,
      "customerPhone": "+2010****567",  // Masked
      "createdAt": "2024-08-25T10:00:00Z"
    }
  ]
}
```

---

### 5. Review Order (مراجعة طلب)
```
POST /api/company/orders/{orderId}/review
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "notes": "Reviewing this order"
}
```

**Response:**
```json
{
  "success": true,
  "data": { "status": "COMPANY_REVIEWING" },
  "message": "Order is now being reviewed"
}
```

---

### 6. Accept Order (قبول بالسعر المقترح)
```
POST /api/company/orders/{orderId}/accept
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "notes": "Order accepted"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "orderId": "order123",
    "status": "COMPANY_ACCEPTED",
    "finalPrice": 300
  },
  "message": "Order accepted at customer's offered price"
}
```

---

### 7. Reject Order (رفض الطلب)
```
POST /api/company/orders/{orderId}/reject
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "rejectionReason": "Too far from our service area"
}
```

**Response:**
```json
{
  "success": true,
  "data": { "status": "COMPANY_REJECTED" },
  "message": "Order rejected"
}
```

---

### 8. Send Counter Offer (إرسال عرض سعر جديد)
```
POST /api/company/orders/{orderId}/counter-offer
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "offerPrice": 400,
  "notes": "New price based on current traffic"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "orderId": "order123",
    "status": "PRICE_SENT",
    "companyOfferPrice": 400,
    "priceOfferId": "priceOffer123"
  },
  "message": "Counter offer sent to customer"
}
```

---

## 📦 Order Endpoints - نقاط نهاية الطلبات

### 1. Create Limousine Order (إنشاء طلب ليموزين)
```
POST /api/orders/limousine
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "pickupLocation": {
    "latitude": 30.0444,
    "longitude": 31.2357,
    "address": "Cairo Airport"
  },
  "dropoffLocation": {
    "latitude": 30.1000,
    "longitude": 31.3000,
    "address": "Downtown Cairo"
  },
  "passengerCount": 3,
  "dateTime": "2024-08-26T14:00:00Z",
  "notes": "Please bring champagne",
  "offerPrice": 300
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "orderId": "order123",
    "status": "NEW",
    "serviceType": "LIMOUSINE",
    "customerOfferPrice": 300
  },
  "message": "Order created successfully"
}
```

---

### 2. Create Shipping Order (إنشاء طلب شحن)
```
POST /api/orders/shipping
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "pickupAddress": "123 Main Street, Cairo",
  "dropoffAddress": "456 Market Road, Giza",
  "shipmentType": "BOX",  // BOX, PALLET, etc.
  "shipmentDetails": "10 boxes of electronics",
  "weight": 50,
  "dimensions": "1x1x1 meter",
  "dateTime": "2024-08-26T15:00:00Z",
  "notes": "Fragile items, handle with care",
  "offerPrice": 250
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "orderId": "order124",
    "status": "NEW",
    "serviceType": "SHIPPING",
    "customerOfferPrice": 250
  },
  "message": "Shipping order created successfully"
}
```

---

### 3. Get Customer Orders (عرض جميع الطلبات)
```
GET /api/orders
Authorization: Bearer {token}
```

**Query Parameters:**
```
?status=NEW&serviceType=LIMOUSINE&page=1&limit=10
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "order123",
      "status": "NEW",
      "serviceType": "LIMOUSINE",
      "customerOfferPrice": 300,
      "company": null,  // Not assigned yet
      "priceOffers": []
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 25
  }
}
```

---

### 4. Get Order Details (تفاصيل الطلب)
```
GET /api/orders/{orderId}
Authorization: Bearer {token}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "order123",
    "status": "PRICE_SENT",
    "serviceType": "LIMOUSINE",
    "customer": {
      "id": "customer123",
      "name": "Fatima Ahmed",
      "phone": "+2010****567",  // Masked until approval
      "email": "fatima@email.com"
    },
    "company": {
      "id": "company123",
      "name": "Best Limousine"
    },
    "customerOfferPrice": 300,
    "priceOffers": [
      {
        "id": "priceOffer123",
        "offerPrice": 400,
        "status": "PENDING",
        "sentAt": "2024-08-25T12:00:00Z"
      }
    ]
  }
}
```

---

### 5. Approve Price (قبول السعر الجديد)
```
POST /api/orders/{orderId}/approve-price
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "priceOfferId": "priceOffer123"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "orderId": "order123",
    "status": "CUSTOMER_APPROVED",
    "finalPrice": 400,
    "companyPhoneVisible": true
  },
  "message": "Price approved. Customer details now visible to company."
}
```

**Note:** After this endpoint, company can see full phone number.

---

### 6. Reject Price (رفض السعر الجديد)
```
POST /api/orders/{orderId}/reject-price
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "priceOfferId": "priceOffer123",
  "reason": "Price too high"
}
```

**Response:**
```json
{
  "success": true,
  "data": { "status": "CUSTOMER_REJECTED" },
  "message": "Price rejected. Negotiation can continue."
}
```

---

### 7. Confirm Order (تأكيد الطلب)
```
POST /api/orders/{orderId}/confirm
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "notes": "Ready for pickup"
}
```

**Response:**
```json
{
  "success": true,
  "data": { "status": "CONFIRMED" },
  "message": "Order confirmed. Company can start service."
}
```

---

### 8. Complete Order (إنهاء الطلب - Company Only)
```
POST /api/orders/{orderId}/complete
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "notes": "Service completed successfully",
  "rating": 5
}
```

**Response:**
```json
{
  "success": true,
  "data": { "status": "COMPLETED" },
  "message": "Order marked as completed"
}
```

---

### 9. Cancel Order (إلغاء الطلب)
```
POST /api/orders/{orderId}/cancel
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "reason": "Found another service"
}
```

**Response:**
```json
{
  "success": true,
  "data": { "status": "CANCELLED" },
  "message": "Order cancelled"
}
```

---

## 🛡️ Admin Endpoints - نقاط نهاية المسؤول

### 1. Get Pending Companies (الشركات المعلقة)
```
GET /api/admin/companies/pending
Authorization: Bearer {token}
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "company123",
      "name": "Best Limousine",
      "type": "LIMOUSINE",
      "contactPerson": "Ahmed",
      "phone": "+201001234567",
      "status": "pending",
      "createdAt": "2024-08-25T10:00:00Z"
    }
  ]
}
```

---

### 2. Approve Company (الموافقة على الشركة)
```
POST /api/admin/companies/{companyId}/approve
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "notes": "Company verified and approved"
}
```

**Response:**
```json
{
  "success": true,
  "data": { "status": "active" },
  "message": "Company approved successfully"
}
```

---

### 3. Reject Company (رفض الشركة)
```
POST /api/admin/companies/{companyId}/reject
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "reason": "Incomplete documentation"
}
```

**Response:**
```json
{
  "success": true,
  "data": { "status": "rejected" },
  "message": "Company rejected"
}
```

---

### 4. Get All Orders (جميع الطلبات)
```
GET /api/admin/orders
Authorization: Bearer {token}
```

**Query Parameters:**
```
?serviceType=LIMOUSINE&status=COMPLETED&page=1&limit=20
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "order123",
      "status": "COMPLETED",
      "serviceType": "LIMOUSINE",
      "customer": { ... },
      "company": { ... },
      "finalPrice": 400
    }
  ]
}
```

---

### 5. Get All Customers (جميع العملاء)
```
GET /api/admin/customers
Authorization: Bearer {token}
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "customer123",
      "name": "Fatima Ahmed",
      "email": "fatima@email.com",
      "phone": "+201001234567",
      "totalOrders": 15,
      "totalSpent": 3500
    }
  ]
}
```

---

### 6. Get All Companies (جميع الشركات)
```
GET /api/admin/companies
Authorization: Bearer {token}
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "company123",
      "name": "Best Limousine",
      "type": "LIMOUSINE",
      "status": "active",
      "totalOrders": 45,
      "totalRevenue": 12500
    }
  ]
}
```

---

### 7. Get Admin Statistics (الإحصائيات)
```
GET /api/admin/stats
Authorization: Bearer {token}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "users": {
      "total": 1000,
      "customers": 850,
      "drivers": 50,
      "companies": 100
    },
    "orders": {
      "total": 5000,
      "limousine": 3000,
      "shipping": 2000,
      "completed": 4500,
      "cancelled": 300,
      "confirmedPending": 200
    },
    "companies": {
      "total": 100,
      "pending": 5,
      "active": 90,
      "rejected": 5,
      "limousineCompanies": 60,
      "shippingCompanies": 40
    },
    "revenue": {
      "total": 150000,
      "completed": 135000,
      "pending": 15000
    }
  }
}
```

---

## ⚠️ Error Responses

### 400 Bad Request
```json
{
  "success": false,
  "error": "INVALID_INPUT",
  "message": "Phone number is invalid"
}
```

### 401 Unauthorized
```json
{
  "success": false,
  "error": "UNAUTHORIZED",
  "message": "Invalid or expired token"
}
```

### 403 Forbidden
```json
{
  "success": false,
  "error": "FORBIDDEN",
  "message": "You don't have permission to access this resource"
}
```

### 404 Not Found
```json
{
  "success": false,
  "error": "NOT_FOUND",
  "message": "Order not found"
}
```

### 500 Internal Server Error
```json
{
  "success": false,
  "error": "SERVER_ERROR",
  "message": "An unexpected error occurred"
}
```

---

## 🔑 Status Values

### Order Statuses
- `NEW` - مُنشأ للتو
- `COMPANY_REVIEWING` - الشركة تراجع
- `COMPANY_ACCEPTED` - قبول من الشركة
- `COMPANY_REJECTED` - رفض من الشركة
- `PRICE_SENT` - عرض سعر جديد
- `CUSTOMER_APPROVED` - موافقة العميل
- `CUSTOMER_REJECTED` - رفض العميل
- `CONFIRMED` - تأكيد نهائي
- `COMPLETED` - انتهى
- `CANCELLED` - ملغى

### Company Statuses
- `pending` - في الانتظار
- `active` - نشط
- `rejected` - مرفوض

### Service Types
- `LIMOUSINE` - ليموزين
- `SHIPPING` - شحن

---

## 📱 Real-time Events (Socket.IO)

### Listening Events

```javascript
socket.on('order_status_changed', (data) => {
  // Order status updated
  console.log(data);
});

socket.on('price_offer_received', (data) => {
  // Company sent new price offer
});

socket.on('order_accepted', (data) => {
  // Company accepted the order
});
```

### Emitting Events

```javascript
socket.emit('join_order', { orderId: 'order123' });
```

---

## 🧪 Testing Tips

### Using cURL
```bash
# Register company
curl -X POST http://localhost:4000/api/company/register \
  -H "Content-Type: application/json" \
  -d '{"companyName":"Test","companyType":"LIMOUSINE",...}'

# Login
curl -X POST http://localhost:4000/api/company/login \
  -H "Content-Type: application/json" \
  -d '{"email":"company@test.com","password":"pass"}'

# Get dashboard
curl -X GET http://localhost:4000/api/company/dashboard \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Using Postman
1. Create collection
2. Set Base URL: http://localhost:4000
3. Create requests for each endpoint
4. Use Authorization tab for Bearer token
5. Test different scenarios

---

## 📞 Rate Limiting

```
Default: 100 requests per 15 minutes
Per endpoint: Check response headers
```

---

**Last Updated**: 25 August 2024
**API Version**: 1.0.0
**Stability**: Production Ready ✅
