# Changelog

## Version 0.3.2 - Like a Feather

### Licensing

- Orion is now licensed under the Apache License 2.0, making it easier for third parties to develop their own versions.

### New Features and Improvements

#### Keyboard Enhancements

- The Orion Keyboard now allows for presetText.
- With presetText, text fields can now be edited, rather than being cleared every time they're opened.
- Increased sizing of the text for Orion Keyboard components.
- The contrast of buttons has been greatly improved in light mode.

#### Debug Screen

- A public Debug Screen has been implemented, which now displays Orion logs in real-time.
- Logging is now asynchronous and with file rotation.
- INFO, CONFIG and FINE are shown by default, with WARNING and SEVERE as optional filters.

### Bug Fixes and Code Quality

- Fixes have been made to MoveZScreen; It now correctly utilized the Odyssey API and calculates the correct heights.
- UpdateScreen has been visually enhanced.
- A loading state was added to DetailsScreen, ensuring that we fully render everything before revealing it to the user.

### Known Issues

- When enabling Developer Mode, the Debug bottomNavigationItem will not show until a state update.
- WifiScreen sometimes shows a blank screen. When this happens, simply re-open the page by switching to the AboutScreen and back.

---

## Version 0.3.1 - Portrait Mode

### New Features and Improvements

#### Portrait Mode Enhancements

- Significant improvements have been made to the portrait mode, which is the default orientation for the Prometheus Mini.
- A new setting has been added to allow manual screen rotation.

#### WiFi Screen Refactor

- The WiFi screen has been completely refactored.
- A QR code has been added, which will eventually direct users to the WebUI.

### Bug Fixes and Code Quality

- Various fixes have been implemented to enhance overall code quality.
- Improvements include better code readability and maintainability.

---

## Version 0.3.0 - Feature Complete TouchUI

### New Features

- Implemented ToolsScreen (Exposure, Move Z).
- Implemented Settings and Updating Screens.
- Redesigned Home, Status, Details, and About Screen.

### Bug Fixes

- WiFi screen actually works now.

### Enhancements

- Updated and streamlined design.
- Enhanced error handling.

### Documentation Updates

- Fixed wrong information in OrionPi.sh description.

### Known Issues

- DetailsScreen and StatusScreen thumbnail scaling is broken.

---

## Version 0.2.0 - Initial Beta Release

### New Features

- Implemented support for starting, pausing, resuming, and canceling prints.
- Added an 'About Orion' page.

### Bug Fixes

- Resolved issues with fetching API subdirectories.

### Enhancements

- Improved text readability on smaller screens.
- Enhanced error handling.

### Documentation Updates

- Added initial documentation.

### Known Issues

- Several features, including homing, are currently unavailable.
