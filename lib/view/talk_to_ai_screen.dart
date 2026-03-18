import 'dart:async';

import 'package:firebase_ai_sample/repos/live_api_repo.dart';
import 'package:firebase_ai_sample/utils/audio_output.dart';
import 'package:firebase_ai_sample/utils/audio_utils.dart';
import 'package:firebase_ai_sample/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:waveform_flutter/waveform_flutter.dart' as wf;
import 'dart:math';

class TalkToAiScreen extends StatefulWidget {
  const TalkToAiScreen({super.key});

  @override
  State<TalkToAiScreen> createState() => _TalkToAiScreenState();
}

class _TalkToAiScreenState extends State<TalkToAiScreen>
    with TickerProviderStateMixin {
  final LiveApiRepo _liveApiRepo = LiveApiRepo();
  final AudioInput _audioInput = AudioInput();
  final AudioOutput _audioOutput = AudioOutput();

  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  LiveApiStatus _status = LiveApiStatus.disconnected;
  StreamSubscription? _audioInputSub;
  StreamSubscription? _audioResponseSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _turnCompleteSub;

  bool _recording = false;
  bool _loading = false;
  bool _sessionOpened = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _statusSub = _liveApiRepo.statusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });

    _audioResponseSub = _liveApiRepo.audioResponseStream.listen((audioBytes) {
      _audioOutput.addDataToAudioStream(audioBytes);
    });

    _turnCompleteSub = _liveApiRepo.turnCompleteStream.listen((_) {
      _audioOutput.playBufferedAudio();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _audioInputSub?.cancel();
    _audioResponseSub?.cancel();
    _statusSub?.cancel();
    _turnCompleteSub?.cancel();
    _audioInput.dispose();
    _audioOutput.dispose();
    if (_sessionOpened) {
      _liveApiRepo.disconnect();
    }
    _liveApiRepo.dispose();
    super.dispose();
  }

  // -- Session setup (connect/disconnect toggle) --
  Future<void> _setupSession() async {
    setState(() => _loading = true);

    try {
      await _audioOutput.init();
    } catch (e) {
      showlog('Audio Output init error: $e');
    }

    try {
      await _audioInput.init(); // This directly requests microphone permissions
    } catch (e) {
      _showError('Microphone error: $e');
      setState(() => _loading = false);
      return;
    }

    if (!_sessionOpened) {
      try {
        await _liveApiRepo.connect();
        _sessionOpened = true;
        await _audioOutput.playStream();
      } catch (e) {
        _showError('Connection failed: $e');
      }
    } else {
      if (_recording) await _stopRecording();
      await _liveApiRepo.disconnect();
      _sessionOpened = false;
    }

    setState(() => _loading = false);
  }

  // -- Recording controls --
  Future<void> _startRecording() async {
    if (!_sessionOpened) return;

    await _audioInputSub?.cancel();
    _audioInputSub = null;
    setState(() => _recording = true);

    try {
      final inputStream = await _audioInput.startRecordingStream();

      if (inputStream != null) {
        _audioInputSub = inputStream.listen(
          (data) => _liveApiRepo.sendAudio(data),
          onError: (e) {
            showlog('Audio Stream Error: $e');
            _stopRecording();
          },
          cancelOnError: true,
        );
      }

      _pulseController.repeat(reverse: true);
      _glowController.repeat(reverse: true);
    } catch (e) {
      showlog('_startRecording error: $e');
      _showError('Mic error: $e');
      setState(() => _recording = false);
    }
  }

  Future<void> _stopRecording() async {
    await _audioInputSub?.cancel();
    _audioInputSub = null;

    try {
      await _audioInput.stopRecording();
    } catch (e) {
      showlog('Stop recording error: $e');
    }

    _pulseController.stop();
    _pulseController.reset();
    _glowController.stop();
    _glowController.reset();

    setState(() => _recording = false);
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  // -- UI helpers --
  String get _statusText {
    if (_recording) return 'Listening...';
    if (_loading) return 'Connecting...';
    switch (_status) {
      case LiveApiStatus.connecting:
        return 'Connecting...';
      case LiveApiStatus.connected:
        return 'Connected';
      case LiveApiStatus.aiSpeaking:
        return 'AI is speaking...';
      case LiveApiStatus.error:
        return 'Connection error';
      case LiveApiStatus.disconnected:
        return 'Tap connect to start';
    }
  }

  Color get _statusColor {
    if (_recording) return const Color(0xFF43E97B);
    if (_loading) return const Color(0xFFFF9A44);
    switch (_status) {
      case LiveApiStatus.connecting:
        return const Color(0xFFFF9A44);
      case LiveApiStatus.connected:
        return const Color(0xFF4FACFE);
      case LiveApiStatus.aiSpeaking:
        return const Color(0xFFB19CD9);
      case LiveApiStatus.error:
        return const Color(0xFFFC6076);
      case LiveApiStatus.disconnected:
        return const Color(0xFF7F8C8D);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Something went wrong'),
          content: SingleChildScrollView(child: SelectableText(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Voice AI',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _sessionOpened ? 'Disconnect' : 'Connect',
            onPressed: !_loading ? _setupSession : null,
            icon: Icon(
              Icons.network_wifi,
              color: _sessionOpened ? const Color(0xFF43E97B) : Colors.white70,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),

          // Status pill
          _buildStatusPill(),

          const Spacer(),

          // Audio visualizer or Idle Orb
          if (_recording && _audioInput.amplitudeStream != null)
            _buildWaveform()
          else
            _buildIdleOrb(),

          const Spacer(),

          // Mic button
          _buildMicButton(),

          const SizedBox(height: 20),

          // Hint text
          Text(
            !_sessionOpened
                ? 'Connect first →'
                : (_recording ? 'Tap to stop' : 'Tap to speak'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _statusColor.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _statusText,
            style: TextStyle(
              color: _statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 160,
      child: wf.Waveform(amplitudeStream: _audioInput.amplitudeStream),
    );
  }

  Widget _buildIdleOrb() {
    return SizedBox(
      height: 160,
      child: Center(
        child: _OrbWidget(
          isActive: _status == LiveApiStatus.aiSpeaking,
          size: 100,
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = _recording ? _pulseAnimation.value : 1.0;
        final glow = _recording ? _glowAnimation.value : 0.0;
        final gradient = _recording
            ? const [Color(0xFFFC6076), Color(0xFFFF9A44)]
            : const [Color(0xFFB19CD9), Color(0xFF9881CD)];

        return GestureDetector(
          onTap: (_sessionOpened && !_loading) ? _toggleRecording : null,
          child: Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _sessionOpened
                      ? gradient
                      : [Colors.grey.shade800, Colors.grey.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_sessionOpened ? gradient.first : Colors.grey.shade800)
                            .withValues(alpha: 0.3 + glow * 0.4),
                    blurRadius: 20 + glow * 20,
                    spreadRadius: glow * 8,
                  ),
                ],
              ),
              child: Icon(
                _recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: _sessionOpened ? Colors.white : Colors.white38,
                size: 42,
              ),
            ),
          ),
        );
      },
    );
  }
}

// -- Animated orb widget --
class _OrbWidget extends StatefulWidget {
  final bool isActive;
  final double size;

  const _OrbWidget({required this.isActive, this.size = 100.0});

  @override
  State<_OrbWidget> createState() => _OrbWidgetState();
}

class _OrbWidgetState extends State<_OrbWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final breathe = 0.8 + 0.2 * sin(t * 2 * pi);
        final currentSize = widget.size * breathe;

        return Container(
          width: currentSize,
          height: currentSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: widget.isActive
                  ? [
                      const Color(0xFFB19CD9).withValues(alpha: 0.8),
                      const Color(0xFF9881CD).withValues(alpha: 0.2),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.03),
                    ],
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: const Color(
                        0xFFB19CD9,
                      ).withValues(alpha: 0.4 * breathe),
                      blurRadius: 20 * breathe,
                      spreadRadius: 5 * breathe,
                    ),
                  ]
                : [],
          ),
        );
      },
    );
  }
}
