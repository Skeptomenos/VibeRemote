# App Distribution Strategy (No Paid Developer Account)

Since we are proceeding with the **Native Swift App** approach but do not have a paid Apple Developer Program membership ($99/year), we must manage the installation and signing of the app manually.

## 1. The "Free Provisioning" Method (Standard)

Apple allows any user to compile and install apps on their own devices for free using a standard Apple ID.

### **The Workflow**
1.  **Build**: Open the project in Xcode on your Mac.
2.  **Target**: Connect your iPhone/iPad via USB cable. Select it as the run destination.
3.  **Sign**: In Xcode **Signing & Capabilities**, log in with your personal Apple ID. Xcode will generate a free provisioning profile.
4.  **Install**: Click the "Run" (Play) button. The app installs on the device.
5.  **Trust**: On the iOS device, go to **Settings > General > VPN & Device Management**, tap your email address, and tap **"Trust"**.

### **The Limitation: The 7-Day Rule**
*   **Expiration**: Apps signed with a free account expire after **7 days**.
*   **Symptom**: The app will crash immediately upon launch or show "App is no longer available".
*   **Resolution**: You must reconnect the device to the Mac, open Xcode, and hit "Run" again. This renews the certificate for another 7 days.

---

## 2. The Automated Solution: AltStore

To avoid the manual weekly re-installation, we can use **AltStore**. This is a third-party tool that automates the re-signing process using your Mac mini (which is acting as our server anyway).

### **How it Works**
1.  **AltServer (Mac mini)**: Runs in the background on your Mac mini. It mimics an Xcode developer session.
2.  **AltStore (iOS)**: An app installed on your phone that manages your sideloaded apps.
3.  **Wi-Fi Sync**: When your phone and Mac mini are on the same Wi-Fi, AltServer wakes up the phone and refreshes the app signature automatically in the background.

### **Setup Requirements**
*   **Mac mini**: Install AltServer (free).
*   **Finder**: Enable "Show this iPhone when on Wi-Fi" in Finder for your device.
*   **Apple ID**: Use an App-Specific Password for AltStore security.

### **Result**
The app behaves like a permanent installation. As long as you are home (or on the same network) occasionally, the app will never expire.

---

## 3. Decision for AgentOS

We will develop using **Method 1 (Free Provisioning)** for the initial development phase. 
Once the app is stable and in daily use, we will transition to **Method 2 (AltStore)** to make it a "set and forget" utility on your devices.
