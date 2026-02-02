# 🛡️ SentinLNK: Tactical Mesh Communication System

![Project Status](https://img.shields.io/badge/Status-Prototype-4D5D53?style=for-the-badge)
![Tech Stack](https://img.shields.io/badge/Flutter-Dart-02569B?style=for-the-badge&logo=flutter)
![Security](https://img.shields.io/badge/Encryption-AES--256-FF4500?style=for-the-badge)

> **"Comms Check. Green Light."**
> SentinLNK is a decentralized, offline messaging application designed for defense personnel operating in communication-denied environments.

---

## 🎯 Mission Objective
In modern warfare or disaster relief, cellular networks and internet infrastructure are the first to fail. **SentinLNK** bridges this gap by creating an ad-hoc mesh network using low-power radio (LoRa) and Bluetooth Low Energy (BLE).

This repository contains the **Flutter-based Tactical Client**, capable of interfacing with LoRa hardware to send encrypted messages without a central server.

---

## ⚡ Key Capabilities

### 🔒 **Secure & Offline**
* **AES-256 Encryption:** All messages are encrypted locally before transmission.
* **Zero Infrastructure:** Works completely offline using peer-to-peer mesh protocols.

### 📡 **Tactical Interface**
* **Military-Grade UI:** High-contrast "Matte Charcoal" & "Tactical Olive" theme designed for low-light visibility.
* **Radar Scanner:** Visual feedback for node discovery and signal strength (RSSI).
* **Stealth Mode:** Minimal battery consumption with dark mode optimization.

### 📱 **Cross-Platform Deployment**
* Built on **Flutter** for rapid deployment to Android (Soldiers) and iOS (Commanders).
* Responsive design adaptable to tactical tablets and ruggedized phones.

---

## 🛠️ Tech Stack

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Framework** | Flutter (Dart) | UI & Logic Layer |
| **State Mgmt** | StatefulWidget | Lightweight storyboard controller |
| **Hardware Link** | flutter_blue_plus | BLE Interface for LoRa Radios (Planned) |
| **Visuals** | Lucide Icons | Standardized tactical iconography |
| **Time Sync** | Intl Package | Precision timestamping |

---

## 📂 Project Structure

A modular, feature-first architecture designed for scalability.

```text
lib/
├── core/                  # Global configurations
│   └── theme/             # Tactical Color Palette (#1A1A1A, #4D5D53)
├── presentation/          # UI Layer
│   ├── controllers/       # State Management (Storyboard Logic)
│   ├── widgets/           # Reusable Components (Radar, Pulse, Buttons)
│   └── screens/           # Application Panels
│       ├── splash/        # Initialization
│       ├── home/          # Dashboard (Connected/Disconnected states)
│       ├── scanning/      # Node Discovery UI
│       └── chat/          # Encrypted Messaging Interface
└── main.dart              # Application Entry Point