import 'dart:convert';

import 'package:file/file.dart';

import 'journal.pb.dart';

const _journalFileName = 'journal';

/// Extension methods for the [Journal] class to handle reading and writing
/// journal data to the file system.
extension JournalExtension on Journal {
  /// Writes the journal data to the file system.
  ///
  /// The journal data can be written either as JSON or as a binary buffer.
  ///
  /// - [fs]: The file system to write the journal data to.
  /// - [asJson]: If true, the journal data is written as JSON. Otherwise, 
  ///   it is written as a binary buffer.
  Future<void> writeJournal(FileSystem fs, {bool asJson = false}) async {
    final journalFile = fs.file(_journalFileName);
    if (asJson) {
      final obj = toProto3Json();
      final json = jsonEncode(obj);
      await journalFile.writeAsString(json);
    } else {
      final buffer = writeToBuffer();
      await journalFile.writeAsBytes(buffer);
    }
  }
}

/// Loads the journal data from the file system.
///
/// The journal data can be read either from a JSON file or from a binary 
/// buffer.
///
/// - [fs]: The file system to read the journal data from.
/// - [asJson]: If true, the journal data is read from a JSON file. Otherwise, 
///   it is read from a binary buffer.
/// - Returns: The loaded [Journal] object.
Future<Journal> loadJournal(FileSystem fs, {bool asJson = false}) async {
  final journalFile = fs.file(_journalFileName);
  if (journalFile.existsSync()) {
    if (asJson) {
      final json = await journalFile.readAsString();
      return Journal.fromJson(json);
    } else {
      final buffer = await journalFile.readAsBytes();
      return Journal.fromBuffer(buffer);
    }
  } else {
    final journal = Journal();
    await journal.writeJournal(fs, asJson: asJson);
    return journal;
  }
}
