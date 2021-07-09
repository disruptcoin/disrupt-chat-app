# Disrupt Mobile App

This is the open source Disrupt Mobile App. This app is powered by the popular and powerful Flutter framework by Google. We also use Google Cloud / Firebase services on the backend to power the database. 

## Getting Started With Flutter 

This project is a Decentralized Finance (DeFi) and Mobile communications application for a Flutter .

A few resources to get you started with Flutter:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook) 

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# Flutter Firebase Chat Documentation

Flutter Firebase Chat is a real time chatting app with video calling support based on Flutter, Firebase, and Agora.io. You can run this app on both platforms: Android and iOS. Also you can easily customize and refine it for yourself, since it uses a BLoC pattern.

![Preview image](/preview.jpg)

## Main features

* One-to-one chatting
* Group chatting
* One-to-one video calling via Agora.io
* Image sharing
* Email authentication
* Implemented BLoC pattern

## Flutter packages

* firebase_auth
* cloud_firestore
* firebase_storage
* timeago
* email_validator
* flutter_bloc
* image_picker
* platform_action_sheet
* photo_view
* flutter_slidable
* agora_rtc_engine
* permission_handler

## Code Overview

The app is built using Flutter and uses Cloud Firestore as a database. The app also uses Agora.io to make one-to-one video calls and flutter_bloc in order to implement the BLoC pattern.

The app uses the following Project Structure:

### Project Structure

```
...
   ├── pages/          # This folder contains many different folders, each of which corresponds to a different screen of the app.
   ├── services/       # This folder contains services that connect with the Cloud Firestore.
   ├── themes/         # This folder contains so far only one file that stores the colors used in the project.
   ├── utils/          # This folder contains all the common items (e.g. constants used in the project).
   ├── widgets/        # This folder contains widgets which are used in multiple different screens.
   └── app.dart        # This file contains the main StatelessWidget (a MaterialApp wrapped in the necessary BlocProvider).
```

Also each folder in `pages/` can contain the following files/folders:

```
...
   ├── widgets/                    # This folder contains widgets which are used in the current screen only.
   ├── screen_bloc.dart            # This file contains BLoC implementation for the current screen.
   ├── screen_event.dart           # This file contains BLoC's events for the current screen.
   ├── screen_model.dart           # This file contains models which are used in the current screen.
   ├── screen_page.dart            # This file contains the page's internal content of the current screen.
   ├── screen_state.dart           # This file contains BLoC's states for the current screen.
   └── screen.dart                 # This file contains all exports for the current screen.
```

## Project Setup

In order to setup the project you need to follow 3 steps: setup Agora.io, setup Firebase, and setup your flutter project.

### Agora.io setup

1. Create a developer account at https://www.agora.io/.
2. Create a project.
3. Copy the app ID and set the const AGORA_APP_ID in lib/src/utils/settings.dart.

### Firebase setup

1. Go to https://console.firebase.google.com and create a project.
2. Go to "Authentication/Sign-in method" and enable "Email/Password".
3. Go to "Database" and create a Cloud Firestore database.
4. Go to "Database/Rules" and publish this code:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth.uid != null;
    }
  }
}
```
5. Go to "Project Settings", add an Android app to your project. Follow the assistant, and download the generated google-services.json file and place it inside android/app.
6. Add an iOS app to your project. Follow the assistant, download the generated GoogleService-Info.plist file. Do NOT follow the steps named "Add Firebase SDK" and "Add initialization code" in the Firebase assistant. Open ios/Runner.xcworkspace with Xcode, and within Xcode place the GoogleService-Info.plist file inside ios/Runner.

### Flutter setup

1. Install package dependencies:
```
flutter pub get
```
2. Use one of these commands to build the project:
```
flutter build ios
flutter build apk
flutter build appbundle
``` 