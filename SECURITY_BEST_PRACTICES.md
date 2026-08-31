# 🔒 Security & Best Practices Guide
# دليل الأمان وأفضل الممارسات

---

## 🔐 معايير الأمان (Security Standards)

### 1️⃣ Data Privacy

#### Phone Number Masking
```
Before Customer Approval:
  +201001234567 → +2010****567

After Customer Approval:
  +201001234567 → Visible to assigned company only
```

#### Implementation
- Frontend: Mask in UI
- Backend: Mask in API response
- Database: Store full number (for admin)

### 2️⃣ Authentication

#### JWT Tokens
```javascript
// Token Structure
{
  id: userId,
  role: userRole,
  email: userEmail,
  companyId: companyId (if company),
  companyType: companyType (if company)
}

// Expiration
Access Token: 7 days
Refresh Token: 30 days
```

#### Best Practices
- ✅ Always validate JWT on backend
- ✅ Use HTTPS for token transmission
- ✅ Store tokens in secure storage
- ✅ Implement token refresh logic
- ✅ Clear tokens on logout

### 3️⃣ Authorization

#### Role-Based Access Control (RBAC)
```
Customer:
  - Create orders
  - View own orders
  - Negotiate prices
  - Cancel orders

Company:
  - View orders (company type specific)
  - Accept/reject orders
  - Propose counter prices
  - View customer details (after approval)

Super Admin:
  - View everything
  - Manage companies
  - Manage users
  - View statistics
```

#### Implementation
```javascript
// Middleware check
const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Access denied' });
    }
    next();
  };
};
```

### 4️⃣ API Security

#### Input Validation
```javascript
// Always validate input
if (!name || name.length < 2) {
  return res.status(400).json({ error: 'Invalid name' });
}

if (!email || !email.includes('@')) {
  return res.status(400).json({ error: 'Invalid email' });
}
```

#### SQL Injection Prevention
- ✅ Use Prisma ORM (parameterized queries)
- ✅ Never concatenate user input in queries
- ✅ Validate and sanitize all inputs

#### CORS Configuration
```javascript
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(','),
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

### 5️⃣ Password Security

#### Hashing
```javascript
// Use bcryptjs
const hashedPassword = await bcrypt.hash(password, 12);

// Verify
const isValid = await bcrypt.compare(inputPassword, hashedPassword);
```

#### Requirements
- Minimum 8 characters
- Mix of uppercase, lowercase, numbers
- Enforce in registration

### 6️⃣ Data Encryption

#### Sensitive Data
- Passwords: Hash with bcryptjs
- Tokens: JWTs (encrypted if needed)
- Payment info: Encrypt before storing
- Phone: Mask in responses

---

## 📋 Checklist قبل الإنتاج

### Database Security
- [ ] Backup strategy configured
- [ ] SSL connection to database
- [ ] Database user with minimal privileges
- [ ] Regular backups automated
- [ ] Encryption at rest enabled

### API Security
- [ ] HTTPS enabled
- [ ] CORS configured properly
- [ ] Rate limiting implemented
- [ ] Input validation everywhere
- [ ] Error messages don't leak sensitive info
- [ ] Logging configured
- [ ] Monitoring alerts set

### Application Security
- [ ] Environment variables secure
- [ ] No hardcoded credentials
- [ ] Dependencies up to date
- [ ] Security headers added
- [ ] CSRF protection enabled

### User Authentication
- [ ] Two-factor authentication (optional)
- [ ] Session timeout implemented
- [ ] Token refresh working
- [ ] Logout clears tokens
- [ ] Password reset flow secure

---

## 🚨 Common Vulnerabilities & Prevention

### 1. SQL Injection
**Prevention**:
- Use Prisma ORM ✅
- Parameterized queries ✅
- Input validation ✅

### 2. Cross-Site Scripting (XSS)
**Prevention**:
- Sanitize user input
- Use content security policy
- Encode output

### 3. Cross-Site Request Forgery (CSRF)
**Prevention**:
- Use SameSite cookies
- Validate origin headers
- Use CSRF tokens

### 4. Broken Authentication
**Prevention**:
- Validate JWT properly ✅
- Implement rate limiting
- Secure password storage ✅
- Session timeout

### 5. Sensitive Data Exposure
**Prevention**:
- Use HTTPS ✅
- Mask phone numbers ✅
- Encrypt sensitive data ✅
- Don't log sensitive info

---

## 🔐 Implementation Examples

### Secure Data Masking
```javascript
// In companyController.js
const maskPhone = (phone) => {
  return phone.slice(0, 3) + '****' + phone.slice(-2);
};

