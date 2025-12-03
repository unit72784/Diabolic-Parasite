
# 🚀 Diabolic Parasite — Firmware Update Guide

Hi everyone!
This guide will walk you through updating your **Diabolic Parasite** to the latest firmware release, available here:

👉 **[https://github.com/unit72784/Diabolic-Parasite/releases](https://github.com/unit72784/Diabolic-Parasite/releases)**

Whether you're updating the **ESP32-S3** firmware, recovering from self-destruct mode, or updating the **WCH CH554**, this guide covers everything in a safe, step-by-step format.

---

# 🔧 Updating the ESP32-S3 Firmware

You have two ways to update the ESP32-S3:

1. **OTA Update (Recommended — easiest and safest)**
2. **Recovery Mode Flashing (If OTA fails / device bricked / self-destruct mode)**

---

## ✅ 1. OTA Update (Recommended)

This is the easiest method and works on all units that shipped with the **preloaded factory firmware**.

### **Step 1 — Prepare the Firmware File**

* Connect your device (phone or laptop) to the **Diabolic Parasite Wi-Fi AP**.
* Download the file: **ESPfirmware.bin**

### **Step 2 — Upload the Firmware**

1. Open your browser and go to the Web UI.
2. Navigate to:
   **Settings → Update**
3. Select the `.bin` file you downloaded.
4. Click **Upload**.

You will see:

> **Update Successful**
> Do not unplug your Diabolic Parasite.
> It will reboot shortly...

Wait for the reboot.

### 🎉 Done!

Your **ESP32-S3 firmware is now updated successfully.**

---

## 🚑 2. ESP32-S3 Recovery Flash (If OTA Fails)

Use this method if:

* OTA update failed
* You are recovering from **Self-Destruct mode**

### **Step 1 — Download Required Files**

Download all three of these:

* [`ESPFlasher.ps1`](https://github.com/unit72784/Diabolic-Parasite/blob/main/ESPFlasher.ps1)
* [`esptool-v5.1.0-windows-amd64.zip`](https://github.com/espressif/esptool/releases/download/v5.1.0/esptool-v5.1.0-windows-amd64.zip)
* `ESPfirmware.bin`
  (or `ESPrecovery.bin` if recovering from self-destruct)

### **Step 2 — Prepare the Flashing Folder**

Create a new folder and put all files inside:

* `ESPFlasher.ps1`
* `ESPfirmware.bin` (or `ESPrecovery.bin`)
* Extract the ZIP so that **esptool.exe** is in the same folder

**All three MUST be in the same directory.**

### **Step 3 — Open PowerShell in the Folder**

Inside the folder:

1. Hold **Shift**
2. Right-click an empty area
3. Choose **Open PowerShell window here**

### **Step 4 — Enter Download Mode on the Parasite**

On your Diabolic Parasite:

1. Locate the **IO0 button**

   * It is the **top-left button on the bottom side** of the PCB.
2. **Hold IO0**
3. Plug the Parasite into your computer’s USB port
4. Release IO0
5. A new **COM port** will appear (this is download mode)

### **Step 5 — Flash the Firmware**

Run:

```powershell
.\ESPFlasher.ps1
```

* The script will auto-detect the COM port
* The flashing will start immediately
* **Do not unplug the device until it completes**

### 🛠 Recovering from Self-Destruct Mode

Follow the **exact same steps**, but use:

* `ESPrecovery.bin` instead of `ESPfirmware.bin`

---

# 🔧 Updating the WCH CH554 Firmware

This process updates the USB Host microcontroller.

---

## ⚠️ BEFORE YOU BEGIN

**Disable Fast Startup in the Web UI:**

1. Connect to your Diabolic Parasite Wi-Fi
2. Open the Web UI
3. Go to: **Settings → Disable FastStartup**

This ensures proper USB enumeration during flashing.

---

## Step-by-Step CH554 Flashing Guide

### **Step 1 — Install WCH ISP Tool**

Download and install [the latest **WCHISP Studio** from WCH’s official website.](https://www.wch-ic.com/downloads/WCHISPTool_Setup_exe.html)

### **Step 2 — Configure WCHISP**

1. Open **WCHISPStudio**
2. On the left, choose:
   **MCU Series View → E8051USB (CH54x/CH55x)**
3. Set the following:

| Option          | Value |
| --------------- | ----- |
| **Chip Series** | CH55x |
| **Chip Model**  | CH554 |
| **Dnld Port**   | USB   |

### **Step 3 — Download the Firmware File**

Download the file:

* `WCHfirmware.bin`
* In “Object File 1”, select your `WCHfirmware.bin`

### **⚠️Step 4 — Configure the Download Settings⚠️**

In the **Download Config** section:

* Set **Download CFG Pin → P1.5**

> ⚠️ VERY IMPORTANT
> If you forget to set the config pin to **P1.5**, you may permanently lose the ability to reflash the CH554.

**Your app GUI should look like this:**

<img width="1416" height="852" alt="Untitled" src="https://github.com/user-attachments/assets/e60c847d-6b44-4d61-bbd9-90c7291cbd87" />


### **Step 5 — Connect the Parasite via USB**

You will need a **male-to-male USB cable**:

1. Plug one end into the **female USB-A port** of the Diabolic Parasite (the same port used for keyboards)
2. Plug the other end into your PC
3. WCHISP should now detect the CH554 automatically

### **Step 6 — Flash the Firmware**


* Click **Download**

If the flash succeeds, you're done.

### **Step 7 — Re-enable Fast Startup**

After flashing:

1. Connect to the Diabolic Parasite Wi-Fi again
2. Open the Web UI
3. Re-enable **FastStartup** in Settings

---

# 🎉 Update Complete!

If you face any issues, you can always reach out on Discord:
**@3amoonee**
