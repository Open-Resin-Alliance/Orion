/*
* Orion - Country Regional Groupings
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

/// Maps country names to their geographical regions for easier organization
/// in the country selector UI.
const Map<String, String> countryToRegion = {
  // Europe
  'Albania': 'Europe',
  'Andorra': 'Europe',
  'Austria': 'Europe',
  'Belarus': 'Europe',
  'Belgium': 'Europe',
  'Bosnia and Herzegovina': 'Europe',
  'Bulgaria': 'Europe',
  'Croatia': 'Europe',
  'Cyprus': 'Europe',
  'Czech Republic': 'Europe',
  'Czechia': 'Europe',
  'Denmark': 'Europe',
  'Estonia': 'Europe',
  'Finland': 'Europe',
  'France': 'Europe',
  'Germany': 'Europe',
  'Greece': 'Europe',
  'Hungary': 'Europe',
  'Iceland': 'Europe',
  'Ireland': 'Europe',
  'Italy': 'Europe',
  'Kosovo': 'Europe',
  'Latvia': 'Europe',
  'Liechtenstein': 'Europe',
  'Lithuania': 'Europe',
  'Luxembourg': 'Europe',
  'Malta': 'Europe',
  'Moldova': 'Europe',
  'Monaco': 'Europe',
  'Montenegro': 'Europe',
  'Netherlands': 'Europe',
  'North Macedonia': 'Europe',
  'Norway': 'Europe',
  'Poland': 'Europe',
  'Portugal': 'Europe',
  'Romania': 'Europe',
  'Russia': 'Europe',
  'San Marino': 'Europe',
  'Serbia': 'Europe',
  'Slovakia': 'Europe',
  'Slovenia': 'Europe',
  'Spain': 'Europe',
  'Sweden': 'Europe',
  'Switzerland': 'Europe',
  'Ukraine': 'Europe',
  'United Kingdom': 'Europe',

  // Asia
  'Afghanistan': 'Asia',
  'Armenia': 'Asia',
  'Azerbaijan': 'Asia',
  'Bahrain': 'Asia',
  'Bangladesh': 'Asia',
  'Bhutan': 'Asia',
  'Brunei': 'Asia',
  'Cambodia': 'Asia',
  'China': 'Asia',
  'Georgia': 'Asia',
  'Hong Kong': 'Asia',
  'India': 'Asia',
  'Indonesia': 'Asia',
  'Iran': 'Asia',
  'Iraq': 'Asia',
  'Israel': 'Asia',
  'Japan': 'Asia',
  'Jordan': 'Asia',
  'Kazakhstan': 'Asia',
  'Kuwait': 'Asia',
  'Kyrgyzstan': 'Asia',
  'Laos': 'Asia',
  'Lebanon': 'Asia',
  'Macao': 'Asia',
  'Malaysia': 'Asia',
  'Maldives': 'Asia',
  'Mongolia': 'Asia',
  'Myanmar': 'Asia',
  'Nepal': 'Asia',
  'North Korea': 'Asia',
  'Oman': 'Asia',
  'Pakistan': 'Asia',
  'Palestine': 'Asia',
  'Philippines': 'Asia',
  'Qatar': 'Asia',
  'Saudi Arabia': 'Asia',
  'Singapore': 'Asia',
  'South Korea': 'Asia',
  'Sri Lanka': 'Asia',
  'Syria': 'Asia',
  'Taiwan': 'Asia',
  'Tajikistan': 'Asia',
  'Thailand': 'Asia',
  'Timor-Leste': 'Asia',
  'Turkey': 'Asia',
  'Turkmenistan': 'Asia',
  'United Arab Emirates': 'Asia',
  'Uzbekistan': 'Asia',
  'Vietnam': 'Asia',
  'West Bank': 'Asia',
  'Yemen': 'Asia',

  // Africa
  'Algeria': 'Africa',
  'Angola': 'Africa',
  'Benin': 'Africa',
  'Botswana': 'Africa',
  'Burkina Faso': 'Africa',
  'Burundi': 'Africa',
  'Cameroon': 'Africa',
  'Cape Verde': 'Africa',
  'Central African Republic': 'Africa',
  'Chad': 'Africa',
  'Comoros': 'Africa',
  'Congo': 'Africa',
  'Democratic Republic of the Congo': 'Africa',
  'Djibouti': 'Africa',
  'Egypt': 'Africa',
  'Equatorial Guinea': 'Africa',
  'Eritrea': 'Africa',
  'Eswatini': 'Africa',
  'Ethiopia': 'Africa',
  'Gabon': 'Africa',
  'Gambia': 'Africa',
  'Ghana': 'Africa',
  'Guinea': 'Africa',
  'Guinea-Bissau': 'Africa',
  'Ivory Coast': 'Africa',
  'Kenya': 'Africa',
  'Lesotho': 'Africa',
  'Liberia': 'Africa',
  'Libya': 'Africa',
  'Madagascar': 'Africa',
  'Malawi': 'Africa',
  'Mali': 'Africa',
  'Mauritania': 'Africa',
  'Mauritius': 'Africa',
  'Morocco': 'Africa',
  'Mozambique': 'Africa',
  'Namibia': 'Africa',
  'Niger': 'Africa',
  'Nigeria': 'Africa',
  'Rwanda': 'Africa',
  'Saint Helena': 'Africa',
  'Sao Tome and Principe': 'Africa',
  'Senegal': 'Africa',
  'Seychelles': 'Africa',
  'Sierra Leone': 'Africa',
  'Somalia': 'Africa',
  'South Africa': 'Africa',
  'South Sudan': 'Africa',
  'Sudan': 'Africa',
  'Tanzania': 'Africa',
  'Togo': 'Africa',
  'Tunisia': 'Africa',
  'Uganda': 'Africa',
  'Western Sahara': 'Africa',
  'Zambia': 'Africa',
  'Zimbabwe': 'Africa',

  // Americas
  'Antigua and Barbuda': 'Americas',
  'Argentina': 'Americas',
  'Bahamas': 'Americas',
  'Barbados': 'Americas',
  'Belize': 'Americas',
  'Bolivia': 'Americas',
  'Brazil': 'Americas',
  'Canada': 'Americas',
  'Chile': 'Americas',
  'Colombia': 'Americas',
  'Costa Rica': 'Americas',
  'Cuba': 'Americas',
  'Dominica': 'Americas',
  'Dominican Republic': 'Americas',
  'Ecuador': 'Americas',
  'El Salvador': 'Americas',
  'Grenada': 'Americas',
  'Guatemala': 'Americas',
  'Guyana': 'Americas',
  'Haiti': 'Americas',
  'Honduras': 'Americas',
  'Jamaica': 'Americas',
  'Mexico': 'Americas',
  'Nicaragua': 'Americas',
  'Panama': 'Americas',
  'Paraguay': 'Americas',
  'Peru': 'Americas',
  'Saint Kitts and Nevis': 'Americas',
  'Saint Lucia': 'Americas',
  'Saint Vincent and the Grenadines': 'Americas',
  'Suriname': 'Americas',
  'Trinidad and Tobago': 'Americas',
  'United States': 'Americas',
  'Uruguay': 'Americas',
  'Venezuela': 'Americas',

  // Oceania
  'Australia': 'Oceania',
  'Fiji': 'Oceania',
  'Kiribati': 'Oceania',
  'Marshall Islands': 'Oceania',
  'Micronesia': 'Oceania',
  'Nauru': 'Oceania',
  'New Zealand': 'Oceania',
  'Palau': 'Oceania',
  'Papua New Guinea': 'Oceania',
  'Samoa': 'Oceania',
  'Solomon Islands': 'Oceania',
  'Tonga': 'Oceania',
  'Tuvalu': 'Oceania',
  'Vanuatu': 'Oceania',
};

/// Ordered list of regions for consistent UI display
const List<String> regionOrder = [
  'Europe',
  'Asia',
  'Africa',
  'Americas',
  'Oceania',
];

/// Get the region for a country, or null if not found
String? getCountryRegion(String countryName) {
  return countryToRegion[countryName];
}

/// Group countries by region
Map<String, List<Map<String, String>>> groupCountriesByRegion(
    List<Map<String, String>> countries) {
  final grouped = <String, List<Map<String, String>>>{};

  for (final region in regionOrder) {
    grouped[region] = [];
  }

  for (final country in countries) {
    final region = countryToRegion[country['name']];
    if (region != null && grouped.containsKey(region)) {
      grouped[region]!.add(country);
    }
  }

  // Sort countries within each region alphabetically
  for (final region in grouped.keys) {
    grouped[region]!.sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  return grouped;
}
