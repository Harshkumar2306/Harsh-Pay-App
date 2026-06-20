<div align="center">
  <img src="assets/images/logo.png" alt="Harsh Pay Logo" width="120"/>
  <h1>💳 Harsh Pay</h1>
  <p><strong>The Next-Generation Offline-First Payment Application</strong></p>
</div>

<br/>

## 🌟 Overview

**Harsh Pay** is a state-of-the-art Flutter mobile application designed to seamlessly handle money transfers even completely **offline**. Using peer-to-peer Bluetooth technologies, local encrypted databases, and an intelligent background sync engine, Harsh Pay guarantees that you can pay your friends anywhere—whether you're deep underground in a subway or out in the wilderness without cellular coverage.

---

## 🚀 Key Features

* **📴 True Offline Payments**: Uses Google's `nearby_connections` to transfer funds securely over Bluetooth/Wi-Fi Direct without any internet connection.
* **🔒 Encrypted Local Vault**: Powered by `Hive`, all user wallets, balances, and transaction histories are stored locally using military-grade encryption.
* **☁️ Cloud Auto-Sync**: The moment your device connects to the internet, Harsh Pay seamlessly syncs all pending offline transactions to the cloud.
* **📷 ML-Powered QR Scanner**: Instantly scan to pay using lightning-fast on-device Machine Learning (Google ML Kit).
* **🔔 Smart Notifications**: Native Android push notifications and an in-app beautiful Notification Center timeline.
* **🎨 Premium Aesthetics**: Built with a sleek, dark-mode-first glassmorphism design language using fluid micro-animations.

---

## 🛠️ Technology Stack

* **Framework:** Flutter (Dart)
* **Architecture:** Riverpod + Repository Pattern
* **Local Database:** Hive (Offline-First)
* **Networking:** Dio & Connectivity Plus
* **P2P Transfers:** Nearby Connections API
* **Camera/ML:** Mobile Scanner & QR Flutter
* **Routing:** GoRouter

---

## ⚙️ Getting Started

### Prerequisites
* Flutter SDK (`^3.12.2`)
* Android Studio / VS Code
* An Android Device (Bluetooth features require a physical device, not an emulator).

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Harshkumar2306/Harsh-Pay-App.git
   cd Harsh-Pay-App
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

### Building for Release
Due to the integration of Google ML Kit and R8 Minification, use the provided GitHub Actions pipeline or run:
```bash
flutter build apk --release
```

---

## 📸 Screenshots

*( )*

---

<div align="center">
  <p>Built with ❤️ by Harsh Kumar</p>
</div>
