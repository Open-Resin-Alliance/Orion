/*
* Orion - Country Data with Timezones based on ISO 3166-1 (2024) 
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

//  ╔═════════════════════════════════════════════════════════════════════╗
//  ║                          IMPORTANT NOTICE                           ║
//  ║                                                                     ║
//  ║    This list is not officially licensed or endorsed by ISO.         ║
//  ║    We are orienting ourselves on publicly available ISO data.       ║
//  ║                                                                     ║
//  ╚═════════════════════════════════════════════════════════════════════╝

const Map<String, Map<String, dynamic>> countryData = {
  'Afghanistan': {
    'code': 'AF',
    'timezones': {
      'suggested': ['UTC+4:30 - Afghanistan Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Albania': {
    'code': 'AL',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Algeria': {
    'code': 'DZ',
    'timezones': {
      'suggested': ['UTC+1 - Central European Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Andorra': {
    'code': 'AD',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Angola': {
    'code': 'AO',
    'timezones': {
      'suggested': ['UTC+1 - West Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Antigua and Barbuda': {
    'code': 'AG',
    'timezones': {
      'suggested': ['UTC-4 - Atlantic Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Argentina': {
    'code': 'AR',
    'timezones': {
      'suggested': ['UTC-3 - Argentina Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Armenia': {
    'code': 'AM',
    'timezones': {
      'suggested': ['UTC+4 - Armenia Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Australia': {
    'code': 'AU',
    'timezones': {
      'suggested': [
        'UTC+10 - Australian Eastern Standard Time',
        'UTC+9:30 - Australian Central Standard Time',
        'UTC+8 - Australian Western Standard Time',
      ],
      'other': [
        'UTC+11 - Australian Eastern Summer Time',
        'UTC+10:30 - Australian Central Summer Time',
        'UTC+0 - Coordinated Universal Time'
      ]
    }
  },
  'Austria': {
    'code': 'AT',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Azerbaijan': {
    'code': 'AZ',
    'timezones': {
      'suggested': ['UTC+4 - Azerbaijan Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Bahamas': {
    'code': 'BS',
    'timezones': {
      'suggested': ['UTC-5 - Eastern Time', 'UTC-4 - Eastern Daylight Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Bahrain': {
    'code': 'BH',
    'timezones': {
      'suggested': ['UTC+3 - Arabia Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Bangladesh': {
    'code': 'BD',
    'timezones': {
      'suggested': ['UTC+6 - Bangladesh Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Barbados': {
    'code': 'BB',
    'timezones': {
      'suggested': ['UTC-4 - Atlantic Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Belarus': {
    'code': 'BY',
    'timezones': {
      'suggested': ['UTC+3 - Moscow Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Belgium': {
    'code': 'BE',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Belize': {
    'code': 'BZ',
    'timezones': {
      'suggested': ['UTC-6 - Central Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Benin': {
    'code': 'BJ',
    'timezones': {
      'suggested': ['UTC+1 - West Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Bhutan': {
    'code': 'BT',
    'timezones': {
      'suggested': ['UTC+6 - Bhutan Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Bolivia': {
    'code': 'BO',
    'timezones': {
      'suggested': ['UTC-4 - Bolivia Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Bosnia and Herzegovina': {
    'code': 'BA',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Botswana': {
    'code': 'BW',
    'timezones': {
      'suggested': ['UTC+2 - Central Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Brazil': {
    'code': 'BR',
    'timezones': {
      'suggested': [
        'UTC-3 - Brasilia Time',
        'UTC-4 - Amazon Time',
        'UTC-5 - Acre Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Brunei': {
    'code': 'BN',
    'timezones': {
      'suggested': ['UTC+8 - Brunei Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Bulgaria': {
    'code': 'BG',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Burkina Faso': {
    'code': 'BF',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Burundi': {
    'code': 'BI',
    'timezones': {
      'suggested': ['UTC+2 - Central Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Cambodia': {
    'code': 'KH',
    'timezones': {
      'suggested': ['UTC+7 - Indochina Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Cameroon': {
    'code': 'CM',
    'timezones': {
      'suggested': ['UTC+1 - West Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Canada': {
    'code': 'CA',
    'timezones': {
      'suggested': [
        'UTC-3:30 - Newfoundland Time',
        'UTC-4 - Atlantic Time',
        'UTC-5 - Eastern Time',
        'UTC-6 - Central Time',
        'UTC-7 - Mountain Time',
        'UTC-8 - Pacific Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Cape Verde': {
    'code': 'CV',
    'timezones': {
      'suggested': ['UTC-1 - Cape Verde Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Central African Republic': {
    'code': 'CF',
    'timezones': {
      'suggested': ['UTC+1 - West Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Chad': {
    'code': 'TD',
    'timezones': {
      'suggested': ['UTC+1 - West Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Chile': {
    'code': 'CL',
    'timezones': {
      'suggested': [
        'UTC-4 - Chile Standard Time',
        'UTC-3 - Chile Summer Time',
        'UTC-6 - Easter Island Standard Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'China': {
    'code': 'CN',
    'timezones': {
      'suggested': ['UTC+8 - China Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Colombia': {
    'code': 'CO',
    'timezones': {
      'suggested': ['UTC-5 - Colombia Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Comoros': {
    'code': 'KM',
    'timezones': {
      'suggested': ['UTC+3 - East Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Congo': {
    'code': 'CG',
    'timezones': {
      'suggested': ['UTC+1 - West Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Costa Rica': {
    'code': 'CR',
    'timezones': {
      'suggested': ['UTC-6 - Central Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Croatia': {
    'code': 'HR',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Cuba': {
    'code': 'CU',
    'timezones': {
      'suggested': ['UTC-5 - Cuba Standard Time', 'UTC-4 - Cuba Daylight Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Cyprus': {
    'code': 'CY',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Czech Republic': {
    'code': 'CZ',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Democratic Republic of the Congo': {
    'code': 'CD',
    'timezones': {
      'suggested': ['UTC+1 - West Africa Time', 'UTC+2 - Central Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Denmark': {
    'code': 'DK',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Djibouti': {
    'code': 'DJ',
    'timezones': {
      'suggested': ['UTC+3 - East Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Dominica': {
    'code': 'DM',
    'timezones': {
      'suggested': ['UTC-4 - Atlantic Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Dominican Republic': {
    'code': 'DO',
    'timezones': {
      'suggested': ['UTC-4 - Atlantic Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Ecuador': {
    'code': 'EC',
    'timezones': {
      'suggested': ['UTC-5 - Ecuador Time', 'UTC-6 - Galapagos Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Egypt': {
    'code': 'EG',
    'timezones': {
      'suggested': ['UTC+2 - Eastern European Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'El Salvador': {
    'code': 'SV',
    'timezones': {
      'suggested': ['UTC-6 - Central Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Equatorial Guinea': {
    'code': 'GQ',
    'timezones': {
      'suggested': ['UTC+1 - West Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Eritrea': {
    'code': 'ER',
    'timezones': {
      'suggested': ['UTC+3 - East Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Estonia': {
    'code': 'EE',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Eswatini': {
    'code': 'SZ',
    'timezones': {
      'suggested': ['UTC+2 - South African Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Ethiopia': {
    'code': 'ET',
    'timezones': {
      'suggested': ['UTC+3 - East Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Fiji': {
    'code': 'FJ',
    'timezones': {
      'suggested': ['UTC+12 - Fiji Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Finland': {
    'code': 'FI',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'France': {
    'code': 'FR',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Gabon': {
    'code': 'GA',
    'timezones': {
      'suggested': ['UTC+1 - West Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Gambia': {
    'code': 'GM',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Georgia': {
    'code': 'GE',
    'timezones': {
      'suggested': ['UTC+4 - Georgia Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Germany': {
    'code': 'DE',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Ghana': {
    'code': 'GH',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Greece': {
    'code': 'GR',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Grenada': {
    'code': 'GD',
    'timezones': {
      'suggested': ['UTC-4 - Atlantic Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Guatemala': {
    'code': 'GT',
    'timezones': {
      'suggested': ['UTC-6 - Central Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Guinea': {
    'code': 'GN',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Guinea-Bissau': {
    'code': 'GW',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Guyana': {
    'code': 'GY',
    'timezones': {
      'suggested': ['UTC-4 - Guyana Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Haiti': {
    'code': 'HT',
    'timezones': {
      'suggested': ['UTC-5 - Eastern Time', 'UTC-4 - Eastern Daylight Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Honduras': {
    'code': 'HN',
    'timezones': {
      'suggested': ['UTC-6 - Central Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Hungary': {
    'code': 'HU',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Iceland': {
    'code': 'IS',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'India': {
    'code': 'IN',
    'timezones': {
      'suggested': ['UTC+5:30 - India Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Indonesia': {
    'code': 'ID',
    'timezones': {
      'suggested': [
        'UTC+7 - Western Indonesia Time',
        'UTC+8 - Central Indonesia Time',
        'UTC+9 - Eastern Indonesia Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Iran': {
    'code': 'IR',
    'timezones': {
      'suggested': [
        'UTC+3:30 - Iran Standard Time',
        'UTC+4:30 - Iran Daylight Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Iraq': {
    'code': 'IQ',
    'timezones': {
      'suggested': ['UTC+3 - Arabia Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Ireland': {
    'code': 'IE',
    'timezones': {
      'suggested': [
        'UTC+0 - Greenwich Mean Time',
        'UTC+1 - Irish Standard Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Israel': {
    'code': 'IL',
    'timezones': {
      'suggested': [
        'UTC+2 - Israel Standard Time',
        'UTC+3 - Israel Daylight Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Italy': {
    'code': 'IT',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Jamaica': {
    'code': 'JM',
    'timezones': {
      'suggested': ['UTC-5 - Eastern Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Japan': {
    'code': 'JP',
    'timezones': {
      'suggested': ['UTC+9 - Japan Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Jordan': {
    'code': 'JO',
    'timezones': {
      'suggested': ['UTC+3 - Arabia Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Kazakhstan': {
    'code': 'KZ',
    'timezones': {
      'suggested': [
        'UTC+5 - West Kazakhstan Time',
        'UTC+6 - East Kazakhstan Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Kenya': {
    'code': 'KE',
    'timezones': {
      'suggested': ['UTC+3 - East Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Kiribati': {
    'code': 'KI',
    'timezones': {
      'suggested': [
        'UTC+12 - Gilbert Islands Time',
        'UTC+13 - Phoenix Islands Time',
        'UTC+14 - Line Islands Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Kuwait': {
    'code': 'KW',
    'timezones': {
      'suggested': ['UTC+3 - Arabia Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Kyrgyzstan': {
    'code': 'KG',
    'timezones': {
      'suggested': ['UTC+6 - Kyrgyzstan Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Laos': {
    'code': 'LA',
    'timezones': {
      'suggested': ['UTC+7 - Indochina Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Latvia': {
    'code': 'LV',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Lebanon': {
    'code': 'LB',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Lesotho': {
    'code': 'LS',
    'timezones': {
      'suggested': ['UTC+2 - South African Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Liberia': {
    'code': 'LR',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Libya': {
    'code': 'LY',
    'timezones': {
      'suggested': ['UTC+2 - Eastern European Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Liechtenstein': {
    'code': 'LI',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Lithuania': {
    'code': 'LT',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Luxembourg': {
    'code': 'LU',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Madagascar': {
    'code': 'MG',
    'timezones': {
      'suggested': ['UTC+3 - East Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Malawi': {
    'code': 'MW',
    'timezones': {
      'suggested': ['UTC+2 - Central Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Malaysia': {
    'code': 'MY',
    'timezones': {
      'suggested': ['UTC+8 - Malaysia Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Maldives': {
    'code': 'MV',
    'timezones': {
      'suggested': ['UTC+5 - Maldives Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Mali': {
    'code': 'ML',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Malta': {
    'code': 'MT',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Marshall Islands': {
    'code': 'MH',
    'timezones': {
      'suggested': ['UTC+12 - Marshall Islands Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Mauritania': {
    'code': 'MR',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Mauritius': {
    'code': 'MU',
    'timezones': {
      'suggested': ['UTC+4 - Mauritius Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Mexico': {
    'code': 'MX',
    'timezones': {
      'suggested': [
        'UTC-6 - Central Standard Time',
        'UTC-7 - Mountain Standard Time',
        'UTC-8 - Pacific Standard Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Micronesia': {
    'code': 'FM',
    'timezones': {
      'suggested': ['UTC+10 - Chuuk Time', 'UTC+11 - Pohnpei Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Moldova': {
    'code': 'MD',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Monaco': {
    'code': 'MC',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Mongolia': {
    'code': 'MN',
    'timezones': {
      'suggested': ['UTC+8 - Ulaanbaatar Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Montenegro': {
    'code': 'ME',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Morocco': {
    'code': 'MA',
    'timezones': {
      'suggested': ['UTC+1 - Western European Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Mozambique': {
    'code': 'MZ',
    'timezones': {
      'suggested': ['UTC+2 - Central Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Myanmar': {
    'code': 'MM',
    'timezones': {
      'suggested': ['UTC+6:30 - Myanmar Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Namibia': {
    'code': 'NA',
    'timezones': {
      'suggested': ['UTC+2 - Central Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Nauru': {
    'code': 'NR',
    'timezones': {
      'suggested': ['UTC+12 - Nauru Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Nepal': {
    'code': 'NP',
    'timezones': {
      'suggested': ['UTC+5:45 - Nepal Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Netherlands': {
    'code': 'NL',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'New Zealand': {
    'code': 'NZ',
    'timezones': {
      'suggested': [
        'UTC+12 - New Zealand Standard Time',
        'UTC+13 - New Zealand Daylight Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Nicaragua': {
    'code': 'NI',
    'timezones': {
      'suggested': ['UTC-6 - Central Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Niger': {
    'code': 'NE',
    'timezones': {
      'suggested': ['UTC+1 - West Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Nigeria': {
    'code': 'NG',
    'timezones': {
      'suggested': ['UTC+1 - West Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'North Korea': {
    'code': 'KP',
    'timezones': {
      'suggested': ['UTC+9 - Korea Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'North Macedonia': {
    'code': 'MK',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Norway': {
    'code': 'NO',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Oman': {
    'code': 'OM',
    'timezones': {
      'suggested': ['UTC+4 - Gulf Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Pakistan': {
    'code': 'PK',
    'timezones': {
      'suggested': ['UTC+5 - Pakistan Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Palau': {
    'code': 'PW',
    'timezones': {
      'suggested': ['UTC+9 - Palau Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Palestine': {
    'code': 'PS',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Panama': {
    'code': 'PA',
    'timezones': {
      'suggested': ['UTC-5 - Eastern Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Papua New Guinea': {
    'code': 'PG',
    'timezones': {
      'suggested': ['UTC+10 - Papua New Guinea Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Paraguay': {
    'code': 'PY',
    'timezones': {
      'suggested': ['UTC-4 - Paraguay Time', 'UTC-3 - Paraguay Summer Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Peru': {
    'code': 'PE',
    'timezones': {
      'suggested': ['UTC-5 - Peru Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Philippines': {
    'code': 'PH',
    'timezones': {
      'suggested': ['UTC+8 - Philippine Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Poland': {
    'code': 'PL',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Portugal': {
    'code': 'PT',
    'timezones': {
      'suggested': [
        'UTC+0 - Western European Time',
        'UTC+1 - Western European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Qatar': {
    'code': 'QA',
    'timezones': {
      'suggested': ['UTC+3 - Arabia Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Romania': {
    'code': 'RO',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Russia': {
    'code': 'RU',
    'timezones': {
      'suggested': [
        'UTC+2 - Kaliningrad Time',
        'UTC+3 - Moscow Time',
        'UTC+4 - Samara Time',
        'UTC+5 - Yekaterinburg Time',
        'UTC+6 - Omsk Time',
        'UTC+7 - Krasnoyarsk Time',
        'UTC+8 - Irkutsk Time',
        'UTC+9 - Yakutsk Time',
        'UTC+10 - Vladivostok Time',
        'UTC+11 - Magadan Time',
        'UTC+12 - Kamchatka Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Rwanda': {
    'code': 'RW',
    'timezones': {
      'suggested': ['UTC+2 - Central Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Saint Kitts and Nevis': {
    'code': 'KN',
    'timezones': {
      'suggested': ['UTC-4 - Atlantic Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Saint Lucia': {
    'code': 'LC',
    'timezones': {
      'suggested': ['UTC-4 - Atlantic Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Saint Vincent and the Grenadines': {
    'code': 'VC',
    'timezones': {
      'suggested': ['UTC-4 - Atlantic Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Samoa': {
    'code': 'WS',
    'timezones': {
      'suggested': ['UTC+13 - Samoa Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'San Marino': {
    'code': 'SM',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Sao Tome and Principe': {
    'code': 'ST',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Saudi Arabia': {
    'code': 'SA',
    'timezones': {
      'suggested': ['UTC+3 - Arabia Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Senegal': {
    'code': 'SN',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Serbia': {
    'code': 'RS',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Seychelles': {
    'code': 'SC',
    'timezones': {
      'suggested': ['UTC+4 - Seychelles Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Sierra Leone': {
    'code': 'SL',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Singapore': {
    'code': 'SG',
    'timezones': {
      'suggested': ['UTC+8 - Singapore Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Slovakia': {
    'code': 'SK',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Slovenia': {
    'code': 'SI',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Solomon Islands': {
    'code': 'SB',
    'timezones': {
      'suggested': ['UTC+11 - Solomon Islands Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Somalia': {
    'code': 'SO',
    'timezones': {
      'suggested': ['UTC+3 - East Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'South Africa': {
    'code': 'ZA',
    'timezones': {
      'suggested': ['UTC+2 - South African Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'South Korea': {
    'code': 'KR',
    'timezones': {
      'suggested': ['UTC+9 - Korea Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'South Sudan': {
    'code': 'SS',
    'timezones': {
      'suggested': ['UTC+3 - East Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Spain': {
    'code': 'ES',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Sri Lanka': {
    'code': 'LK',
    'timezones': {
      'suggested': ['UTC+5:30 - Sri Lanka Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Sudan': {
    'code': 'SD',
    'timezones': {
      'suggested': ['UTC+2 - Central Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Suriname': {
    'code': 'SR',
    'timezones': {
      'suggested': ['UTC-3 - Suriname Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Sweden': {
    'code': 'SE',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Switzerland': {
    'code': 'CH',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Syria': {
    'code': 'SY',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Taiwan': {
    'code': 'TW',
    'timezones': {
      'suggested': ['UTC+8 - Taipei Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Tajikistan': {
    'code': 'TJ',
    'timezones': {
      'suggested': ['UTC+5 - Tajikistan Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Tanzania': {
    'code': 'TZ',
    'timezones': {
      'suggested': ['UTC+3 - East Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Thailand': {
    'code': 'TH',
    'timezones': {
      'suggested': ['UTC+7 - Indochina Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Timor-Leste': {
    'code': 'TL',
    'timezones': {
      'suggested': ['UTC+9 - Timor-Leste Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Togo': {
    'code': 'TG',
    'timezones': {
      'suggested': ['UTC+0 - Greenwich Mean Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Tonga': {
    'code': 'TO',
    'timezones': {
      'suggested': ['UTC+13 - Tonga Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Trinidad and Tobago': {
    'code': 'TT',
    'timezones': {
      'suggested': ['UTC-4 - Atlantic Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Tunisia': {
    'code': 'TN',
    'timezones': {
      'suggested': ['UTC+1 - Central European Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Turkey': {
    'code': 'TR',
    'timezones': {
      'suggested': ['UTC+3 - Turkey Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Turkmenistan': {
    'code': 'TM',
    'timezones': {
      'suggested': ['UTC+5 - Turkmenistan Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Tuvalu': {
    'code': 'TV',
    'timezones': {
      'suggested': ['UTC+12 - Tuvalu Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Uganda': {
    'code': 'UG',
    'timezones': {
      'suggested': ['UTC+3 - East Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Ukraine': {
    'code': 'UA',
    'timezones': {
      'suggested': [
        'UTC+2 - Eastern European Time',
        'UTC+3 - Eastern European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'United Arab Emirates': {
    'code': 'AE',
    'timezones': {
      'suggested': ['UTC+4 - Gulf Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'United Kingdom': {
    'code': 'GB',
    'timezones': {
      'suggested': [
        'UTC+0 - British Standard Time',
        'UTC+1 - British Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'United States': {
    'code': 'US',
    'timezones': {
      'suggested': [
        'UTC-5 - Eastern Time',
        'UTC-6 - Central Time',
        'UTC-7 - Mountain Time',
        'UTC-8 - Pacific Time',
        'UTC-9 - Alaska Time',
        'UTC-10 - Hawaii Time'
      ],
      'other': [
        'UTC-4 - Atlantic Time',
        'UTC+10 - Chamorro Time (Guam)',
        'UTC+0 - Coordinated Universal Time'
      ]
    }
  },
  'Uruguay': {
    'code': 'UY',
    'timezones': {
      'suggested': ['UTC-3 - Uruguay Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Uzbekistan': {
    'code': 'UZ',
    'timezones': {
      'suggested': ['UTC+5 - Uzbekistan Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Vanuatu': {
    'code': 'VU',
    'timezones': {
      'suggested': ['UTC+11 - Vanuatu Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Vatican City': {
    'code': 'VA',
    'timezones': {
      'suggested': [
        'UTC+1 - Central European Time',
        'UTC+2 - Central European Summer Time'
      ],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Venezuela': {
    'code': 'VE',
    'timezones': {
      'suggested': ['UTC-4 - Venezuelan Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Vietnam': {
    'code': 'VN',
    'timezones': {
      'suggested': ['UTC+7 - Indochina Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Yemen': {
    'code': 'YE',
    'timezones': {
      'suggested': ['UTC+3 - Arabia Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Zambia': {
    'code': 'ZM',
    'timezones': {
      'suggested': ['UTC+2 - Central Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Zimbabwe': {
    'code': 'ZW',
    'timezones': {
      'suggested': ['UTC+2 - Central Africa Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Guam': {
    'code': 'GU',
    'timezones': {
      'suggested': ['UTC+10 - Chamorro Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'Puerto Rico': {
    'code': 'PR',
    'timezones': {
      'suggested': ['UTC-4 - Atlantic Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
  'U.S. Virgin Islands': {
    'code': 'VI',
    'timezones': {
      'suggested': ['UTC-4 - Atlantic Standard Time'],
      'other': ['UTC+0 - Coordinated Universal Time']
    }
  },
};

String getCountryCode(String countryName) =>
    countryData[countryName]?['code'] ?? '';

List<String> getCountryTimezones(String countryName) {
  final timezones = countryData[countryName]?['timezones'];
  if (timezones == null) return [];

  return [
    ...(timezones['suggested'] as List<String>? ?? []),
    ...(timezones['other'] as List<String>? ?? [])
  ];
}

bool isValidCountry(String countryName) => countryData.containsKey(countryName);
