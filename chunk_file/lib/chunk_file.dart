import 'dart:io';

import 'package:chunk_file/constants.dart';

Future<void> splitFileIntoChunks(String filePath) async {
  if (!Directory(resultDirectory).existsSync()) {
    await Directory(resultDirectory).create();
  }
  final metadataFile = File('${filePath}_metadata.txt');
  final metadataSink = metadataFile.openWrite();

  final file = File(filePath);
  if (!file.existsSync()) {
    print('input file does not exists');
    exit(-1);
  }
  final fileSize = await file.length();

  int offset = 0;
  int chunkIndex = 0;

  while (offset < fileSize) {
    final int end;
    final int contentLength;
    if (offset + chunkSize > fileSize) {
      end = fileSize;
      contentLength = fileSize - offset;
    } else {
      end = offset + chunkSize;
      contentLength = end - offset;
    }

    final chunk = await file.openRead(offset, end).toList();

    final chunkFileName = '${file.path}_chunk_$chunkIndex';
    final chunkFile = File(chunkFileName);
    await chunkFile.writeAsBytes(chunk.expand((x) => x).toList());

    final contentRange = 'bytes $offset-${end - 1}/$fileSize';
    metadataSink.writeln('Chunk $chunkIndex:');
    metadataSink.writeln('Content-Range: $contentRange');
    metadataSink.writeln('Content-Length: $contentLength');
    metadataSink.writeln('File: $chunkFileName');
    metadataSink.writeln('');

    offset += contentLength;
    chunkIndex++;
  }
  await metadataSink.close();

  print('File split into $chunkIndex chunks.');
}
