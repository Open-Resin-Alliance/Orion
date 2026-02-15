/*
 * Orion - Local Files Provider
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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'package:orion/util/orion_api_filesystem/orion_api_file.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_directory.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_item.dart';

/// Provides file listing from local filesystem for USB/Media directories
///
/// Used on NanoDLP machines when there is no backend override URL.
/// On Linux, scans /media/usb for .stl and .nanodlp files.
/// On macOS (development), scans ~/Documents for testing.
class LocalFilesProvider extends ChangeNotifier {
  final _log = Logger('LocalFilesProvider');

  // Base directory to scan for files
  late final String _baseDirectory;

  List<OrionApiItem> _items = [];
  List<OrionApiItem> get items => _items;

  bool _loading = false;
  bool get isLoading => _loading;

  Object? _error;
  Object? get error => _error;

  String _location = 'Local';
  String get location => _location;

  String _subdirectory = '';
  String get subdirectory => _subdirectory;

  // Expose base directory for testing and initialization
  String get baseDirectory => _baseDirectory;

  // Supported file extensions
  static const List<String> supportedExtensions = ['.stl', '.nanodlp'];
  static const Set<String> _ignoredDirectoryNames = {
    'system volume information',
    '_macosx',
    '.spotlight-v100',
    '.trashes',
    '.fseventsd',
    '.temporaryitems',
    '.vol',
    'lost+found',
  };

  LocalFilesProvider({String? baseDirectory}) {
    if (baseDirectory != null) {
      _baseDirectory = baseDirectory;
    } else {
      // Platform-specific defaults: macOS uses ~/Documents for development, Linux uses /media/usb
      if (Platform.isMacOS) {
        final username = Platform.environment['USER'];
        _baseDirectory =
            username != null ? '/Users/$username/Documents' : '~/Documents';
      } else {
        _baseDirectory = '/media/usb';
      }
    }
  }

  /// Load items from the filesystem
  Future<void> loadItems(String location, String subdirectory,
      {int pageSize = 100, int pageIndex = 0}) async {
    _log.info(
        'loadItems: location=$location subdirectory=$subdirectory pageSize=$pageSize pageIndex=$pageIndex');
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Build the full path to scan
      final fullPath = subdirectory.isEmpty
          ? _baseDirectory
          : path.join(_baseDirectory, subdirectory);

      // Resolve the path to prevent directory traversal attacks (../..)
      final resolvedPath = path.normalize(path.absolute(fullPath));
      final resolvedBase = path.normalize(path.absolute(_baseDirectory));

      // Validate that the resolved path is within the base directory
      if (!resolvedPath.startsWith(resolvedBase)) {
        _log.warning(
            'Attempted to navigate outside base directory. Base: $resolvedBase, Requested: $resolvedPath');
        // Cap at base directory if trying to escape
        _items = [];
        _location = location;
        _subdirectory = ''; // Reset to base
        _loading = false;
        _error = null;
        notifyListeners();
        return;
      }

      final dir = Directory(resolvedPath);

      // Check if directory exists
      if (!dir.existsSync()) {
        _log.warning('Directory does not exist: $resolvedPath');
        _items = [];
        _location = location;
        _subdirectory = '';
        _loading = false;
        _error = null;
        notifyListeners();
        return;
      }

      // List all items in the directory
      final List<OrionApiItem> items = [];

      // Add directories first
      final dirEntities = dir.listSync(recursive: false, followLinks: false);
      final directories = <OrionApiDirectory>[];
      final files = <OrionApiFile>[];

      for (final entity in dirEntities) {
        if (entity is Directory) {
          try {
            if (_isIgnoredDirectory(entity)) {
              continue;
            }
            directories.add(_createDirectoryItem(entity, resolvedPath));
          } catch (e) {
            _log.warning('Failed to create directory item: ${entity.path}', e);
          }
        } else if (entity is File) {
          if (_isSupportedFile(entity.path)) {
            try {
              files.add(_createFileItem(entity, resolvedPath));
            } catch (e) {
              _log.warning('Failed to create file item: ${entity.path}', e);
            }
          }
        }
      }

      // Sort items
      directories.sort((a, b) => a.name.compareTo(b.name));
      files.sort((a, b) => a.name.compareTo(b.name));

      items.addAll(directories);
      items.addAll(files);

      _items = items;
      _location = location;
      // Store relative path from base directory
      _subdirectory = resolvedPath == resolvedBase
          ? ''
          : path.relative(resolvedPath, from: resolvedBase);
      _loading = false;
      _error = null;
      _log.fine(
          'loadItems: loaded ${_items.length} items from $resolvedPath (${directories.length} dirs, ${files.length} files)');
    } catch (e, st) {
      _log.severe('Failed to load items from filesystem', e, st);
      _error = e;
      _loading = false;
      _items = [];
    } finally {
      notifyListeners();
    }
  }

  /// Check if a file is supported (has supported extension)
  bool _isSupportedFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return supportedExtensions.contains(ext);
  }

  bool _isIgnoredDirectory(Directory dir) {
    final name = path.basename(dir.path).toLowerCase();
    if (name.isEmpty) return false;
    if (_ignoredDirectoryNames.contains(name)) return true;
    // Hide common metadata directories that start with a dot.
    if (name.startsWith('.') && name != '..') return true;
    return false;
  }

  /// Create an OrionApiDirectory from a File entity
  OrionApiDirectory _createDirectoryItem(Directory dir, String parentPath) {
    final stat = dir.statSync();
    final name = path.basename(dir.path);
    return OrionApiDirectory(
      path: dir.path,
      name: name,
      lastModified: stat.modified.millisecondsSinceEpoch,
      locationCategory: 'Local',
      parentPath: parentPath,
    );
  }

  /// Create an OrionApiFile from a File entity
  OrionApiFile _createFileItem(File file, String parentPath) {
    final stat = file.statSync();
    final name = path.basename(file.path);
    return OrionApiFile(
      file: file,
      path: file.path,
      name: name,
      parentPath: parentPath,
      lastModified: stat.modified.millisecondsSinceEpoch,
      locationCategory: 'Local',
    );
  }

  /// Check if USB/media directory is available
  Future<bool> usbAvailable() async {
    try {
      final dir = Directory(_baseDirectory);
      return dir.existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Delete a file (not implemented for local provider - would need special permissions)
  Future<bool> deleteFile(String location, String filePath) async {
    _log.warning('deleteFile not supported for LocalFilesProvider');
    return false;
  }

  /// Start print (not implemented for local provider - would need backend integration)
  Future<bool> startPrint(String location, String filePath) async {
    _log.warning('startPrint not supported for LocalFilesProvider');
    return false;
  }

  /// List items as OrionApiItems
  Future<List<OrionApiItem>> listItemsAsOrionApiItems(
      String location, String subdirectory,
      {int pageSize = 100, int pageIndex = 0}) async {
    _log.info(
        'listItemsAsOrionApiItems: location=$location subdirectory=$subdirectory pageSize=$pageSize pageIndex=$pageIndex');
    try {
      // Build the full path to scan
      final fullPath = subdirectory.isEmpty
          ? _baseDirectory
          : path.join(_baseDirectory, subdirectory);

      // Resolve the path to prevent directory traversal attacks (../..)
      final resolvedPath = path.normalize(path.absolute(fullPath));
      final resolvedBase = path.normalize(path.absolute(_baseDirectory));

      // Validate that the resolved path is within the base directory
      if (!resolvedPath.startsWith(resolvedBase)) {
        _log.warning(
            'Attempted to navigate outside base directory in listItems. Base: $resolvedBase, Requested: $resolvedPath');
        return [];
      }

      final dir = Directory(resolvedPath);

      // Check if directory exists
      if (!dir.existsSync()) {
        _log.warning('Directory does not exist: $resolvedPath');
        return [];
      }

      // List all items in the directory
      final List<OrionApiItem> items = [];

      // Add directories first
      final dirEntities = dir.listSync(recursive: false, followLinks: false);
      final directories = <OrionApiDirectory>[];
      final files = <OrionApiFile>[];

      for (final entity in dirEntities) {
        if (entity is Directory) {
          try {
            if (_isIgnoredDirectory(entity)) {
              continue;
            }
            directories.add(_createDirectoryItem(entity, resolvedPath));
          } catch (e) {
            _log.warning('Failed to create directory item: ${entity.path}', e);
          }
        } else if (entity is File) {
          if (_isSupportedFile(entity.path)) {
            try {
              files.add(_createFileItem(entity, resolvedPath));
            } catch (e) {
              _log.warning('Failed to create file item: ${entity.path}', e);
            }
          }
        }
      }

      // Sort items
      directories.sort((a, b) => a.name.compareTo(b.name));
      files.sort((a, b) => a.name.compareTo(b.name));

      items.addAll(directories);
      items.addAll(files);

      _log.fine('listItemsAsOrionApiItems: built items count=${items.length}');
      return items;
    } catch (e, st) {
      _log.severe('Failed to fetch items as OrionApiItems', e, st);
      rethrow;
    }
  }
}
