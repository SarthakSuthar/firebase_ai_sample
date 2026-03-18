import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_ai_sample/utils/logger.dart';
import 'package:path_provider/path_provider.dart';

class AudioOutput {
  bool initialized = false;
  final AudioPlayer _player = AudioPlayer();
  final List<int> _audioBuffer = [];

  final int sampleRate = 24000;
  final int channels = 1;
  final int bitsPerSample = 16;

  Future<void> init() async {
    if (initialized) return;
    initialized = true;
  }

  Future<void> dispose() async {
    if (initialized) {
      await stopStream();
      await _player.dispose();
      initialized = false;
    }
  }

  // Called when recording starts (or when session is setup)
  Future<void> playStream() async {
    _audioBuffer.clear();
    await stopStream();
  }

  void addDataToAudioStream(Uint8List audioChunk) {
    _audioBuffer.addAll(audioChunk);
  }

  Future<void> stopStream() async {
    await _player.stop();
  }

  Future<void> playBufferedAudio() async {
    if (_audioBuffer.isEmpty) return;

    final pcmBytes = Uint8List.fromList(_audioBuffer);
    _audioBuffer.clear();

    final wavBytes = _createWavFromPcm(
      pcmBytes,
      sampleRate,
      channels,
      bitsPerSample,
    );

    File? tempFile;
    try {
      final dir = await getTemporaryDirectory();
      tempFile = File(
        '${dir.path}/ai_audio_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      await tempFile.writeAsBytes(wavBytes, flush: true);

      await _player.setFilePath(tempFile.path);
      await _player.play();
      showlog('AudioOutput: Playing ${wavBytes.length} bytes of WAV audio');

      await _player.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );
    } catch (e) {
      showlog('AudioOutput: playback error $e');
    } finally {
      await tempFile?.delete(); // Always clean up temp file
    }
  }

  Uint8List _createWavFromPcm(
    Uint8List pcmData,
    int sampleRate,
    int channels,
    int bitsPerSample,
  ) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);

    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57); // W
    buffer.setUint8(9, 0x41); // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E

    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6D); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, channels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);

    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);

    final wavBytes = buffer.buffer.asUint8List();
    wavBytes.setRange(44, 44 + dataSize, pcmData);

    return wavBytes;
  }
}

class _WavAudioSource extends StreamAudioSource {
  final Uint8List _wavBytes;
  _WavAudioSource(this._wavBytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _wavBytes.length;
    return StreamAudioResponse(
      sourceLength: _wavBytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_wavBytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
