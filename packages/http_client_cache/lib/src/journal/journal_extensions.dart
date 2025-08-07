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
  Future<void> writeJournal(FileSystem fs) async {
    final journalFile = fs.file(_journalFileName);
    final buffer = writeToBuffer();
    await journalFile.writeAsBytes(buffer);
  }
}

/// Loads the journal data from the file system.
///
/// The journal data can be read either from a JSON file or from a binary
/// buffer.
///
/// - [fs]: The file system to read the journal data from.
/// - Returns: The loaded [Journal] object.
Future<Journal> loadJournal(FileSystem fs) async {
  final journalFile = fs.file(_journalFileName);
  if (journalFile.existsSync()) {
    final buffer = await journalFile.readAsBytes();
    return Journal.fromBuffer(buffer);
  } else {
    final journal = Journal();
    await journal.writeJournal(fs);
    return journal;
  }
}
