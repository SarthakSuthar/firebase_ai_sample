import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:waveform_flutter/waveform_flutter.dart' as wf;

/// Handles recording user voice input securely and streaming real-time PCM bytes.
/// Extends [ChangeNotifier] so UI components can reactively update when recording state changes.
class AudioInput extends ChangeNotifier {
  // Underlying plugin responsible for capturing audio streams securely from the device.
  AudioRecorder _recorder = AudioRecorder();
  // Configured to 16-bit PCM standard to match the Gemini API requirements.
  final AudioEncoder _encoder = AudioEncoder.pcm16bits;

  bool isRecording = false;
  bool isPaused = false;

  // Manages mapping the raw hardware stream packets into an accessible [Uint8List] stream.
  StreamController<Uint8List>? _audioDataController;
  StreamSubscription? _recorderStreamSub;

  Stream<Uint8List>? get audioStream => _audioDataController?.stream;

  // Manages tracking and dispatching volume bounds (amplitude) for visualizers.
  Stream<wf.Amplitude>? amplitudeStream;
  StreamSubscription? _amplitudeSubscription;
  StreamController<wf.Amplitude>? _amplitudeStreamController;

  Future<void> init() async {
    await _checkPermission();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioDataController?.close();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    PermissionStatus status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw MicrophonePermissionDeniedException(
        'App does not have mic permissions. Please grant them in settings.',
      );
    }
  }

  /// Initiates microphone capture and provides a live stream of recorded PCM bytes.
  Future<Stream<Uint8List>?> startRecordingStream() async {
    // 1. Clean up any existing active streams before instantiating new ones.
    await _amplitudeSubscription?.cancel();
    if (_amplitudeStreamController != null &&
        !_amplitudeStreamController!.isClosed) {
      await _amplitudeStreamController!.close();
    }

    await _recorderStreamSub?.cancel();
    if (_audioDataController != null && !_audioDataController!.isClosed) {
      await _audioDataController!.close();
    }

    _audioDataController = StreamController<Uint8List>();

    // 2. Clear out the previous recording instance.
    // Re-instantiating the recorder guarantees we get a freshly isolated physical stream
    // and fixes frequent "Stream has already been listened to" exceptions.
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      debugPrint('Error stopping recorder: $e');
    }
    await _recorder.dispose();
    _recorder = AudioRecorder();

    // 1. DEVICE SELECTION LOGIC
    // Fetch all devices to find the real microphone
    final devices = await _recorder.listInputDevices();
    InputDevice? selectedDevice;

    try {
      // Find the device that is NOT BlackHole and looks like a built-in mic.
      // Browsers often name it "Default - Internal Microphone" or "Built-in Audio".
      selectedDevice = devices.firstWhere(
        (device) {
          final label = device.label.toLowerCase();
          return !label.contains('blackhole') &&
              (label.contains('internal') ||
                  label.contains('built-in') ||
                  label.contains('macbook'));
        },
        // Fallback: Just find anything that isn't Blackhole
        orElse: () => devices.firstWhere(
          (d) => !d.label.toLowerCase().contains('blackhole'),
          orElse: () => devices.first, // Absolute fallback
        ),
      );
    } catch (e) {
      debugPrint('Error selecting device: $e');
    }

    // Configures the core recording params to match the exact specs the Gemini API expects
    // e.g. 24Khz standard mono stream while heavily suppressing surrounding background noise.
    var recordConfig = RecordConfig(
      encoder: _encoder,
      sampleRate: 24000,
      device: selectedDevice,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      androidConfig: const AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceCommunication,
      ),
      iosConfig: const IosRecordConfig(categoryOptions: []),
    );

    // Request the platform plugin to start delivering hardware bytes.
    final rawStream = await _recorder.startStream(recordConfig);

    // Manually push each captured hardware packet downstream to our own controllers
    _recorderStreamSub = rawStream.listen(
      (data) {
        if (data.isNotEmpty &&
            _audioDataController != null &&
            !_audioDataController!.isClosed) {
          _audioDataController!.add(data);
        }
      },
      onError: (e) {
        debugPrint('Recorder stream error: $e');
        if (_audioDataController != null && !_audioDataController!.isClosed) {
          _audioDataController!.addError(e);
        }
      },
      onDone: () {
        // Do not close the controller here automatically; let stopRecording handle it
        // to prevent race conditions in the UI.
      },
    );

    _amplitudeStreamController = StreamController<wf.Amplitude>.broadcast();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
          _amplitudeStreamController?.add(
            wf.Amplitude(current: amp.current, max: amp.max),
          );
        });
    amplitudeStream = _amplitudeStreamController?.stream;

    isRecording = true;
    notifyListeners();

    return _audioDataController!.stream;
  }

  Future<void> stopRecording() async {
    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('Error stopping recorder hardware: $e');
    }
    await _amplitudeSubscription?.cancel();
    await _amplitudeStreamController?.close();
    amplitudeStream = null;

    await _recorderStreamSub?.cancel();
    await _audioDataController?.close();
    _audioDataController = null;

    isRecording = false;
    notifyListeners();
  }

  Future<void> togglePause() async {
    if (isPaused) {
      await _recorder.resume();
      isPaused = false;
    } else {
      await _recorder.pause();
      isPaused = true;
    }
    notifyListeners();
    return;
  }
}

/// An exception thrown when microphone permission is denied or not granted.
class MicrophonePermissionDeniedException implements Exception {
  /// The optional message associated with the permission denial.
  final String? message;

  /// Creates a new [MicrophonePermissionDeniedException] with an optional [message].
  MicrophonePermissionDeniedException([this.message]);

  @override
  String toString() {
    return 'MicrophonePermissionDeniedException: $message';
  }
}
