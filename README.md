<div align="center">
  <img src="assets/images/logo.png" alt="Harsh Pay Logo" width="120"/>
  <h1>💳 Harsh Pay</h1>
  <p><strong>The Next-Generation Offline-First Zero-Trust Payment Network</strong></p>
</div>

<br/>

## 🌟 Overview

**Harsh Pay** is a state-of-the-art Flutter mobile application and Next.js cloud ecosystem designed to seamlessly handle money transfers even completely **offline**. Bridging the gap between digital convenience and physical cash reliability, Harsh Pay guarantees that you can pay your friends anywhere—whether you're deep underground in a subway or out in the wilderness without cellular coverage.

---

## 🚀 The Ecosystem

Harsh Pay is split into a mobile client and a web-based backend settlement engine.

### 🌐 The Cloud Backend & Web Dashboard (`harsh_bank_web`)
- **Next.js (React / TypeScript)**: Used as the core web framework. It allows us to build both the user-facing web dashboard and the `/api/` backend routes in a single Vercel-hosted repository.
- **MongoDB Atlas**: The cloud database. We used **Mongoose** to strictly define schemas for `Users`, `Wallets`, and `Transactions`.
- **Clerk**: A drop-in authentication provider handling user sign-ups, secure passwords, and session tokens via Webhooks.

### 📱 The Mobile Client (`harsh_pay`)
- **Flutter & Dart**: Chosen to compile native code to both iOS and Android from a single codebase, critical for a dual-platform offline payment network.
- **Hive**: A lightning-fast, NoSQL local database acting as the offline ledger.
- **Hardware Integrations**: `mobile_scanner` for optical QR data transmission, and `nearby_connections` for high-bandwidth Bluetooth/Wi-Fi Direct radio transmission.

---

## 🔐 The "Zero-Trust" Two-Way Escrow Architecture

The crown jewel of Harsh Pay is how it handles offline money without allowing double-spending fraud.

When an offline payment is made (QR or Radio), the app generates a cryptographic `clientTxId` that acts as a secure envelope:
`txId = {UUID}::{ReceiverClerkId}::{SenderClerkId}`

Both phones log this locally as a `PENDING` transaction. **Balances do not drop instantly.**

**The Settlement Flow:**
1. Whichever user goes online first silently uploads their half of the transaction. The Vercel backend places it in an **Escrow Vault**. No cloud balances are touched.
2. When the other user goes online, the backend retrieves the pending escrow transaction.
3. The backend strictly verifies that the Sender ID, Receiver ID, and Amount **perfectly match** on both sides, and that the transaction is less than 24 hours old.
4. If all checks pass, the backend atomically deducts the sender, credits the receiver, and marks both transactions as `SUCCESS`.

---

## 📡 Intelligent Network Engine

- **Live Background Polling**: The app listens for hardware network changes. When the phone switches from Airplane Mode to Wi-Fi, the app waits exactly 2 seconds for DNS/Routing to settle.
- A background timer fires every 3 seconds to silently upload any offline transactions.
- **Push Notifications**: Powered by `flutter_local_notifications`, the moment the background engine successfully settles an escrow transaction with the cloud, a notification banner pops up instantly.

---

## 🛠️ Getting Started

### Prerequisites
* Flutter SDK (`^3.12.2`)
* Android Studio / Xcode
* A physical device (Bluetooth and Wi-Fi Direct features require a physical device, not an emulator).

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

*(Note: To fully test offline transfers, you will need two physical devices with the app installed).*

---

## 📖 User Guide: How to Setup & Pair

Because Harsh Pay uses a Zero-Trust local vault, your mobile app must be securely "paired" with your cloud account before you can go offline.

1. **Create your Cloud Account:**
   - On a computer or phone, go to the Web Dashboard: [https://harsh-bank.vercel.app](https://harsh-bank.vercel.app)
   - Click **Sign Up** to create your secure account.
   - You will automatically be granted a starting balance in the cloud.

2. **Generate your App Sync ID:**
   - Once logged into the website, navigate to the **Security Profile** tab.
   - Click to reveal or generate your **App Sync ID QR Code**. This is your secure token.

3. **Pair the Mobile App:**
   - Open the Harsh Pay app on your phone.
   - Tap **"I have an account"** or scan the QR Code from your computer screen.
   - The app will instantly download your encrypted `OfflineWallet` and recent transactions into the Hive database.
   
4. **Go Offline & Transact:**
   - You can now turn on Airplane mode or head into the wilderness. Use **Radio Transfer** or **Scan & Pay** to move money. Your local vault will hold the checks until you regain an internet connection!

---

## 🤝 Contributing
Contributions, issues, and feature requests are welcome!

## 📝 License
This project is open-source and available under the [MIT License](LICENSE).
