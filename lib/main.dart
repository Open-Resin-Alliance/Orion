/*
* Orion - An open-source user interface for the Odyssey 3d-printing engine.
* Copyright (C) 2025 Open Resin Alliance
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:orion/backend_service/providers/resins_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart';

import 'package:orion/files/files_screen.dart';
import 'package:orion/files/grid_files_screen.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/home/home_screen.dart';
import 'package:orion/home/startup_gate.dart';
import 'package:orion/l10n/generated/app_localizations.dart';
import 'package:orion/settings/about_screen.dart';
import 'package:orion/settings/settings_screen.dart';
import 'package:orion/status/status_screen.dart';
import 'package:orion/materials/materials_screen.dart';
import 'package:orion/materials/calibration_context_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/backend_service/providers/files_provider.dart';
import 'package:orion/backend_service/providers/config_provider.dart';
import 'package:orion/backend_service/providers/print_provider.dart';
import 'package:orion/backend_service/providers/notification_provider.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/backend_service/providers/analytics_provider.dart';
import 'package:orion/tools/tools_screen.dart';
import 'package:orion/util/error_handling/error_handler.dart';
import 'package:orion/util/providers/locale_provider.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/util/error_handling/connection_error_watcher.dart';
import 'package:orion/util/error_handling/notification_watcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    setWindowTitle('Orion - Open Resin Alliance');
    setWindowMinSize(const Size(480, 480 + 28)); // account for title bar
    if (kDebugMode) {
      setWindowMaxSize(const Size(800, 800));
    }
  }

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

  runApp(const OrionRoot());
}

class OrionRoot extends StatelessWidget {
  const OrionRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => StatusProvider(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => ConfigProvider(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => FilesProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => PrintProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => AnalyticsProvider(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => ManualProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => ResinsProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => CalibrationContextProvider(),
          lazy: true,
        )
      ],
      child: const OrionMainApp(),
    );
  }
}

class OrionMainApp extends StatefulWidget {
  const OrionMainApp({super.key});

  @override
  OrionMainAppState createState() => OrionMainAppState();
}

class OrionMainAppState extends State<OrionMainApp> {
  late final GoRouter _router;
  ConnectionErrorWatcher? _connWatcher;
  NotificationWatcher? _notifWatcher;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  bool _statusListenerAttached = false;
  bool _wasPrinting = false;
  bool _isStatusShown = false;
  // navigatorKey removed; using MaterialApp.router builder context instead

  @override
  void initState() {
    super.initState();
    _initRouter();
  }

  @override
  void dispose() {
    _connWatcher?.dispose();
    _notifWatcher?.dispose();
    super.dispose();
  }

  void _initRouter() {
    _router = GoRouter(
      navigatorKey: _navKey,
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) {
            // Let the StartupGate decide whether to show the startup overlay
            // while the initial backend connection attempt completes. It will
            // render the onboarding screen or the HomeScreen once connected.
            return const StartupGate();
          },
          routes: <RouteBase>[
            GoRoute(
              path: 'home',
              builder: (BuildContext context, GoRouterState state) {
                return const HomeScreen();
              },
            ),
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
              path: 'materials',
              builder: (BuildContext context, GoRouterState state) {
                return const MaterialsScreen();
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
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocaleProvider, ThemeProvider>(
      builder: (context, localeProvider, themeProvider, child) {
        return Provider<Function>.value(
          value: themeProvider.setThemeMode,
          child: _buildAppShell(localeProvider, themeProvider),
        );
      },
    );
  }

  Widget _buildAppShell(
      LocaleProvider localeProvider, ThemeProvider themeProvider) {
    return GlassApp(
      child: Builder(builder: (innerCtx) {
        // Use MaterialApp.router's builder to get a context that has
        // MaterialLocalizations and a Navigator. Install the watcher
        // after the first frame using that context.
        return MaterialApp.router(
          title: 'Orion',
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          theme: themeProvider.lightTheme,
          builder: (ctx, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                final navCtx = _navKey.currentContext;
                // Startup gating is handled by the root route's StartupGate.
                if (_connWatcher == null && navCtx != null) {
                  _connWatcher = ConnectionErrorWatcher.install(navCtx);
                }
                if (_notifWatcher == null && navCtx != null) {
                  _notifWatcher = NotificationWatcher.install(navCtx);
                }
                // Attach a listener to StatusProvider so we can auto-open
                // the StatusScreen when a print becomes active (remote start).
                try {
                  if (!_statusListenerAttached && navCtx != null) {
                    final statusProv =
                        Provider.of<StatusProvider>(navCtx, listen: false);
                    statusProv.addListener(() {
                      try {
                        final s = statusProv.status;
                        final active =
                            (s?.isPrinting == true) || (s?.isPaused == true);
                        if (active && !_wasPrinting) {
                          // Only navigate if not already on /status. Navigate
                          // to status on transition to active print.
                          try {
                            final navState = _navKey.currentState;
                            final sModel = statusProv.status;
                            final initialThumb = statusProv.thumbnailBytes;
                            final initialPath =
                                sModel?.printData?.fileData?.path;
                            // Avoid pushing if we're already showing the
                            // Status screen or we've already pushed it.
                            try {
                              if (_isStatusShown) {
                                // nothing to do
                              } else if (navState != null) {
                                _isStatusShown = true;
                                navState
                                    .push(MaterialPageRoute(
                                  builder: (ctx) => StatusScreen(
                                    newPrint: false,
                                    initialThumbnailBytes: initialThumb,
                                    initialFilePath: initialPath,
                                  ),
                                ))
                                    .then((_) {
                                  // cleared when the pushed route is popped
                                  _isStatusShown = false;
                                });
                              } else {
                                _isStatusShown = true;
                                _router.go('/status');
                                // best-effort: we can't await router navigation
                                // easily here, so keep the flag set briefly
                                Future.delayed(const Duration(seconds: 1), () {
                                  _isStatusShown = false;
                                });
                              }
                            } catch (_) {
                              // Fallback to router navigation if push fails
                              if (!_isStatusShown) {
                                _isStatusShown = true;
                                _router.go('/status');
                                Future.delayed(const Duration(seconds: 1), () {
                                  _isStatusShown = false;
                                });
                              }
                            }
                          } catch (_) {
                            // Fallback to router navigation if push fails
                            _router.go('/status');
                          }
                        }
                        _wasPrinting = active;
                      } catch (_) {}
                    });
                    _statusListenerAttached = true;
                  }
                } catch (_) {}
              } catch (_) {}
            });
            return child ?? const SizedBox.shrink();
          },
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          locale: localeProvider.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        );
      }),
    );
  }
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

bool initialSetupTrigger() {
  if (config.getFlag('firstRun', category: 'machine')) {
    return true;
  }
  return false;
}
