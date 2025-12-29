/*
* Orion - Error Details
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

class ErrorDetails {
  final String title;
  final String message;

  ErrorDetails(this.title, this.message);
}

final Map<String, ErrorDetails> errorLookupTable = {
  'default': ErrorDetails(
    'Unknown Error',
    'An unknown error has occurred.\n'
        'Please contact support.\n\n'
        'Error Code: UNKNOWN',
  ),
  'PINK-CARROT': ErrorDetails(
    'Odyssey API Error',
    'An Error has occurred while fetching files!\n'
        'Please ensure that Odyssey is running and accessible.\n\n'
        'If the issue persists, please contact support.\n'
        'Error Code: PINK-CARROT',
  ),
  'BLUE-BANANA': ErrorDetails(
    'Network Error',
    'A network error has occurred.\n'
        'Please check your internet connection and try again.\n\n'
        'Error Code: BLUE-BANANA',
  ),
  'RED-APPLE': ErrorDetails(
    'Resin Level Low',
    'The resin level is too low.\n'
        'Please refill the resin tank.\n\n'
        'Error Code: RED-APPLE',
  ),
  'GREEN-GRAPE': ErrorDetails(
    'Print Failure',
    'The print has failed.\n'
        'Please check the model and try again.\n\n'
        'Error Code: GREEN-GRAPE',
  ),
  'YELLOW-LEMON': ErrorDetails(
    'Temperature Error',
    'The temperature is outside the acceptable range.\n'
        'Please check the printer environment.\n\n'
        'Error Code: YELLOW-LEMON',
  ),
  'ORANGE-ORANGE': ErrorDetails(
    'UV Light Error',
    'The UV light is not functioning correctly.\n'
        'Please check the light source.\n\n'
        'Error Code: ORANGE-ORANGE',
  ),
  'PURPLE-PLUM': ErrorDetails(
    'Build Plate Error',
    'The build plate is not correctly calibrated.\n'
        'Please recalibrate the build plate.\n\n'
        'Error Code: PURPLE-PLUM',
  ),
  'BROWN-BEAR': ErrorDetails(
    'Firmware Update Error',
    'There was an error during the firmware update.\n'
        'Please try again.\n\n'
        'Error Code: BROWN-BEAR',
  ),
  'BLACK-BERRY': ErrorDetails(
    'File Error',
    'The selected file cannot be read.\n'
        'Please check the file and try again.\n\n'
        'Error Code: BLACK-BERRY',
  ),
  'WHITE-WOLF': ErrorDetails(
    'Sensor Error',
    'A sensor is not working correctly.\n'
        'Please check the printer sensors.\n\n'
        'Error Code: WHITE-WOLF',
  ),
  'GRAY-GOOSE': ErrorDetails(
    'Power Error',
    'There was a power issue with the printer.\n'
        'Please ensure the printer is properly connected.\n\n'
        'Error Code: GRAY-GOOSE',
  ),
  'GOLDEN-APE': ErrorDetails(
    'Movement Error',
    'The movement command has failed.\n'
        'Please check the Z-axis and try again.\n\n'
        'Error Code: GOLDEN-APE',
  ),
  'CRITICAL': ErrorDetails(
    'CRITICAL ERROR',
    'A critical error has occured!\n'
        'Please contact support immediately.\n\n'
        'Error Code: CRITICAL',
  )
};
