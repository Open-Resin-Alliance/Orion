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
import 'package:orion/util/error_handling/error_details.dart';

void showErrorDialog(BuildContext context, String errorCode) {
  ErrorDetails? errorDetails =
      errorLookupTable[errorCode] ?? errorLookupTable['default'];

  WidgetsBinding.instance.addPostFrameCallback((_) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(errorDetails!.title),
            content: Text(
              errorDetails.message,
              style: const TextStyle(color: Colors.grey),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          );
        });
  });
}
