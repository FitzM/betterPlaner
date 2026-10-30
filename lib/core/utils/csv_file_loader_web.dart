// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

typedef CsvFileCallback = void Function(String fileName, String content);

void pickAndReadCsvFile({
  required CsvFileCallback onLoaded,
  void Function(String error)? onError,
}) {
  try {
    final uploadInput = html.FileUploadInputElement()
      ..accept = '.csv,text/csv,text/plain';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.readAsText(file);
        reader.onLoadEnd.listen((e) {
          final content = reader.result;
          if (content is String && content.isNotEmpty) {
            onLoaded(file.name, content);
          } else {
            onError?.call('The selected file was empty.');
          }
        });
        reader.onError.listen((e) {
          onError?.call('Failed to read file: $e');
        });
      }
    });
  } catch (e) {
    onError?.call('Error opening file picker: $e');
  }
}
