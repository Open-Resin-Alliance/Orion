/*
* Orion - Debug Screen
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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';

class DebugScreen extends StatefulWidget {
  final Function(ThemeMode) changeThemeMode;

  const DebugScreen({super.key, required this.changeThemeMode});

  @override
  DebugScreenState createState() => DebugScreenState();
}

class DebugScreenState extends State<DebugScreen> {
  final ScrollController _scrollController = ScrollController();
  List<String> logMessages = [];
  int currentPage = 0;
  static const int pageSize = 20;
  Timer? _timer;
  Map<String, int> logCounts = {};

  bool showInfo = true;
  bool showConfig = true;
  bool showFine = true;
  bool showWarning = false;
  bool showSevere = false;

  @override
  void initState() {
    super.initState();
    fetchLogMessages();
    _startAutoUpdate();
  }

  void _startAutoUpdate() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      fetchLogMessages();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchLogMessages() async {
    final List<String> messages = await _getLogMessages();
    setState(() {
      logMessages = messages.reversed.toList();
      _computeLogCounts(logMessages);
    });
  }

  void _computeLogCounts(List<String> messages) {
    Map<String, int> counts = {
      'INFO': 0,
      'WARNING': 0,
      'CONFIG': 0,
      'FINE': 0,
      'SEVERE': 0,
    };
    final logLevelRegex = RegExp(r'(INFO|WARNING|CONFIG|FINE|SEVERE)');

    for (var message in messages) {
      final match = logLevelRegex.firstMatch(message);
      if (match != null) {
        String level = match.group(1)!;
        counts[level] = counts[level]! + 1;
      }
    }

    logCounts = counts;
  }

  Future<List<String>> _getLogMessages() async {
    try {
      Directory logDir = await getApplicationSupportDirectory();
      File logFile = File('${logDir.path}/app.log');
      if (await logFile.exists()) {
        List<String> lines = await logFile.readAsLines();
        return _groupLogMessages(lines);
      } else {
        return ['Log file not found.'];
      }
    } catch (e) {
      return ['Error reading log file: $e'];
    }
  }

  List<String> _groupLogMessages(List<String> lines) {
    final timestampRegex =
        RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{6}');
    List<String> groupedMessages = [];
    StringBuffer currentMessage = StringBuffer();

    for (String line in lines) {
      if (timestampRegex.hasMatch(line)) {
        if (currentMessage.isNotEmpty) {
          groupedMessages.add(currentMessage.toString());
          currentMessage.clear();
        }
      }
      currentMessage.writeln(line);
    }

    if (currentMessage.isNotEmpty) {
      groupedMessages.add(currentMessage.toString());
    }

    return groupedMessages;
  }

  List<String> getFilteredMessages() {
    return logMessages.where((message) {
      final logLevelRegex = RegExp(r'(INFO|WARNING|CONFIG|FINE|SEVERE)');
      final match = logLevelRegex.firstMatch(message);
      if (match != null) {
        final logLevel = match.group(1);
        switch (logLevel) {
          case 'INFO':
            return showInfo;
          case 'WARNING':
            return showWarning;
          case 'CONFIG':
            return showConfig;
          case 'FINE':
            return showFine;
          case 'SEVERE':
            return showSevere;
        }
      }
      return false;
    }).toList();
  }

  void nextPage() {
    if ((currentPage + 1) * pageSize < logMessages.length) {
      setState(() {
        currentPage++;
      });
    }
  }

  void previousPage() {
    if (currentPage > 0) {
      setState(() {
        currentPage--;
      });
    }
  }

  Widget formatLogMessage(String message) {
    final timestampRegex =
        RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{6}');
    final match = timestampRegex.firstMatch(message);

    if (match != null) {
      final timestamp = match.group(0);
      final trimmedTimestamp = timestamp!.substring(0, 19);
      final logLevelRegex = RegExp(r'(INFO|WARNING|CONFIG|FINE|SEVERE)');
      final logLevelMatch = logLevelRegex.firstMatch(message);
      final logLevel = logLevelMatch?.group(1) ?? '';
      final loggerNameRegex = RegExp(r'\[(.*?)\]');
      final loggerNameMatch = loggerNameRegex.firstMatch(message);
      final loggerName = loggerNameMatch?.group(1) ?? '';
      final logContent = message
          .substring(match.end)
          .replaceAll(logLevelRegex, '')
          .replaceAll(loggerNameRegex, '')
          .replaceAll('\n', ' ')
          .trim();

      return Card(
        child: ListTile(
          title: Text(
            '$loggerName - $trimmedTimestamp',
            style: const TextStyle(fontSize: 18),
          ),
          subtitle: Text(
            logContent,
            style: const TextStyle(fontSize: 18),
          ),
          trailing: logLevel.isNotEmpty
              ? Chip(
                  label: Text(logLevel),
                  backgroundColor:
                      _getLogLevelColor(logLevel).withOpacity(0.35),
                )
              : null,
        ),
      );
    } else {
      final cleanedMessage = message.replaceAll('\n', ' ').trim();
      return ListTile(
        title: Text(cleanedMessage),
      );
    }
  }

  Color _getLogLevelColor(String logLevel) {
    switch (logLevel) {
      case 'INFO':
        return Colors.blue;
      case 'WARNING':
        return Colors.red;
      case 'CONFIG':
        return Colors.green;
      case 'FINE':
        return Colors.purple;
      case 'SEVERE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> filteredMessages = getFilteredMessages();
    int totalPages = (filteredMessages.length / pageSize).ceil();

    // Adjust currentPage if it exceeds totalPages
    if (currentPage >= totalPages) {
      currentPage = totalPages > 0 ? totalPages - 1 : 0;
    }

    List<String> currentMessages = filteredMessages.sublist(
        currentPage * pageSize,
        (currentPage + 1) * pageSize > filteredMessages.length
            ? filteredMessages.length
            : (currentPage + 1) * pageSize);

    final theme = Theme.of(context).copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
            (Set<WidgetState> states) {
              return RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: Colors.transparent));
            },
          ),
        ),
      ),
    );

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: FadingEdgeScrollView.fromSingleChildScrollView(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              FilterChip(
                                label: Text(
                                  'All (${logMessages.length})',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                selected: showInfo &&
                                    showWarning &&
                                    showConfig &&
                                    showFine &&
                                    showSevere,
                                onSelected: (bool value) {
                                  setState(() {
                                    showInfo = value;
                                    showWarning = value;
                                    showConfig = value;
                                    showFine = value;
                                    showSevere = value;
                                  });
                                },
                              ),
                              const SizedBox(width: 12.0),
                              const VerticalDivider(
                                width: 1,
                                thickness: 1,
                              ),
                              const SizedBox(width: 12.0),
                              FilterChip(
                                label: Text(
                                  'INFO (${logCounts['INFO'] ?? 0})',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                selected: showInfo,
                                onSelected: (bool value) {
                                  setState(() {
                                    showInfo = value;
                                  });
                                },
                              ),
                              const SizedBox(width: 8.0),
                              FilterChip(
                                label: Text(
                                  'CONFIG (${logCounts['CONFIG'] ?? 0})',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                selected: showConfig,
                                onSelected: (bool value) {
                                  setState(() {
                                    showConfig = value;
                                  });
                                },
                              ),
                              const SizedBox(width: 8.0),
                              FilterChip(
                                label: Text(
                                  'FINE (${logCounts['FINE'] ?? 0})',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                selected: showFine,
                                onSelected: (bool value) {
                                  setState(() {
                                    showFine = value;
                                  });
                                },
                              ),
                              const SizedBox(width: 8.0),
                              FilterChip(
                                label: Text(
                                  'WARNING (${logCounts['WARNING'] ?? 0})',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                selected: showWarning,
                                onSelected: (bool value) {
                                  setState(() {
                                    showWarning = value;
                                  });
                                },
                              ),
                              const SizedBox(width: 8.0),
                              FilterChip(
                                label: Text(
                                  'SEVERE (${logCounts['SEVERE'] ?? 0})',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                selected: showSevere,
                                onSelected: (bool value) {
                                  setState(() {
                                    showSevere = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ListView.builder(
                      itemCount: currentMessages.length,
                      itemBuilder: (context, index) {
                        return formatLogMessage(currentMessages[index]);
                      },
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Column(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: currentPage > 0 ? previousPage : null,
                          style: theme.elevatedButtonTheme.style,
                          child: Text('${currentPage + 1}',
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              currentPage < totalPages - 1 ? nextPage : null,
                          style: theme.elevatedButtonTheme.style,
                          child: Text('${currentPage + 2}',
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
