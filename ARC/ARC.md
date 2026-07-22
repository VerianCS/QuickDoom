
---

# 🚀 Architecture & Engineering Plan: Modern Doom Launcher (Flutter Desktop)

## 1. Executive Summary
**Project Name:** OpenZDL / Doom Launcher (Working Title)  
**Target Platform:** Windows, Linux, macOS (Desktop-first)  
**Tech Stack:** Flutter, Dart, Riverpod / BLoC, Hive / JSON, `dart:io`  
**Primary Goal:** A high-performance, cross-platform source port and mod launcher for retro Doom games, offering profile management, drag-and-drop load ordering, and real-time process monitoring.

---

## 2. System Architecture

The application follows **Clean Architecture** combined with a **Feature-First** structure. This separation ensures that OS interactions (`dart:io`, process execution) and file system operations are decoupled from the UI and business logic, making the application highly testable and extensible.

```
                  +-----------------------------------+
                  |      Presentation Layer           |
                  |  (UI Widgets, Riverpod/BLoC)      |
                  +-----------------+-----------------+
                                    |
                                    v
                  +-----------------+-----------------+
                  |         Domain Layer              |
                  |  (Entities, UseCases, Contracts)  |
                  +-----------------+-----------------+
                                    |
                                    v
                  +-----------------+-----------------+
                  |          Data Layer               |
                  |  (Repositories, OS Execution,       |
                  |   File I/O, Hive Storage)         |
                  +-----------------------------------+
```

### Layer Responsibilities

1. **Presentation Layer (UI & State):**
    * Desktop UI controls (Custom title bar, Split panels, Drag-and-Drop lists).
    * State management (Notifier/Controllers) converting UI events into Domain requests.
    * Real-time stream listeners for game process console output (`stdout`/`stderr`).

2. **Domain Layer (Business Logic):**
    * **Entities:** Pure Dart models (`Profile`, `SourcePort`, `IWAD`, `PWAD`).
    * **Use Cases:** Launch Game, Build Command Arguments, Save Profile, Resolve WAD Dependencies.
    * **Interfaces/Contracts:** Abstract definitions for storage and process execution.

3. **Data Layer (System & Persistence):**
    * **Process Engine:** Interacts with `dart:io` (`Process.start`) to execute external binaries safely.
    * **File System Service:** Handles path normalizations, file selection via pickers, and directory scanning.
    * **Storage Repository:** Persists profiles, ports, and app settings into local JSON/Hive storage.

---

## 3. Core Data Entities

```dart
// domain/entities/source_port.dart
class SourcePort {
  final String id;
  final String name;       // e.g., "GZDoom v4.11"
  final String executablePath; // e.g., "C:\Games\GZDoom\gzdoom.exe"
  final String defaultArgs; // e.g., "-nogui"
}

// domain/entities/iwad.dart
class Iwad {
  final String id;
  final String name;       // e.g., "Doom II: Hell on Earth"
  final String path;       // e.g., "C:\Games\WADs\doom2.wad"
}

// domain/entities/pwad.dart
class Pwad {
  final String id;
  final String path;       // e.g., "C:\Mods\brutalv21.pk3"
  final bool isEnabled;
  final int loadOrder;    // Critical: Doom mod load order matters!
}

// domain/entities/launch_profile.dart
class LaunchProfile {
  final String id;
  final String name;       // e.g., "Brutal Doom + Map20"
  final String sourcePortId;
  final String iwadId;
  final List<Pwad> pwadList;
  final String customArgs; // e.g., "+map map01 -skill 4"
}
```

---

## 4. Key Subsystems & Design Patterns

### A. The Launch Command Builder (Strategy & Builder Pattern)
Executing a source port safely requires building an array of command arguments rather than raw string concatenation (to prevent command injection and handle spaces in paths correctly).

```
   [ Launch Profile ] 
           │
           ▼
┌─────────────────────────────────────────┐
│       LaunchCommandBuilder              │
│ 1. Validate paths                       │
│ 2. Append -iwad <path>                  │
│ 3. Append -file <sorted_pwad_paths...>  │
│ 4. Append custom parameters             │
└────────────────────┬────────────────────┘
                     │
                     ▼
             [ Executable Path ] 
                     + 
        [ List<String> Arguments ]
                     │
                     ▼
            Process.start(...)
```

```dart
// domain/usecases/build_launch_command.dart
class LaunchCommandBuilder {
  List<String> buildArgs(LaunchProfile profile, Iwad iwad, List<Pwad> activePwads) {
    final List<String> args = [];

    // 1. Specify IWAD
    args.addAll(['-iwad', iwad.path]);

    // 2. Specify PWADs in explicit load order
    final sortedPwads = activePwads.where((p) => p.isEnabled).toList()
      ..sort((a, b) => a.loadOrder.compareTo(b.loadOrder));

    if (sortedPwads.isNotEmpty) {
      args.add('-file');
      args.addAll(sortedPwads.map((p) => p.path));
    }

    // 3. Append custom CLI arguments safely
    if (profile.customArgs.isNotEmpty) {
      args.addAll(profile.customArgs.split(' '));
    }

    return args;
  }
}
```

