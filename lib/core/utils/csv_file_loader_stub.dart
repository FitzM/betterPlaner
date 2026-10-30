typedef CsvFileCallback = void Function(String fileName, String content);

void pickAndReadCsvFile({
  required CsvFileCallback onLoaded,
  void Function(String error)? onError,
}) {
  onError?.call('File picker is only available in web browsers');
}

