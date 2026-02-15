/*
* Orion - Fancy License Screen
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

/// Code derived from Flutter code library.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntry, LicenseRegistry, LicenseParagraph;

import 'package:orion/glasser/src/widgets/glass_app.dart';
import 'package:orion/glasser/src/widgets/glass_card.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:orion/widgets/orion_app_bar.dart';

// Data structure for license information
class _LicenseData {
  final List<LicenseEntry> licenses;
  final Map<String, List<int>> packageLicenseBindings;
  final List<String> packages;

  _LicenseData(this.licenses, this.packageLicenseBindings, this.packages);
}

// Header widget for the about section
class _AboutHeader extends StatelessWidget {
  final String? name;
  final String? version;
  final Widget? icon;
  final String? legalese;

  const _AboutHeader({this.name, this.version, this.icon, this.legalese});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: icon != null
                      ? IconTheme(
                          data: Theme.of(context).iconTheme, child: icon!)
                      : Image.asset(
                          'assets/images/ora/open_resin_alliance_logo_darkmode.png',
                          width: 65,
                          height: 65,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              const SizedBox(width: 20),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (version != null && version!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Text(
                            version!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'built with the help of these amazing packages',
                        style: Theme.of(context).textTheme.bodyMedium,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (legalese != null && legalese!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'built with the help of these amazing packages',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

// Glassmorphic page for a single package's licenses
class _PackageLicenseScreen extends StatelessWidget {
  final String packageName;
  final List<LicenseEntry> licenseEntries;

  const _PackageLicenseScreen({
    required this.packageName,
    required this.licenseEntries,
  });

  @override
  Widget build(BuildContext context) {
    return GlassApp(
      child: Scaffold(
        appBar: OrionAppBar(
            title: Text(packageName),
            toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
            actions: <Widget>[
              SystemStatusWidget(),
            ],
          ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final entry in licenseEntries)
              for (final p in entry.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    p.text,
                    textAlign: p.indent == LicenseParagraph.centeredIndent
                        ? TextAlign.center
                        : TextAlign.start,
                    style: p.indent == LicenseParagraph.centeredIndent
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// A glassmorphic, modern replacement for Flutter's LicensePage.
class FancyLicensePage extends StatefulWidget {
  final String? applicationName;
  final String? applicationVersion;
  final Widget? applicationIcon;
  final String? applicationLegalese;

  const FancyLicensePage({
    super.key,
    this.applicationName,
    this.applicationVersion,
    this.applicationIcon,
    this.applicationLegalese,
  });

  @override
  State<FancyLicensePage> createState() => _FancyLicensePageState();
}

class _FancyLicensePageState extends State<FancyLicensePage> {
  late Future<_LicenseData> _licensesFuture;

  @override
  void initState() {
    super.initState();
    _licensesFuture = _loadLicenses();
  }

  Future<_LicenseData> _loadLicenses() async {
    final licenses = <LicenseEntry>[];
    final packageLicenseBindings = <String, List<int>>{};
    final packages = <String>[];
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        packageLicenseBindings
            .putIfAbsent(package, () => <int>[])
            .add(licenses.length);
        if (!packages.contains(package)) packages.add(package);
      }
      licenses.add(entry);
    }
    return _LicenseData(licenses, packageLicenseBindings, packages);
  }

  @override
  Widget build(BuildContext context) {
    return GlassApp(
      child: FutureBuilder<_LicenseData>(
        future: _licensesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(
              appBar: OrionAppBar(
            title: const Text('Loading Licenses...'),
            toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
            actions: <Widget>[
              SystemStatusWidget(),
            ],
          ),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final data = snapshot.data!;
          return Scaffold(
            appBar: OrionAppBar(
            title: const Text('Open-Source Licenses'),
            toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
            actions: <Widget>[
              SystemStatusWidget(),
            ],
          ),
            body: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: data.packages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _AboutHeader(
                    name: widget.applicationName,
                    version: widget.applicationVersion,
                    icon: widget.applicationIcon,
                    legalese: widget.applicationLegalese,
                  );
                }
                final package = data.packages[index - 1];
                final licenseIndexes = data.packageLicenseBindings[package]!;
                return GlassCard(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      title: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Text(
                          package,
                          style: TextStyle(fontSize: 22),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => _PackageLicenseScreen(
                              packageName: package,
                              licenseEntries: licenseIndexes
                                  .map((i) => data.licenses[i])
                                  .toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// Optionally: helper to show the license page
void showFancyLicensePage({
  required BuildContext context,
  String? applicationName,
  String? applicationVersion,
  Widget? applicationIcon,
  String? applicationLegalese,
  bool useRootNavigator = false,
}) {
  final CapturedThemes themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: useRootNavigator).context,
  );
  Navigator.of(context, rootNavigator: useRootNavigator).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => themes.wrap(
        FancyLicensePage(
          applicationName: applicationName,
          applicationVersion: applicationVersion,
          applicationIcon: applicationIcon,
          applicationLegalese: applicationLegalese,
        ),
      ),
    ),
  );
}
