# RideFlow App - Deployment Guide for Friend

## ✅ Status: App Configured for Online Use

Your Flutter app is **fully configured** to work online with the live backend. Your friend does NOT need your computer running - the app connects directly to the cloud server.

---

## 🎯 What Your Friend Needs to Do

### 1. **Install the APK**
- Download `rideflow-app-release.apk` from you
- Open file on Android phone
- Tap "Install"
- Tap "Open" after installation completes

### 2. **First Launch**
- App will open with login screen
- **No internet connection issues** - it's already configured to use the online backend at `https://zoon-api.onrender.com`

### 3. **Sign In**
Your friend can either:

#### **Option A: Customer Sign In** (Recommended)
- Enter phone number (e.g., 01012345678)
- Enter password
- Access: Home, wallet, order tracking, trips

#### **Option B: Admin Sign In** (For Admin Dashboard)
- Email: `ayman01aay@gmail.com`
- Password: `admin123`
- Access: All admin features (drivers, shipments, analytics)

---

## 🔧 App Configuration

The app is configured with:
- **Backend URL**: `https://zoon-api.onrender.com` (production)
- **Auth**: JWT token-based (stored locally, no device pairing needed)
- **All APIs**: Already pointing to live server

**No setup or environment variables needed.**

---

## ⚙️ Troubleshooting

### "Cannot connect to backend"
- Check phone internet connection
- Render free tier servers may sleep after 15 min inactivity (takes ~30s to wake up)
- Wait 30 seconds and retry

### "Login fails even with correct password"
- Clear app data: Settings → Apps → RideFlow → Storage → Clear Data
- Restart app
- Try again

### "Can't see orders/trips"
- Ensure you're logged in as customer (phone/password)
- Go to Home tab → Pull down to refresh
- Wait 2-3 seconds for data to load

---

## 📱 What Your Friend Can Do

✅ View home dashboard  
✅ Manage wallet and add funds  
✅ View order history  
✅ Track active trips  
✅ View transaction history  
✅ Use all customer features  

**All without needing your PC running!**

---

## 🚀 APK Build Status

Due to Windows Gradle caching issues, the APK needs to be built using one of these methods:

### Method 1: On Linux/Mac
```bash
cd flutter_app
flutter clean
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

### Method 2: On Windows (Alternative)
```powershell
# Open new PowerShell, navigate to flutter_app folder
flutter clean
flutter build apk --release --verbose
```

### Method 3: Using WSL on Windows
```bash
wsl
cd /mnt/c/Users/Cloud\ Tech/Desktop/z/flutter_app
flutter clean
flutter build apk --release
```

### Method 4: CI/CD (Recommended)
- Push to GitHub
- Use GitHub Actions to build APK
- Download build artifact

---

## 📋 Next Steps

1. **Build the APK** using one of the methods above
2. **Transfer** `app-release.apk` to your friend (Google Drive, WhatsApp, etc.)
3. **Your friend installs** on their Android phone
4. **They sign in** with their credentials or admin account
5. **Done!** - No local backend needed

---

## 🔐 Security Notes

- JWT tokens stored securely in SharedPreferences
- Tokens refresh automatically
- No personal data stored permanently
- Each device gets its own session token

---

## 📞 Support

For issues:
1. Check backend health: `https://zoon-api.onrender.com/api/health`
2. Verify internet connection on phone
3. Clear app cache if login fails
4. Ensure app has internet permission in Android settings

---

**Your friend is ready to go!** 🚀
