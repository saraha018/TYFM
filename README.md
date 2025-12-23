# 💌 tyfm (To You From Me)
tyfm is a digital time-capsule application built with Flutter. It allows users to write letters to their future selves, attach meaningful images, and "lock" them away until a specific date and time. It's a space for reflection, goal-tracking, and surprising your future self with memories.

✨ Features
Future Messaging: Write rich-text letters and set a precise unlock date and time.

Media Attachments: Securely attach images to your messages to capture the moment visually.

The "Vault": A dedicated space to view your locked messages, showing a countdown until they can be opened.

Secure Locking: Messages are cryptographically "locked" until the timer expires.

Push Notifications: Get notified the exact moment a message from your past self becomes available.

🛠️ Tech Stack
Frontend: Flutter (Dart)

Backend: Firebase (Firestore, Storage, and Cloud Functions)

Build System: Gradle with Kotlin DSL (build.gradle.kts)

Architecture: Provider/Riverpod for State Management

Local Support: Java 8+ API desugaring for compatibility across older Android versions.

⚙️ Technical Highlights
Modern Build Configuration
The project utilizes the latest Android build standards, including:

JVM Toolchain: Configured for JDK 17 to ensure consistent compilation across Java and Kotlin.

Kotlin 2.2.0: Leveraging the latest stable Kotlin features and performance improvements.

Scheduled Unlocking Logic
To ensure messages remain private until the intended time, the app uses a combination of client-side visibility logic and server-side verification to prevent "cheating" by changing the system clock.

🚀 Getting Started
Prerequisites:

Flutter SDK

Android Studio / VS Code

A Firebase Project

Installation:

Bash

git clone https://github.com/yourusername/tyfm.git
cd tyfm
flutter pub get
Run the App:

Bash

flutter run
