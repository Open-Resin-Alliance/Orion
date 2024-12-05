/*
* Orion - Markdown Screen
* Copyright (C) 2024 Open Resin Alliance
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownScreen extends StatelessWidget {
  final String? filename;
  final String? changelog;

  const MarkdownScreen({super.key, this.filename, this.changelog});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(filename ?? 'Changelog'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: changelog != null
            ? Markdown(
                data: changelog!,
                styleSheet: _getMarkdownStyleSheet(context),
              )
            : FutureBuilder(
                future: rootBundle.loadString(filename!),
                builder:
                    (BuildContext context, AsyncSnapshot<String> snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return Markdown(
                      data: snapshot.data ?? '',
                      styleSheet: _getMarkdownStyleSheet(context),
                    );
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              ),
      ),
    );
  }

  MarkdownStyleSheet _getMarkdownStyleSheet(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            code: const TextStyle(
              color: Colors.limeAccent,
              backgroundColor: Colors.black,
              fontFamily: 'monospace',
            ),
          )
        : MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            code: const TextStyle(
              color: Colors.deepPurple,
              backgroundColor: Colors.white,
              fontFamily: 'monospace',
            ),
          );
  }
}
