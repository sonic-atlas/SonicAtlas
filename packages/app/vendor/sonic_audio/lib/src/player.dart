import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'common.dart';

enum PlayerState {
  idle, // 0
  buffering, // 1
  playing, // 2
  paused, // 3
  ended, // 4
  error, // 5
}

class SonicPlayer {
  final SonicAudioBindings _bindings;
  Timer? _pollTimer;
  bool _isDisposed = false;

  final _stateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  PlayerState _currentState = PlayerState.idle;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;

  Stream<PlayerState> get stateStream => _stateController.stream;

  Stream<Duration> get positionStream => _positionController.stream;

  Stream<Duration> get durationStream => _durationController.stream;

  PlayerState get state => _currentState;

  Duration get position => _currentPosition;

  Duration get duration => _currentDuration;

  bool get isPlaying => _currentState == PlayerState.playing;

  bool get isBuffering => _currentState == PlayerState.buffering;

  SonicPlayer() : _bindings = SonicAudioBridge.instance.bindings {
    final result = _bindings.init();
    if (result != 0) {
      throw Exception('Failed to initialize SonicAudio: $result');
    }
  }

  static List<AudioDevice> getAvailableDevices() {
    final bindings = SonicAudioBridge.instance.bindings;
    bindings.init();

    final count = bindings.getPlaybackDeviceCount();
    if (count <= 0) return [];

    final devices = <AudioDevice>[];
    final infoPtr = calloc<SonicDeviceInfo>();

    try {
      for (int i = 0; i < count; i++) {
        bindings.getPlaybackDeviceInfo(i, infoPtr);

        final namePtr = infoPtr.cast<Utf8>();
        final name = namePtr.toDartString();

        String getBackendName(int id) {
          switch (id) {
            case 1:
              return 'ALSA';
            case 2:
              return 'PulseAudio';
            case 3:
              return 'WASAPI';
            case 4:
              return 'AAudio';
            case 5:
              return 'OpenSL';
            default:
              return 'Unknown';
          }
        }

        final backendId = infoPtr.ref.backend;
        final backend = getBackendName(backendId);

        devices.add(
          AudioDevice(
            name: name,
            isDefault: infoPtr.ref.isDefault != 0,
            backend: backend,
            index: i,
          ),
        );
      }
    } finally {
      calloc.free(infoPtr);
    }

    return devices;
  }

  Future<void> load(String url, {String? headers}) async {
    if (_isDisposed) return;

    final urlPtr = url.toNativeUtf8();
    final headersPtr = headers?.toNativeUtf8() ?? nullptr;
    try {
      final result = _bindings.playerLoad(urlPtr, headersPtr);
      if (result != 0) {
        throw Exception('Failed to load: $result');
      }
      _startPolling();
    } finally {
      calloc.free(urlPtr);
      if (headers != null) calloc.free(headersPtr);
    }
  }

  void play() {
    if (_isDisposed) return;
    _bindings.playerPlay();
  }

  void pause() {
    if (_isDisposed) return;
    _bindings.playerPause();
  }

  void stop() {
    if (_isDisposed) return;
    _stopPolling();
    _bindings.playerStop();
    _currentState = PlayerState.idle;
    _currentPosition = Duration.zero;
    _stateController.add(_currentState);
    _positionController.add(_currentPosition);
  }

  void seek(Duration position) {
    if (_isDisposed) return;
    _bindings.playerSeek(position.inMilliseconds / 1000.0);
  }

  void setVolume(double volume) {
    if (_isDisposed) return;
    _bindings.playerSetVolume(volume.clamp(0.0, 1.0));
  }

  void setOutputDevice(int index) {
    if (_isDisposed) return;
    _bindings.playerSetOutputDevice(index);
  }

  void setBufferDuration(double seconds) {
    if (_isDisposed) return;
    _bindings.playerSetBufferDuration(seconds.clamp(0.1, 30.0));
  }

  void setNativeRateEnabled(bool enabled) {
    if (_isDisposed) return;
    _bindings.playerSetNativeRate(enabled ? 1 : 0);
  }

  void setExclusiveAudioEnabled(bool enabled) {
    if (_isDisposed) return;
    _bindings.playerSetExclusiveAudio(enabled ? 1 : 0);
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _updateState();
    });
    _updateState();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _updateState() {
    if (_isDisposed) return;

    final stateCode = _bindings.playerGetState();
    final newState =
        PlayerState.values[stateCode.clamp(0, PlayerState.values.length - 1)];

    final positionSec = _bindings.playerGetPosition();
    final durationSec = _bindings.playerGetDuration();

    final newPosition = Duration(milliseconds: (positionSec * 1000).toInt());
    final newDuration = Duration(milliseconds: (durationSec * 1000).toInt());

    if (newState != _currentState) {
      _currentState = newState;
      _stateController.add(_currentState);

      if (_currentState == PlayerState.ended) {
        _stopPolling();
      }
    }

    if (newPosition != _currentPosition) {
      _currentPosition = newPosition;
      _positionController.add(_currentPosition);
    }

    if (newDuration != _currentDuration) {
      _currentDuration = newDuration;
      _durationController.add(_currentDuration);
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _stopPolling();
    _bindings.playerStop();

    _stateController.close();
    _positionController.close();
    _durationController.close();
  }
}
