# Copilot Instructions for Orion

Welcome to the Orion codebase! This document provides essential guidance for AI coding agents to be productive in this project.

## Project Overview

Orion is a Flutter-based UI for controlling mSLA 3D printers via the Odyssey engine. It runs primarily on Linux SBCs (Raspberry Pi) and supports three theme modes: light, dark, and glassmorphic. The app uses Provider pattern for state management and go_router for navigation.

## Architecture Overview

- **Three-Layer Theme System**: `OrionThemeMode` enum supports light/dark/glass modes via `ThemeProvider`
- **Glasser Library**: Internal glassmorphic widget library (`lib/glasser/`) with automatic theme adaptation
- **API Communication**: HTTP-based communication with Odyssey engine via `ApiService` singleton
- **Config System**: `OrionConfig` class handles persistent settings with vendor theme override support
- **Logging**: Comprehensive logging with file rotation using `Logger.root` and StreamController

## Key Architectural Patterns

### Theme Architecture

```dart
// Use new Glasser widgets (NOT GlassAware* - those are deprecated)
import 'package:orion/glasser/glasser.dart';

GlassButton(onPressed: () {}, child: Text('Click Me'))  // Auto-adapts to theme
```

### API Service Pattern

```dart
final ApiService _api = ApiService();  // Singleton pattern
final response = await _api.getStatus();  // All methods are async
```

### State Management

```dart
// Use Provider pattern consistently
Consumer<ThemeProvider>(
  builder: (context, themeProvider, child) => // Widget tree
)
```

## Critical Developer Workflows

### Building for Raspberry Pi

```bash
flutter pub get
flutter build linux --target-platform linux-arm64
# Use orionpi.sh for automated deploy: ./orionpi.sh <IP> <USER> <PASS>
```

### Localization Workflow

```bash
flutter gen-l10n                    # Regenerate after ARB changes
dart run test/translation_audit.dart # Audit for missing translations
```

### Glasser Migration (IMPORTANT)

The codebase is migrating from `GlassAware*` to clean `Glass*` widgets:

- ❌ `GlassAwareButton` → ✅ `GlassButton`
- ❌ `GlassAwareCard` → ✅ `GlassCard`
- ❌ `GlassAwareDialog` → ✅ `GlassDialog`

## Project-Specific Conventions

### Glassmorphic Theming (Current Focus)

- **Use Glasser Library**: `import '../glasser/glasser.dart'`
- **Automatic Adaptation**: Widgets detect `ThemeProvider.isGlassTheme` automatically
- **No Manual Theme Checking**: Let Glasser widgets handle theme switching
- **Glass Background**: Use `GlassApp` wrapper for glassmorphic backgrounds

### Configuration System

- **OrionConfig Singleton**: Handles all persistent settings
- **Vendor Override**: `mandateTheme` flag prevents user theme changes
- **Environment-Aware**: Uses `ORION_CFG` environment variable for config path

### Error Handling Patterns

```dart
// Centralized error handling
import 'package:orion/util/error_handling/error_handler.dart';
FlutterError.onError = ErrorHandler.onErrorDetails;
```

### Navigation Pattern

```dart
// Use go_router consistently
context.go('/status');  // Navigation
GoRoute(path: '/screen', builder: (context, state) => Screen())  // Routing
```

## Integration Points

- **Odyssey API**: RESTful HTTP communication on localhost:12357 (configurable)
- **Flutter-Pi**: Native ARM Linux deployment target
- **PrometheusOS**: Complete OS distribution including Orion + Odyssey

## Development Environment

- **Target Platform**: Linux ARM64 (Raspberry Pi 4 primarily)
- **Font**: AtkinsonHyperlegible (accessibility-focused)
- **Material Design**: Material 3 with custom color schemes via `flex_seed_scheme`
- **Logging**: File-based with automatic rotation (5MB limit)

## Common Patterns

- **ValueNotifier**: Use for simple state management within widgets
- **Timer.periodic**: Pattern for real-time status updates (see `StatusScreen`)
- **Future/Async**: All API calls are async with proper error handling
- **Responsive UI**: Check landscape/portrait modes for layout adaptation

For questions or contributions, refer to the [GitHub repository](https://github.com/Open-Resin-Alliance/Orion).
