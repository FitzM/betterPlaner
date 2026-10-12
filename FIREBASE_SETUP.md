# Firebase & Google Sign-In Setup Guide

This application is ready to run locally out-of-the-box (Local-First mode with sample data). Follow these steps to connect your own Firebase project for cloud synchronization and single-user Google Sign-In.

---

## 1. Create a Firebase Project
1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add Project** and give it a name (e.g. `my-getplan-app`).
3. Disable or enable Google Analytics (optional) and click **Create Project**.

---

## 2. Enable Authentication (Google Sign-In)
1. In the Firebase Console, go to **Build > Authentication**.
2. Click **Get Started**.
3. Under the **Sign-in method** tab, click **Google**.
4. Enable the provider, configure the project support email, and click **Save**.

---

## 3. Enable Cloud Firestore
1. In the Firebase Console, go to **Build > Firestore Database**.
2. Click **Create Database**.
3. Select a location near you and choose **Start in production mode**.
4. Click **Create**.

---

## 4. Single-User Security Lockdown
To ensure that **only your Google account** can access the database, deploy the included `firestore.rules`:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      // Allow only your authenticated user ID and specific email:
      allow read, write: if request.auth != null 
                         && request.auth.uid == userId 
                         && request.auth.token.email == 'your_google_email@gmail.com';
    }
  }
}
```

---

## 5. Configure FlutterFire
From your terminal in `/home/FmX/Projects/4_Dart_Flutter/getPlanBetter`:
```bash
# Install the FlutterFire CLI if you haven't yet:
dart pub global activate flutterfire_cli

# Configure your Flutter project with your Firebase project:
flutterfire configure
```
This will automatically generate `lib/firebase_options.dart`.

Then in `lib/main.dart`, uncomment:
```dart
import 'firebase_options.dart';

// inside main():
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

---

## 6. Deploy to Firebase Hosting (Free Evergreen SSL)
```bash
# 1. Build optimized web bundle
flutter build web

# 2. Deploy to Firebase Hosting
firebase deploy --only hosting
```
Your app will be live at:
`https://<your-project-id>.web.app`

It comes with an **automatic, valid SSL certificate that never expires** and is accessible from any computer, phone, or tablet anywhere in the world!
