import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_ai_sample/utils/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Handles the playback of streaming audio responses from the AI.
/// It buffers PCM audio chunks and plays them back smoothly using a temporary WAV file.
class AudioOutput {
  bool initialized = false;
  final AudioPlayer _player = AudioPlayer();

  // A temporary buffer holding raw PCM audio chunks before they are packaged into a playable format.
  final List<int> _audioBuffer = [];

  // Expected audio parameters defined by the Gemini Live API.
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
  /// Clears any leftover audio in the buffer.
  Future<void> playStream() async {
    _audioBuffer.clear();
    await stopStream();
  }

  /// Appends newly arrived chunk of raw PCM bytes from the API into our memory buffer.
  void addDataToAudioStream(Uint8List audioChunk) {
    _audioBuffer.addAll(audioChunk);
  }

  /// Stops any currently playing audio track.
  Future<void> stopStream() async {
    await _player.stop();
  }

  /// Compiles all buffered PCM data into a WAV file and uses [AudioPlayer] to play it.
  /// Typically called sequentially after the AI completes a turn to ensure continuous output.
  Future<void> playBufferedAudio() async {
    if (_audioBuffer.isEmpty) return;

    // Retrieve and immediately clear the incoming buffer to process new chunks
    final pcmBytes = Uint8List.fromList(_audioBuffer);
    _audioBuffer.clear();

    // The just_audio plugin (and most native players) expect standard audio formats like WAV.
    // So we manually add a WAV Header to the raw PCM data.
    final wavBytes = _createWavFromPcm(
      pcmBytes,
      sampleRate,
      channels,
      bitsPerSample,
    );

    File? tempFile;
    try {
      // Create a unique temporary file to dump the WAV bytes locally.
      final dir = await getTemporaryDirectory();
      tempFile = File(
        '${dir.path}/ai_audio_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      await tempFile.writeAsBytes(wavBytes, flush: true);

      // Tell the audio player to consume and play the generated temporary WAV file.
      await _player.setFilePath(tempFile.path);
      await _player.play();
      showlog('AudioOutput: Playing ${wavBytes.length} bytes of WAV audio');

      // Wait until playback successfully finishes.
      await _player.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );
    } catch (e) {
      showlog('AudioOutput: playback error $e');
    } finally {
      // Clean up the temporary file from storage after playback or failure.
      await tempFile?.delete(); // Always clean up temp file
    }
  }

  /// Utility function to wrap Raw PCM audio data into a standard WAV format
  /// by prepping and appending a valid RIFF header on top of the bytes.
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
