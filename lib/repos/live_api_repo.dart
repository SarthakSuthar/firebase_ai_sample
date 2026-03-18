import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_ai_sample/utils/logger.dart';
import 'package:flutter/foundation.dart';

class LiveApiRepo {
  final liveModel = FirebaseAI.googleAI().liveGenerativeModel(
    model: 'gemini-2.5-flash-native-audio-preview-12-2025',
    liveGenerationConfig: LiveGenerationConfig(
      responseModalities: [ResponseModalities.audio],
    ),
  );

  LiveSession? _session;
  bool _sessionOpened = false;

  final _audioResponseController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<LiveApiStatus>.broadcast();
  final _turnCompleteController = StreamController<void>.broadcast();

  Stream<Uint8List> get audioResponseStream => _audioResponseController.stream;
  Stream<LiveApiStatus> get statusStream => _statusController.stream;
  Stream<void> get turnCompleteStream => _turnCompleteController.stream;

  bool get isConnected => _sessionOpened;
  LiveSession? get session => _session;

  Future<void> connect() async {
    _statusController.add(LiveApiStatus.connecting);
    try {
      _session = await liveModel.connect();
      _sessionOpened = true;
      _statusController.add(LiveApiStatus.connected);

      // Start the continuous message processing loop
      unawaited(_processMessagesContinuously());
    } catch (e) {
      showlog('LiveApiRepo: connection error: $e');
      _statusController.add(LiveApiStatus.error);
      rethrow;
    }
  }

  /// Continuously listens for messages from the live session.
  /// This runs as a long-lived async loop using `await for`.
  Future<void> _processMessagesContinuously() async {
    final session = _session;
    if (session == null) return;

    try {
      await for (final response in session.receive()) {
        final message = response.message;

        if (message is LiveServerContent) {
          if (message.modelTurn != null) {
            _statusController.add(LiveApiStatus.aiSpeaking);
            for (final part in message.modelTurn!.parts) {
              if (part is InlineDataPart && part.mimeType.startsWith('audio')) {
                _audioResponseController.add(part.bytes);
              }
            }
          }
          if (message.turnComplete == true) {
            _statusController.add(LiveApiStatus.connected);
            _turnCompleteController.add(null);
          }
          if (message.interrupted == true) {
            showlog('LiveApiRepo: generation interrupted');
          }
        }
      }
    } catch (e) {
      showlog('LiveApiRepo: receive error: $e');
      _statusController.add(LiveApiStatus.error);
    }
  }

  Future<void> sendAudio(Uint8List audioBytes) async {
    final session = _session;
    if (session == null) return;
    try {
      final audioPart = InlineDataPart('audio/pcm', audioBytes);
      await session.sendAudioRealtime(audioPart);
    } catch (e) {
      showlog('LiveApiRepo: send audio error: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _session?.close();
    } catch (e) {
      showlog('LiveApiRepo: disconnect error: $e');
    }
    _session = null;
    _sessionOpened = false;
    _statusController.add(LiveApiStatus.disconnected);
  }

  void dispose() {
    _session?.close();
    _session = null;
    _sessionOpened = false;
    _audioResponseController.close();
    _statusController.close();
    _turnCompleteController.close();
  }
}

enum LiveApiStatus { disconnected, connecting, connected, aiSpeaking, error }
