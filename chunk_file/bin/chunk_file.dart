import 'package:chunk_file/chunk_file.dart' as chunk_file;

final path = "<replace with your file path>";

void main(List<String> _) async {
  await chunk_file.splitFileIntoChunks(path);
}
