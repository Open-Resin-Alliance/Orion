/*
* Orion - Error Dialog
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

import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/error_handling/error_details.dart';

void showErrorDialog(BuildContext context, String errorCode) {
  ErrorDetails? errorDetails =
      errorLookupTable[errorCode] ?? errorLookupTable['default'];

  WidgetsBinding.instance.addPostFrameCallback((_) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return GlassAlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade400,
                size: 26,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      errorDetails!.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Code: $errorCode',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade400,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Text(
            _cleanErrorMessage(errorDetails.message),
            style: const TextStyle(
              fontSize: 18,
              height: 1.5,
            ),
          ),
          actions: [
            GlassButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        );
      },
    );
  });
}

/// Helper function to clean error messages by removing duplicate error codes
String _cleanErrorMessage(String message) {
  // Remove "Error Code: XXXX-XXXX" patterns and extra whitespace
  return message
      .replaceAll(RegExp(r'\n\n?Error Code: [A-Z]+-[A-Z]+'), '')
      .replaceAll(RegExp(r'Error Code: [A-Z]+-[A-Z]+\n?'), '')
      .trim();
}