### B. Process Execution Engine (Observer Pattern)
The launcher monitors the running game process to handle crashes, log errors, or auto-minimize/restore the launcher window.

```dart
// data/repositories/process_launcher_repository_impl.dart
abstract class IProcessLauncher {
  Future<ProcessStream> launch(String executable, List<String> args);
}

class ProcessStream {
  final Stream<String> outputLogs;
  final Future<int> exitCode;
  
  ProcessStream({required this.outputLogs, required this.exitCode});
}
```

---

## 5. Recommended Project Folder Structure

```text
lib/
├── main.dart
├── app/
│   ├── theme/             # Modern dark/retro UI styling & colors
│   └── router.dart        # Desktop navigation structure
│
├── core/                  # Utilities shared across features
│   ├── utils/             # Path helpers, String extensions
│   ├── services/          # System File Picker wrapper, Shell execution
│   └── constants/          # File extensions (.wad, .pk3, .pk7)
│
└── features/
    ├── launcher/          # Core launching functionality
    │   ├── domain/        # Entities & UseCases
    │   ├── data/          # Process execution & storage impl
    │   └── presentation/  # Main screen, split panes, launch button
    │
    ├── profiles/          # Profile / Preset Manager
    │   ├── domain/
    │   ├── data/
    │   └── presentation/  # Profile list sidebar & dialogs
    │
    ├── wads/              # IWAD and PWAD management
    │   ├── presentation/  # Drag-and-drop WAD list, load-order controls
    │   └── data/          # WAD file validation & metadata reader
    │
    └── console/           # Live game execution logs pane
        └── presentation/  # Terminal/Console output view
```

---

## 6. Development Roadmap (Phased Approach)

### Phase 1: MVP Core (Execution Engine)
- [ ] Configure basic UI layout (Sidebar for profiles, Center pane for mod list).
- [ ] Implement local path selection for GZDoom and IWADs.
- [ ] Implement manual selection of `.wad`/`.pk3` files.
- [ ] Wire up `Process.start` to launch GZDoom with the generated command list.

### Phase 2: Profile Persistence & Drag-and-Drop
- [ ] Integrate **Hive** or **Isar** for local data persistence.
- [ ] Implement drag-and-drop reordering for PWADs using `ReorderableListView`.
- [ ] Add support for desktop OS file drag-and-drop (`desktop_drop` package).
- [ ] Save/Load profiles (e.g., "Vanilla Doom 2", "Brutal Doom", "Heretic Setup").

### Phase 3: Desktop UX Polish
- [ ] Custom dark/cyberpunk window frame using `window_manager`.
- [ ] Real-time game log panel (redirect `stdout`/`stderr` from process to UI).
- [ ] Auto-minimize launcher on game start and restore on game exit.

### Phase 4: Advanced Features (Portfolio Flex)
- [ ] **WAD Reader Service:** Extract title lump/headers or metadata directly from binary `.wad` files.
- [ ] **idgames API Client:** Simple REST integration to search and download community mods directly inside the app.
- [ ] Cross-platform compilation tests (Generate builds for Windows, macOS, and Linux).

---

## 7. Quality Assurance & Engineering Standards

For a junior portfolio, code quality matters significantly more than raw feature count.

1. **Unit Testing:**
    * Unit test `LaunchCommandBuilder` to verify argument ordering.
    * Unit test JSON / Hive data serializations for profiles.
2. **Error Handling:**
    * Validate executable paths before launching (check if file exists).
    * Graceful warning banners if a `.wad` file path is broken/deleted.
3. **Desktop Responsiveness:**
    * Min-window resolution constraint (`800x600`).
    * Keyboard shortcuts (`Ctrl+L` / `Cmd+L` to quick-launch active profile).

---

## 8. Portfolio Showcase Strategy (GitHub Presentation)

To maximize impact on recruiters, format the repository as follows:

* **`README.md` Highlights:**
    * Include a high-quality **GIF/Video demo** showing drag-and-drop load ordering and instant launching.
    * Include an **Architecture Diagram** (like the one in Section 2).
    * Feature an **"Engineering Challenges Solved"** section explaining how you handled cross-platform path resolution and process streaming.
* **CI/CD Pipeline:**
    * Configure **GitHub Actions** to automatically build binaries (`.exe`, `.app`, `.AppImage`) on release. Demonstrating automation skills as a junior is a huge bonus!