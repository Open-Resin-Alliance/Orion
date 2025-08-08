# Glasser - Glassmorphic UI Library

Glasser is an internal Flutter library for Orion that provides comprehensive glassmorphic widgets. It automatically adapts between glass and non-glass themes based on the current `ThemeProvider` state.

## Features

- **Automatic Theme Adaptation**: All widgets automatically switch between glassmorphic and standard styling
- **Clean API**: Simple, intuitive widget names without the "Aware" suffix
- **Drop-in Replacements**: Direct replacements for standard Flutter widgets (e.g., `ElevatedButton` → `GlassButton`)
- **Consistent Glass Effects**: Shared constants ensure uniform glassmorphic styling across all widgets
- **Comprehensive Widget Set**: Complete set of glassmorphic widgets for all UI needs

## Usage Examples

### Basic Setup

```dart
import '../glasser/glasser.dart';

// Wrap your app for glass background support
GlassApp(
  child: MaterialApp(
    home: Scaffold(
      body: YourContent(),
    ),
  ),
)
```

### Common Widget Usage

```dart
// Buttons automatically adapt to glass theme
GlassButton(
  onPressed: () {},
  child: Text('Click Me'),
)

// Switches work like standard Flutter widgets
GlassSwitch(
  value: isEnabled,
  onChanged: (value) => setState(() => isEnabled = value),
)

// Cards get glassmorphic effects when glass theme is active
GlassCard(
  child: ListTile(
    title: Text('Title'),
    subtitle: Text('Subtitle'),
  ),
)

// Dialogs automatically use glass styling
showDialog(
  context: context,
  builder: (context) => GlassAlertDialog(
    title: Text('Confirm'),
    content: Text('Are you sure?'),
    actions: [
      GlassButton(onPressed: () {}, child: Text('OK')),
    ],
  ),
);
```

### Theme Detection

Widgets automatically detect the current theme - no manual checking required:

```dart
// This automatically becomes glassmorphic when ThemeProvider.isGlassTheme is true
GlassButton(onPressed: () {}, child: Text('Auto-adapting'))
```

### Complete Widget List

#### Layout & Navigation

- **GlassApp**: Main app wrapper with glassmorphic background
- **GlassBottomNavigationBar**: Navigation bar with glass styling

#### Interactive Elements

- **GlassButton**: Drop-in replacement for `ElevatedButton`
- **GlassFloatingActionButton**: Glass-styled FAB
- **GlassSwitch**: Toggle switch with glass adaptation

#### Display Components

- **GlassCard**: Card widget with glassmorphic effects
- **GlassDialog**: Custom dialog with glass styling
- **GlassAlertDialog**: Alert dialog with glass effects
- **GlassListTile**: List tile with glass adaptation

#### Selection Components

- **GlassChip**: Basic chip with glass styling
- **GlassFilterChip**: Filter chip that adapts to glass theme
- **GlassChoiceChip**: Choice chip with glassmorphic effects

#### Theme Components

- **GlassThemeSelector**: Theme selection widget with glass support

## Migration from Old System

The new Glasser library uses cleaner names without the "Aware" suffix:

| Old Widget              | New Widget         |
| ----------------------- | ------------------ |
| `GlassAwareApp`         | `GlassApp`         |
| `GlassAwareButton`      | `GlassButton`      |
| `GlassAwareSwitch`      | `GlassSwitch`      |
| `GlassAwareCard`        | `GlassCard`        |
| `GlassAwareFilterChip`  | `GlassFilterChip`  |
| `GlassAwareChoiceChip`  | `GlassChoiceChip`  |
| `GlassAwareDialog`      | `GlassDialog`      |
| `GlassAwareAlertDialog` | `GlassAlertDialog` |

### Migration Steps

1. Replace import:

   ```dart
   // Old
   import '../themes/glassmorphic_widgets.dart';

   // New
   import '../glasser/glasser.dart';
   ```

