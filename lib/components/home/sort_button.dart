import 'dart:io';

import 'package:flutter/material.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:stow_plain/stow_plain.dart';

// ignore_for_file: deprecated_member_use

class SortNotes {
  SortNotes._();

  static final List<void Function(List<String>, bool)> sortFunctions = [
    _sortNotesAlpha,
    _sortNotesLastModified,
    _sortNotesSize,
  ];
  static final PlainStow<int> _sortFunctionIdx = stows.sortFunctionIdx;
  static final PlainStow<bool> _isIncreasingOrder = stows.isSortIncreasing;

  static var _isNeeded = true;
  static bool get isNeeded => _isNeeded;

  static int get sortFunctionIdx => _sortFunctionIdx.value;
  static set sortFunctionIdx(int value) {
    _sortFunctionIdx.value = value;
    _isNeeded = true;
  }

  static bool get isIncreasingOrder => _isIncreasingOrder.value;
  static set isIncreasingOrder(bool value) {
    _isIncreasingOrder.value = value;
    _isNeeded = true;
  }

  static void _reverse(List<String> list) {
    final n = list.length;
    for (int i = 0; i < n / 2; i++) {
      final tmp = list[i];
      list[i] = list[n - i - 1];
      list[n - i - 1] = tmp;
    }
  }

  static void sortNotes(List<String> filePaths, {bool forced = false}) {
    if (_isNeeded || forced) {
      sortFunctions[sortFunctionIdx].call(filePaths, isIncreasingOrder);
      _isNeeded = false;
    }
  }

  static String getSortFunctionName(int idx) {
    if (idx < 0 || idx >= sortFunctions.length) {
      return t.home.sortNames.alphabetical;
    }
    switch (idx) {
      case 0:
        return t.home.sortNames.alphabetical;
      case 1:
        return t.home.sortNames.lastModified;
      case 2:
        return t.home.sortNames.sizeOnDisk;
      default:
        return t.home.sortNames.alphabetical;
    }
  }

  static void _sortNotesAlpha(List<String> filePaths, bool isIncreasing) {
    filePaths.sort((a, b) => a.split('/').last.compareTo(b.split('/').last));
    if (!isIncreasing) _reverse(filePaths);
  }

  static DateTime _getDirLastModified(Directory dir) {
    assert(dir.existsSync());
    DateTime out = dir.statSync().modified;
    for (final FileSystemEntity entity in dir.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.absolute.path.endsWith(Editor.extension)) {
        final DateTime curFileModified = entity.lastModifiedSync();
        if (curFileModified.isAfter(out)) out = curFileModified;
      }
    }
    return out;
  }

  static void _sortNotesLastModified(
    List<String> filePaths,
    bool isIncreasing,
  ) {
    filePaths.sort((a, b) {
      final Directory firstDir = Directory(FileManager.documentsDirectory + a);
      final Directory secondDir = Directory(FileManager.documentsDirectory + b);
      final DateTime firstTime = firstDir.existsSync()
          ? _getDirLastModified(firstDir)
          : _getFileLastModified(a + Editor.extension);
      final DateTime secondTime = secondDir.existsSync()
          ? _getDirLastModified(secondDir)
          : _getFileLastModified(b + Editor.extension);
      return firstTime.compareTo(secondTime);
    });
    if (!isIncreasing) _reverse(filePaths);
  }

  static DateTime _getFileLastModified(String filePath) {
    final file = FileManager.getFile(filePath);
    if (file.existsSync()) {
      return file.lastModifiedSync();
    }
    return DateTime.min;
  }

  static int _getDirSize(Directory dir) {
    assert(dir.existsSync());
    int out = 0;
    for (final FileSystemEntity entity in dir.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.absolute.path.endsWith(Editor.extension)) {
        final int curFileSize = entity.lengthSync();
        out += curFileSize;
      }
    }
    return out;
  }

  static void _sortNotesSize(List<String> filePaths, bool isIncreasing) {
    filePaths.sort((a, b) {
      final Directory firstDir = Directory(FileManager.documentsDirectory + a);
      final Directory secondDir = Directory(FileManager.documentsDirectory + b);
      final int firstSize = firstDir.existsSync()
          ? _getDirSize(firstDir)
          : _getFileSize('$a${Editor.extension}');
      final int secondSize = secondDir.existsSync()
          ? _getDirSize(secondDir)
          : _getFileSize('$b${Editor.extension}');
      return firstSize.compareTo(secondSize);
    });
    if (!isIncreasing) _reverse(filePaths);
  }

  static int _getFileSize(String filePath) {
    final file = FileManager.getFile(filePath);
    if (file.existsSync()) {
      return file.statSync().size;
    }
    return 0;
  }
}

class SortButton extends StatelessWidget {
  const SortButton({super.key, required this.callback});

  final void Function() callback;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.sort),
      onPressed: () async {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return _SortButtonDialog();
          },
        ).then((_) => callback());
      },
    );
  }
}

class _SortButtonDialog extends StatefulWidget {
  @override
  State<_SortButtonDialog> createState() => _SortButtonDialogState();
}

class _SortButtonDialogState extends State<_SortButtonDialog> {
  @override
  Widget build(BuildContext context) {
    // Needs to match the order of sortFunctions
    final List<String> sortNames = [
      t.home.sortNames.alphabetical,
      t.home.sortNames.lastModified,
      t.home.sortNames.sizeOnDisk,
    ];

    return Align(
      alignment: Alignment.topRight,
      child: Container(
        width: 220,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
        clipBehavior: Clip.antiAlias,
        child: Material(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int idx = 0; idx < sortNames.length; idx++)
                ListTile(
                  title: Text(sortNames[idx]),
                  leading: Radio<int>(
                    value: idx,
                    groupValue: SortNotes.sortFunctionIdx,
                    onChanged: (int? newValue) {
                      SortNotes.sortFunctionIdx = newValue!;
                      setState(() {});
                    },
                  ),
                ),
              ListTile(
                title: Text(
                  stows.isSortIncreasing.value
                      ? t.settings.sortOrders.ascending
                      : t.settings.sortOrders.descending,
                ),
                leading: Checkbox(
                  value: SortNotes.isIncreasingOrder,
                  onChanged: (bool? v) {
                    SortNotes.isIncreasingOrder = v!;
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
