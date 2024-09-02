import 'package:uuid/uuid.dart';

// kibibyte/KiB and mebibyte/MiB are byte multiples using binary notation. They fix the ambiguity with the kilobyte and megabyte notation, which are multiples of 10
// https://en.wikipedia.org/wiki/Byte#Multiple-byte_units
const _k256KiB = 256 * 1024; // 262144B ~ 256kB
const _k1MiB = _k256KiB * 4; // 1048576B ~ 1MB
const chunkSize = _k1MiB * 10;

const resultDirectory = './result';
const uuid = Uuid();
