# Orion: The Resin UI &nbsp;&nbsp;&nbsp; [![Discord Link](https://discordapp.com/api/guilds/1281738817417777204/widget.png?style=shield)](https://discord.gg/beFeTaPH6v)

[![GitHub license](https://img.shields.io/github/license/Open-Resin-Alliance/Orion.svg?style=for-the-badge)](https://github.com/Open-Resin-Alliance/Orion/blob/main/LICENSE)
[![GitHub release](https://img.shields.io/github/release/Open-Resin-Alliance/Orion.svg?style=for-the-badge)](https://github.com/Open-Resin-Alliance/Orion/releases)

Orion is a user interface designed to control [Odyssey](https://github.com/TheContrappostoShop/Odyssey). It's tailored to run with a wide variety of devices, primarily Linux SBCs.

> :warning: **Orion is currently under active development. We recommend exercising caution when using it for the first time and advise against unattended printing.**

## Table of Contents

- [About Orion](#about-orion)
- [Features](#features)
- [Getting Started](#getting-started)
  - [Variant 1: Installing PrometheusOS](#variant-1-installing-prometheusos)
  - [Variant 2: Manual Compilation](#variant-2-manual-compilation)
  - [Variant 3: Using the Orion Script](#variant-3-using-the-orion-script)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## Features

Orion offers a range of features designed to enhance your 3D printing experience:

- **User-friendly Interface:** An intuitive interface for controlling mSLA printers, suitable for both beginners and experienced users.
- **Real-time Monitoring:** Keep track of your print progress and status in real-time.
- **File Management:** Simplified process of uploading and selecting print files.
- **Customizable Print Settings:** Fine-tune your prints according to your specific needs.

## Getting Started

To get started with Orion, follow one of these steps:

### Variant 1: Installing PrometheusOS

PrometheusOS is an all-in-one solution that includes both Odyssey and Orion. Here's how to install it:

1. **Prerequisites:** Ensure you have a Raspberry Pi model compatible with PrometheusOS.
2. **Installation:** Visit the [PrometheusOS GitHub page](https://github.com/TheContrappostoShop/PrometheusOS) and follow the detailed instructions there to install PrometheusOS on your Raspberry Pi.

### Variant 2: Manual Compilation

If you prefer to have more control over the build process, you can manually compile the Orion project using the Dart and Flutter extensions in Visual Studio Code. Here's how:

1. **Prerequisites:** Ensure that you have Visual Studio Code installed on your machine. You also need to have the Dart and Flutter extensions installed.
2. **Open the Project:** Open the Orion project in Visual Studio Code.
3. **Prepare the Environment:** Fetch the project dependencies by running the command `flutter pub get` in the terminal.
4. **Build the Project:** Build the project by running the command `flutter build linux --target-platform linux-arm64` in the terminal.
5. **Verify the Build:** Check the `build` directory in the Orion project directory for the compiled Flutter bundle.
6. **Deploy the Application:** Deploy the Flutter bundle to your Raspberry Pi.

### Variant 3: Using the Orion Script

The `orionpi.sh` script is a convenient way to build and deploy Orion to a Raspberry Pi. Here's how to use it:

1. **Prerequisites:** Ensure that you have [flutterpi_tool](https://pub.dev/packages/flutterpi_tool) installed on your host machine. On the target machine (Raspberry Pi), you should have [flutter-pi](https://github.com/ardera/flutter-pi) installed.
2. **Prepare the Script:** Download the `orionpi.sh` script from the Orion repository and give it execute permissions using the command `chmod +x orionpi.sh`.
3. **Run the Script:** Run the script with the necessary arguments. The command should look like this: <br>`./orionpi.sh <IP_ADDRESS> <USERNAME> <PASSWORD>`.
4. **Wait for Completion:** The script will build the Flutter bundle, copy it to the Raspberry Pi, and run it.
5. **Verify the Deployment:** Check if the Orion application is running on your Raspberry Pi.

## Contributing

We welcome and appreciate contributions to Orion! If you're interested in contributing, please:

1. **Fork the Repository:** Fork the Orion repository and create a new branch for your feature or bug fix.
2. **Make Your Changes:** Implement your feature or fix the bug, ensuring that the code passes all tests.
3. **Submit a Pull Request:** Submit a pull request with a clear and detailed description of your changes.

## License

> The previous GPLv3 licensing has been superseded. However, any version of Orion previously released under GPLv3 may continue to be distributed and used under the terms of GPLv3.

Orion is now licensed under the [Apache License 2.0](LICENSE).

## Contact

If you have any questions, feedback, or suggestions, please don't hesitate to contact us on [TheContrappostoShop Discord](https://discord.gg/GFUn9gwRsj) & [Open Resin Alliance Discord!](https://discord.gg/beFeTaPH6v)
