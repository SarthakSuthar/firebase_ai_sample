import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_ai_sample/utils/logger.dart';
import 'package:flutter/foundation.dart';

/// Repository responsible for managing the real-time connection to the Gemini Live API.
/// It handles establishing the session, sending audio data, and broadcasting
/// incoming audio responses and state changes to the rest of the application.
class LiveApiRepo {
  /// The generative model instance configured specifically for live, native audio interactions.
  final liveModel = FirebaseAI.googleAI().liveGenerativeModel(
    model: 'gemini-2.5-flash-native-audio-preview-12-2025',
    liveGenerationConfig: LiveGenerationConfig(
      responseModalities: [ResponseModalities.audio],
    ),
  );

  /// Holds the active live session once a connection is established.
  LiveSession? _session;

  /// Internal state to track if a session is currently open.
  bool _sessionOpened = false;

  /// Steam controllers to broadcast continuous updates to listeners (like the UI).
  /// Streams incoming PCM audio bytes from the AI.
  final _audioResponseController = StreamController<Uint8List>.broadcast();

  /// Streams updates about the current state of the connection and AI (e.g., aiSpeaking).
  final _statusController = StreamController<LiveApiStatus>.broadcast();

  /// Triggers an event whenever the AI has finished its current turn of speaking.
  final _turnCompleteController = StreamController<void>.broadcast();

  // Public getters to allow UI components to listen to the streams.
  Stream<Uint8List> get audioResponseStream => _audioResponseController.stream;
  Stream<LiveApiStatus> get statusStream => _statusController.stream;
  Stream<void> get turnCompleteStream => _turnCompleteController.stream;

  bool get isConnected => _sessionOpened;
  LiveSession? get session => _session;

  /// Connects to the Gemini Live API.
  /// Emits the corresponding status states and starts a background loop
  /// to process incoming messages continuously upon successful connection.
  Future<void> connect() async {
    _statusController.add(LiveApiStatus.connecting);
    try {
      _session = await liveModel.connect();
      _sessionOpened = true;
      _statusController.add(LiveApiStatus.connected);

      // Start the continuous message processing loop without blocking the execution
      unawaited(_processMessagesContinuously());
    } catch (e) {
      showlog('LiveApiRepo: connection error: $e');
      _statusController.add(LiveApiStatus.error);
      rethrow;
    }
  }

  /// Continuously listens for messages from the live session.
  /// This runs as a long-lived async loop using `await for`.
  /// Continuously listens for real-time messages from the active live session.
  /// This runs as a long-lived async loop using an `await for` stream iterator.
  Future<void> _processMessagesContinuously() async {
    final session = _session;
    if (session == null) return;

    try {
      // Loop over incoming messages from the AI as they arrive.
      await for (final response in session.receive()) {
        final message = response.message;

        // Check if the server sent content back.
        if (message is LiveServerContent) {
          // If the AI is sending a model turn, it means it is responding.
          if (message.modelTurn != null) {
            _statusController.add(LiveApiStatus.aiSpeaking);
            // Parse through the parts of the message to find audio chunks.
            for (final part in message.modelTurn!.parts) {
              if (part is InlineDataPart && part.mimeType.startsWith('audio')) {
                // Broadcast individual audio chunks to be played immediately or buffered.
                _audioResponseController.add(part.bytes);
              }
            }
          }
          // The AI has finished its current thought or sentence.
          if (message.turnComplete == true) {
            _statusController.add(LiveApiStatus.connected);
            _turnCompleteController.add(null); // Signal turn completion
          }
          // Handle cases where the AI's response was interrupted by the user.
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

  /// Sends PCM audio data from the user's microphone to the Gemini Realtime API.
  Future<void> sendAudio(Uint8List audioBytes) async {
    final session = _session;
    if (session == null) return;
    try {
      // Wrap the raw PCM bytes into an InlineDataPart and dispatch them.
      final audioPart = InlineDataPart('audio/pcm', audioBytes);
      await session.sendAudioRealtime(audioPart);
    } catch (e) {
      showlog('LiveApiRepo: send audio error: $e');
    }
  }

  /// Closes the active session and cleans up connection states.
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
