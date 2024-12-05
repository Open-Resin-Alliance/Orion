/*
* Orion - An open-source user interface for the Odyssey 3d-printing engine.
* Copyright (C) 2024 TheContrappostoShop
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:orion/home/home_screen.dart';
import 'package:orion/status/status_screen.dart';
import 'package:orion/files/files_screen.dart';
import 'package:orion/files/grid_files_screen.dart';
import 'package:orion/settings/settings_screen.dart';
import 'package:orion/settings/about_screen.dart';
import 'package:orion/themes/themes.dart';
import 'package:orion/util/error_handling/error_handler.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:orion/tools/tools_screen.dart';
import 'package:orion/util/orion_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_size/window_size.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorHandler.onErrorDetails(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorHandler.onError(error, stack);
    return true;
  };

  Logger.root.level = Level.ALL; // Log all log levels

  // Create a StreamController to queue log messages
  final StreamController<LogRecord> logStreamController =
      StreamController<LogRecord>();

  // Listen to log records and add them to the StreamController
  Logger.root.onRecord.listen((record) {
    logStreamController.add(record);
  });

  // Mutex to ensure sequential writes
  final Mutex writeMutex = Mutex();

  // Maximum log file size in bytes (e.g., 5 MB)
  const int maxLogFileSize = 5 * 1024 * 1024;

  // Process log messages sequentially
  logStreamController.stream.listen((record) async {
    await writeMutex.acquire();
    try {
      Directory logDir = await getApplicationSupportDirectory();
      File logFile = File('${logDir.path}/app.log');

      // Check if log file needs rotation
      if (await logFile.exists() && await logFile.length() > maxLogFileSize) {
        // Rotate the log file
        final rotatedLogFile = File('${logDir.path}/app.log.1');
        if (await rotatedLogFile.exists()) {
          await rotatedLogFile.delete();
        }
        await logFile.rename(rotatedLogFile.path);
        logFile = File('${logDir.path}/app.log');
      }

      final logMessage =
          '${record.time}\t[${record.loggerName}]\t${record.level.name}\t${record.message}\n';

      stdout.writeln(
          '${record.time}\t[${record.loggerName}]\t${record.level.name}\t${record.message}');

      // Write the log message atomically
      await logFile.writeAsString(logMessage,
          mode: FileMode.append, flush: true);
    } catch (e, stackTrace) {
      // Log the error to the console or another logging mechanism
      print('Error writing to log file: $e');
      print('StackTrace: $stackTrace');
    } finally {
      writeMutex.release();
    }
  });

  runApp(const Orion());
}

class Mutex {
  Completer<void>? _completer;

  Future<void> acquire() async {
    while (_completer != null) {
      await _completer!.future;
    }
    _completer = Completer<void>();
  }

  void release() {
    _completer?.complete();
    _completer = null;
  }
}

void macDebug() {
  if (kDebugMode) {
    setWindowTitle('Orion Debug - Prometheus mSLA');
    setWindowMinSize(const Size(480, 480));
    setWindowMaxSize(const Size(800, 800));
  }
}

/// The route configuration.
final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const HomeScreen();
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'files',
          builder: (BuildContext context, GoRouterState state) {
            return const FilesScreen();
          },
        ),
        GoRoute(
          path: 'gridfiles',
          builder: (BuildContext context, GoRouterState state) {
            return const GridFilesScreen();
          },
        ),
        GoRoute(
          path: 'settings',
          builder: (BuildContext context, GoRouterState state) {
            return const SettingsScreen();
          },
          routes: <RouteBase>[
            GoRoute(
              path: 'about',
              builder: (BuildContext context, GoRouterState state) {
                return const AboutScreen();
              },
            ),
          ],
        ),
        GoRoute(
          path: 'status',
          builder: (BuildContext context, GoRouterState state) {
            return const StatusScreen(
              newPrint: false,
            );
          },
        ),
        GoRoute(
            path: 'tools',
            builder: (BuildContext context, GoRouterState state) {
              return const ToolsScreen();
            }),
      ],
    ),
  ],
);

/// The main app.

class Orion extends StatefulWidget {
  const Orion({super.key});

  @override
  OrionState createState() => OrionState();
}

class OrionState extends State<Orion> {
  late ThemeMode _themeMode;
  late OrionConfig _config;

  @override
  void initState() {
    super.initState();
    _config = OrionConfig();
    _themeMode = _config.getThemeMode();
  }

  void changeThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    _config.setThemeMode(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.macOS) {
      macDebug();
    }
    return Provider<Function>.value(
      value: changeThemeMode,
      child: SizedBox(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: true,
          routerConfig: _router,
          theme: themeLight,
          darkTheme: themeDark,
          themeMode: _themeMode,
        ),
      ),
    );
  }
}