2. Update widget names:

   ```dart
   // Old
   GlassAwareButton(
     onPressed: () {},
     child: Text('Click'),
   )

   // New
   GlassButton(
     onPressed: () {},
     child: Text('Click'),
   )
   ```

## Architecture

### File Structure

```
lib/glasser/
├── glasser.dart              # Main library export
└── src/
    ├── constants.dart        # Glass styling constants (corner radius, opacity, blur)
    ├── glass_effect.dart     # Glass effect utilities and helpers
    └── widgets/              # Individual widget implementations
        ├── glass_app.dart
        ├── glass_button.dart
        ├── glass_switch.dart
        ├── glass_card.dart
        ├── glass_dialog.dart
        ├── glass_alert_dialog.dart
        ├── glass_bottom_navigation_bar.dart
        ├── glass_floating_action_button.dart
        ├── glass_filter_chip.dart
        ├── glass_choice_chip.dart
        ├── glass_chip.dart
        ├── glass_list_tile.dart
        └── glass_theme_selector.dart
```

### Glass Constants

The library uses shared constants for consistent styling:

- `glassCornerRadius`: 16.0 (standard corner radius)
- `glassSmallCornerRadius`: 8.0 (for smaller elements)
- `glassOpacity`: 0.2 (default glass opacity)
- `glassBlurSigma`: 10.0 (blur effect strength)

## Design Principles

1. **Drop-in Replacements**: Each glass widget is designed as a direct replacement for its Flutter counterpart
2. **Automatic Adaptation**: Widgets automatically detect `ThemeProvider.isGlassTheme` without manual theme checking
3. **Clean API**: Simple, memorable widget names following `Glass[WidgetName]` convention
4. **Modular Structure**: Each widget is self-contained in its own file for maintainability
5. **Consistent Styling**: All glass effects use shared constants from `constants.dart`
6. **No Circular Dependencies**: Glasser provides primitives that Orion widgets can use

## Integration with Orion

### Theme Provider Integration

All glass widgets automatically respond to the `ThemeProvider`:

```dart
Consumer<ThemeProvider>(
  builder: (context, themeProvider, child) {
    // Glass widgets automatically adapt when themeProvider.isGlassTheme changes
    return GlassButton(onPressed: () {}, child: Text('Auto-adapting'));
  },
)
```

### Higher-Level Orion Components

Instead of creating separate glass-aware versions, existing Orion widgets use Glasser primitives:

```dart
// OrionListTile uses GlassSwitch internally
class OrionListTile extends StatelessWidget {
  Widget build(BuildContext context) {
    return ListTile(
      trailing: GlassSwitch(value: value, onChanged: onChanged),
    );
  }
}
```

This maintains clean architecture:

- **Glasser**: Provides low-level glass primitives
- **Orion widgets**: Use Glasser primitives to build complex components
- **No circular dependencies**: Clean separation of concerns

## Contributing

When adding new glass widgets to the library:

1. **Create the widget file** in `src/widgets/` following the naming pattern `glass_[widget_name].dart`
2. **Export the widget** from the main `glasser.dart` file in the appropriate category section
3. **Follow the API pattern**: Make it a drop-in replacement for the equivalent Flutter widget
4. **Use shared constants**: Import and use constants from `constants.dart` for consistent styling
5. **Implement automatic detection**: Use `Provider.of<ThemeProvider>(context).isGlassTheme` to detect glass mode
6. **Document the widget**: Include comprehensive dartdoc comments with usage examples

### Example Widget Template

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orion/util/providers/theme_provider.dart';
import '../constants.dart';

/// A [Widget] that automatically becomes glassmorphic when glass theme is active.
class GlassWidget extends StatelessWidget {
  const GlassWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isGlassTheme = Provider.of<ThemeProvider>(context).isGlassTheme;

    if (isGlassTheme) {
      // Return glassmorphic version
      return Container(/* glass implementation */);
    } else {
      // Return standard version
      return StandardWidget();
    }
  }
}
```
