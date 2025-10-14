/*
 * Orion - Files Provider
 * Centralized state management for file listings and file actions.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:orion/backend_service/odyssey/odyssey_client.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/odyssey/models/files_models.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_file.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_directory.dart';
import 'package:orion/util/orion_api_filesystem/orion_api_item.dart';

/// Provides file listing state for grid/list screens.
///
/// Responsibilities:
/// * Fetch /files listing and convert to typed models
/// * Expose current directory, loading and error state
/// * Perform file actions: delete, start print, refresh
class FilesProvider extends ChangeNotifier {
  final OdysseyClient _client;
  final _log = Logger('FilesProvider');

  FilesListModel? _listing;
  FilesListModel? get listing => _listing;

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

  FilesProvider({OdysseyClient? client}) : _client = client ?? BackendService();

  /// Load items into provider state (convenience wrapper around listItemsAsOrionApiItems)
  Future<void> loadItems(String location, String subdirectory,
      {int pageSize = 100, int pageIndex = 0}) async {
    _log.info(
        'loadItems: location=$location subdirectory=$subdirectory pageSize=$pageSize pageIndex=$pageIndex');
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // Try the requested location first
      List<OrionApiItem> fetched = await listItemsAsOrionApiItems(
          location, subdirectory,
          pageSize: pageSize, pageIndex: pageIndex);
      _items = fetched;
      _location = location;
      _subdirectory = subdirectory;
      _loading = false;
      _error = null;
      _log.fine(
          'loadItems: fetched ${_items.length} items for $location/$subdirectory');
    } catch (e, st) {
      _log.warning(
          'Initial load failed for $location, attempting fallback if Usb',
          e,
          st);
      // If we attempted USB, try falling back to Local automatically
      if (location.toLowerCase() == 'usb') {
        try {
          final List<OrionApiItem> fetched = await listItemsAsOrionApiItems(
              'Local', subdirectory,
              pageSize: pageSize, pageIndex: pageIndex);
          _items = fetched;
          _location = 'Local';
          _subdirectory = subdirectory;
          _loading = false;
          _error = null;
          _log.info(
              'loadItems: fallback to Local succeeded, fetched ${_items.length} items');
          notifyListeners();
          return;
        } catch (e2, st2) {
          _log.severe('Fallback to Local also failed', e2, st2);
          _error = e2;
          _loading = false;
        }
      } else {
        _log.severe('Failed to load items into state', e, st);
        _error = e;
        _loading = false;
      }
    } finally {
      notifyListeners();
    }
  }

  Future<bool> usbAvailable() async {
    _log.fine('usbAvailable: checking USB availability (cached TTL 30s)');
    // Cache the usbAvailable check for a short duration to avoid hammering
    // the backend with repeated small listItems calls from the UI.
    try {
      final now = DateTime.now();
      const ttl = Duration(seconds: 30);
      if (_usbAvailableCache != null && _usbAvailableCachedAt != null) {
        if (now.difference(_usbAvailableCachedAt!) < ttl) {
          _log.fine('usbAvailable: returning cached=$_usbAvailableCache');
          return _usbAvailableCache!;
        }
      }
      final available = await _client.usbAvailable();
      _usbAvailableCache = available;
      _usbAvailableCachedAt = DateTime.now();
      _log.fine('usbAvailable: probe result=$available');
      return available;
    } catch (e, st) {
      _log.warning('usbAvailable check failed', e, st);
      return false;
    }
  }

  // Cached USB availability state
  bool? _usbAvailableCache;
  DateTime? _usbAvailableCachedAt;

  Future<void> listFiles(String location, String subdirectory,
      {int pageSize = 100, int pageIndex = 0}) async {
    _log.info(
        'listFiles: location=$location subdirectory=$subdirectory pageSize=$pageSize pageIndex=$pageIndex');
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final resp =
          await _client.listItems(location, pageSize, pageIndex, subdirectory);

      // Convert raw maps into typed models using our generated classes where possible.
      // ApiService.listItems returns a Map with 'files' and 'dirs'. We'll map them.
      final filesRaw = (resp['files'] as List?) ?? [];
      final dirsRaw = (resp['dirs'] as List?) ?? [];

      final files = filesRaw
          .where((e) => e != null)
          .map<FileEntry>((e) => FileEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      final dirs = dirsRaw
          .where((e) => e != null)
          .map<DirEntry>((e) => DirEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      _listing = FilesListModel(
          files: files, dirs: dirs, pageIndex: pageIndex, pageSize: pageSize);
      _location = location;
      _subdirectory = subdirectory;
      _loading = false;
      _error = null;
      _log.fine(
          'listFiles: constructed FilesListModel files=${files.length} dirs=${dirs.length}');
    } catch (e, st) {
      _log.severe('Failed to list files', e, st);
      _error = e;
      _loading = false;
    } finally {
      notifyListeners();
    }
  }

  Future<FileMetadata?> fetchFileMetadata(
      String location, String filePath) async {
    _log.fine('fetchFileMetadata: location=$location filePath=$filePath');
    try {
      final raw = await _client.getFileMetadata(location, filePath);
      final meta = FileMetadata.fromJson(raw);
      _log.fine('fetchFileMetadata: success for $filePath');
      return meta;
    } catch (e, st) {
      _log.warning('Failed to fetch metadata for $filePath', e, st);
      return null;
    }
  }

  Future<bool> deleteFile(String location, String filePath) async {
    _log.info('deleteFile: location=$location filePath=$filePath');
    try {
      await _client.deleteFile(location, filePath);
      _log.fine('deleteFile: success for $filePath');
      return true;
    } catch (e, st) {
      _log.severe('Failed to delete file $filePath', e, st);
      return false;
    }
  }

  Future<bool> startPrint(String location, String filePath) async {
    _log.info('startPrint: location=$location filePath=$filePath');
    try {
      await _client.startPrint(location, filePath);
      _log.fine('startPrint: success for $filePath');
      return true;
    } catch (e, st) {
      _log.severe('Failed to start print $filePath', e, st);
      return false;
    }
  }

  /// Convenience that mirrors the previous `_getItems` behavior used
  /// by `GridFilesScreen` — returns a list of `OrionApiItem` (dirs first,
  /// then files) built from the raw API response.
  Future<List<OrionApiItem>> listItemsAsOrionApiItems(
      String location, String subdirectory,
      {int pageSize = 100, int pageIndex = 0}) async {
    _log.info(
        'listItemsAsOrionApiItems: location=$location subdirectory=$subdirectory pageSize=$pageSize pageIndex=$pageIndex');
    try {
      final resp =
          await _client.listItems(location, pageSize, pageIndex, subdirectory);

      final List<OrionApiFile> files = (resp['files'] as List?)
              ?.where((item) => item != null)
              .map<OrionApiFile>(
                  (item) => OrionApiFile.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];

      final List<OrionApiDirectory> dirs = (resp['dirs'] as List?)
              ?.where((item) => item != null)
              .map<OrionApiDirectory>((item) =>
                  OrionApiDirectory.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
      final List<OrionApiItem> items = [...dirs, ...files];
      _log.fine('listItemsAsOrionApiItems: built items count=${items.length}');
      return items;
    } catch (e, st) {
      _log.severe('Failed to fetch items as OrionApiItems', e, st);
      rethrow;
    }
  }
}