// In API response
if (order.status !== 'CONFIRMED') {
  order.customer.phone = maskPhone(order.customer.phone);
}
```

### Secure Authorization Check
```javascript
// In orderController.js
if (order.companyId !== req.user.companyId) {
  return res.status(403).json({ error: 'Access denied' });
}
```

### Secure Password Hashing
```javascript
// In authController.js
const hashedPassword = await bcrypt.hash(password, 12);
const user = await prisma.user.create({
  data: { password: hashedPassword, ... }
});
```

---

## 📊 Security Testing

### Manual Testing
- [ ] Test with invalid tokens
- [ ] Test with wrong role
- [ ] Test unauthorized access
- [ ] Test SQL injection attempts
- [ ] Test XSS payloads

### Automated Testing
```bash
# Use npm audit
npm audit

# Use security scanners
npm install -g snyk
snyk test

# Use OWASP ZAP for API testing
# Use Burp Suite for penetration testing
```

---

## 🔄 Security Maintenance

### Weekly
- [ ] Review security logs
- [ ] Check for failed login attempts
- [ ] Monitor API errors

### Monthly
- [ ] Update dependencies: `npm audit fix`
- [ ] Review access logs
- [ ] Check for suspicious activities

### Quarterly
- [ ] Security audit
- [ ] Penetration testing
- [ ] Review access policies
- [ ] Update security documentation

---

## 📱 Mobile App Security

### Flutter Best Practices
```dart
// Store tokens securely
final prefs = await SharedPreferences.getInstance();
// Use flutter_secure_storage instead!
// prefs.setString('token', token); // ❌ NOT SECURE

// Use flutter_secure_storage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
const storage = FlutterSecureStorage();
await storage.write(key: 'token', value: token); // ✅ SECURE
```

### Certificate Pinning
```dart
// Implement certificate pinning for API calls
// Prevents man-in-the-middle attacks
```

---

## 🔔 Incident Response

### If Breach Detected
1. ⏹️ Stop the attack (disable compromised account)
2. 🔍 Identify scope (what data was accessed)
3. 🛡️ Contain damage (reset passwords, revoke tokens)
4. 📢 Notify users (if necessary)
5. 📊 Analyze (what went wrong)
6. 🔧 Fix (implement patches)
7. 🚀 Deploy (roll out fixes)

---

## 📚 Security Resources

- [OWASP Top 10](https://owasp.org/Top10/)
- [Express Security](https://expressjs.com/en/advanced/best-practice-security.html)
- [Prisma Security](https://www.prisma.io/docs/concepts/more/security)
- [Flutter Security](https://flutter.dev/docs/development/platform-integration/platform-channels/channels-and-platform-integration)

---

## ✅ Security Checklist Template

```markdown
## Pre-Production Security Checklist

### Authentication
- [ ] JWT tokens configured
- [ ] Password hashing implemented
- [ ] Token expiration set

### Authorization
- [ ] Role-based access working
- [ ] Company isolation verified
- [ ] Admin permissions correct

### Data Privacy
- [ ] Phone masking working
- [ ] Sensitive data encrypted
- [ ] Logs don't contain secrets

### API Security
- [ ] CORS configured
- [ ] Input validation enabled
- [ ] Rate limiting active

### Database
- [ ] SSL connection enabled
- [ ] Regular backups automated
- [ ] Encryption at rest enabled

### Deployment
- [ ] HTTPS enabled
- [ ] Security headers set
- [ ] Environment variables secure
- [ ] Monitoring active

### Compliance
- [ ] GDPR compliant
- [ ] Privacy policy updated
- [ ] Terms of service reviewed
```

---

## 🎓 Security Best Practices Summary

1. **Principle of Least Privilege**: Give users only needed access ✅
2. **Defense in Depth**: Multiple layers of security ✅
3. **Fail Secure**: Deny by default ✅
4. **Separation of Duties**: Different roles for different tasks ✅
5. **Audit Everything**: Log and monitor actions ✅

---

**Remember**: Security is not a destination, it's a journey! 🛡️
