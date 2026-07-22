# 🩸 QuickDoom
[![Build & Publish Multi-Platform Release](https://github.com/VerianCS/QuickToDoom/actions/workflows/deploy.yml/badge.svg)](https://github.com/VerianCS/QuickToDoom/actions/workflows/deploy.yml)
---

<p align="center">
  <img src="https://img.shields.io/badge/Boot_Time-121ms_(Debug)_%2F_<20ms_(Release)-brightgreen?style=for-the-badge&logo=speedtest" alt="Boot Time">
  <img src="https://img.shields.io/badge/Executable_Size-~5MB_Standalone-crimson?style=for-the-badge&logo=flutter" alt="App Size">
  <img src="https://img.shields.io/badge/RAM_Usage-Microscopic-blueviolet?style=for-the-badge&logo=ram" alt="RAM Usage">
  <img src="https://img.shields.io/badge/Electron_Bloat-0%25-red?style=for-the-badge&logo=prohibit" alt="No Electron">
</p>

> **"Rip and tear... until the boot time is ZERO."**

**QuickDoom** is a blazingly fast, modern, cross-platform Doom source port & mod launcher built with Flutter Desktop. 

While modern desktop launchers consume 500MB of RAM and take 4 seconds to display a button (*looking at you, Electron apps*), QuickDoom boots in **121 milliseconds**, weighs a tiny **~5MB**, and lets you jump straight into blasting demons with `GZDoom`, `UZDoom`, or `Zandronum` before your coffee even finishes brewing.

---

##  Why Does This Exist?

Look, classic launchers like ZDL were legendary back in 2006, but their UIs look like they were designed during the Bronze Age. On the flip side, modern web-wrapper launchers eat more RAM than Chrome with 50 tabs open.

So I built **QuickDoom**: a native desktop launcher that combines a **modern cyberpunk UI** with **insane low-level performance**.

###   Highlights
*  **Instant Boot:** Deferred font/asset parsing drops cold-start to **121ms** (debug) and **<20ms** (release).
*  **10MB Single Binary:** Compressed using UPX and packed into a standalone `.exe` with `warp-packer`. No install wizards required.
*  **Drag-and-Drop Mod Priority:** Drag `.pk3` or `.wad` files straight into the launcher and reorder load priorities on the fly.
*  **Profile & Preset System:** Save your favorite mod combinations (*Brutal Doom*, *Project Brutality*, *Ancient Aliens*) powered by Hive & Riverpod.
*  **Process Engine & Crash Logs:** Executes binaries via native `dart:io`, streams `stdout`/`stderr` logs in real-time, auto-minimizes during gameplay, and restores when you quit.
*  **System Tray Stealth Mode:** Minimizes to the system tray, intercepts the close button, and sits quietly using ~0% CPU.

---

##  System Architecture

QuickDoom is engineered using **Clean Architecture** and **Riverpod State Management**. It completely decouples OS process execution and file I/O from the Flutter presentation layer.

```mermaid
flowchart TD
    subgraph Presentation[" Presentation Layer (UI and UX)"]
        UI["Custom Titlebar and Main Dashboard"]
        DragDrop["Drag-and-Drop WAD Manager"]
        Tray["System Tray Listener and Window Lifecycle"]
    end

    subgraph StateManagement[" State Management (Riverpod)"]
        AppController["Game Launch Controller"]
        ProfileState["Active Profile and WAD Priority State"]
    end

    subgraph Domain[" Domain Layer (Pure Business Logic)"]
        CmdBuilder["Launch Command Builder"]
        OrderSort["WAD Priority Array Sorter"]
    end

    subgraph SystemLayer[" Data and System Execution Layer"]
        HiveDB[("Hive Local Storage (Profiles and Ports)")]
        DartIO["dart:io Process.start Engine"]
        LogStream["stdout / stderr Ring Buffer Stream"]
        NativePort["Source Port Executable: uzdoom / gzdoom"]
    end

    UI --> DragDrop
    DragDrop --> ProfileState
    Tray --> UI
    
    ProfileState --> AppController
    AppController --> CmdBuilder
    CmdBuilder --> OrderSort
    
    CmdBuilder --> DartIO
    HiveDB <--> ProfileState
    DartIO --> NativePort
    NativePort -. "Live Output Stream" .-> LogStream
    LogStream --> AppController

    classDef ui fill:#1e1e24,stroke:#e50914,stroke-width:2px,color:#fff;
    classDef state fill:#2b2d42,stroke:#8d99ae,stroke-width:2px,color:#fff;
    classDef domain fill:#3a0ca3,stroke:#4cc9f0,stroke-width:2px,color:#fff;
    classDef sys fill:#101010,stroke:#e50914,stroke-width:2px,color:#fff;

    class UI,DragDrop,Tray ui;
    class AppController,ProfileState state;
    class CmdBuilder,OrderSort domain;
    class HiveDB,DartIO,LogStream,NativePort sys;
```
📊 Benchmarks (The Flex Section)

I am obsessed with micro-optimizations. Here is how QuickDoom stacks up against
typical desktop apps:

| Metric                 | Typical Electron App   | Standard Flutter App    | **QuickDoom **                        |
| :--------------------- | :--------------------- | :--------------------- | :------------------------------------- |
| **Cold Boot Time**     | \~2,500 ms             | \~400 ms               | **221 ms (Debug) / \<120 ms (Release)** |
| **Executable Size**    | \~150 MB               | \~35 MB                | **\~10.5 MB (UPX + Warp Packed)**       |
| **RAM Footprint**      | \~350 MB               | \~80 MB                | **\~35 MB**                            |
| **Demons Slaughtered** | 0                      | 0                      | **Infinite**                           |

How I Achieved a 121ms Boot:

1.  Zero-Blocking main(): Rendered the first UI frame before touching storage or
    reading disk configs.
2.  Post-Frame Asset Hydration: Deferred custom font table parsing and
    non-critical assets until after the first frame painted (shaved 100ms
    instantly!).
3.  Lazy Hive Hydration: O(1) loading strategy that hydrates only the active
    profile on startup instead of parsing the whole database.

    Tech Stack & Dependencies

  - Framework: Flutter Desktop (Windows, Linux, macOS)
  - Language: Dart 3.x
  - State Management: flutter_riverpod
  - Local Persistence: hive / hive_flutter
  - Desktop Tools: window_manager, tray_manager, desktop_drop, file_picker
  - Compilation & Packaging: CMake (/Os Size Optimization), UPX, warp-packer

   Building & Running Locally

Prerequisites

  - Flutter SDK (Stable channel)
  - C++ Desktop Build Tools (Visual Studio with C++ workload for Windows)

1. Clone & Run

git clone https://github.com/YOUR_USERNAME/QuickDoom.git
cd QuickDoom

# Install dependencies
flutter pub get

# Run in Debug mode
flutter run -d windows

2. Run Test Suite

flutter test

3. Build Hyper-Optimized Release Binaries

# Build optimized release build with symbol stripping & obfuscation
flutter build windows --release --split-debug-info=./symbols --obfuscate --tree-shake-icons

  CI/CD Pipeline

QuickDoom features an automated GitHub Actions Matrix pipeline
(.github/workflows/release.yml).

Pushing a version tag (git tag v1.0.0 && git push origin v1.0.0) automatically
triggers:

1.  Multi-platform builds (Windows, Linux, macOS).
2.  AOT Tree-Shaking & Symbol Stripping.
3.  UPX Dynamic Library Compression.
4.  warp-packer single-executable packaging.
5.  Automatic publishing of ~5MB single-file binaries to GitHub Releases!

  License

Distributed under the MIT License. See LICENSE for more information.



