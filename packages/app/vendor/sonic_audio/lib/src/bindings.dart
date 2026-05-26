import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef SonicInitC = Int32 Function();
typedef SonicInitDart = int Function();

typedef SonicDisposeC = Void Function();
typedef SonicDisposeDart = void Function();

typedef PlayerLoadC = Int32 Function(Pointer<Utf8> url, Pointer<Utf8> headers);
typedef PlayerLoadDart = int Function(Pointer<Utf8> url, Pointer<Utf8> headers);

typedef PlayerLoadAsyncC =
    Void Function(Pointer<Utf8> url, Pointer<Utf8> headers);
typedef PlayerLoadAsyncDart =
    void Function(Pointer<Utf8> url, Pointer<Utf8> headers);

typedef PlayerGetLoadStatusC = Int32 Function();
typedef PlayerGetLoadStatusDart = int Function();

typedef PlayerPlayC = Void Function();
typedef PlayerPlayDart = void Function();

typedef PlayerPauseC = Void Function();
typedef PlayerPauseDart = void Function();

typedef PlayerStopC = Void Function();
typedef PlayerStopDart = void Function();

typedef PlayerSeekC = Void Function(Double seconds);
typedef PlayerSeekDart = void Function(double seconds);

typedef PlayerSetVolumeC = Void Function(Float volume);
typedef PlayerSetVolumeDart = void Function(double volume);

typedef PlayerSetOutputDeviceC = Int32 Function(Int32 index);
typedef PlayerSetOutputDeviceDart = int Function(int index);

typedef PlayerSetBufferDurationC = Void Function(Float seconds);
typedef PlayerSetBufferDurationDart = void Function(double seconds);

typedef PlayerSetNativeRateC = Void Function(Int32 enabled);
typedef PlayerSetNativeRateDart = void Function(int enabled);

typedef PlayerSetExclusiveAudioC = Void Function(Int32 enabled);
typedef PlayerSetExclusiveAudioDart = void Function(int enabled);

typedef PlayerGetStateC = Int32 Function();
typedef PlayerGetStateDart = int Function();

typedef PlayerGetPositionC = Double Function();
typedef PlayerGetPositionDart = double Function();

typedef PlayerGetDurationC = Double Function();
typedef PlayerGetDurationDart = double Function();

typedef GetPlaybackDeviceCountC = Int32 Function();
typedef GetPlaybackDeviceCountDart = int Function();

typedef GetPlaybackDeviceInfoC =
    Void Function(Int32 index, Pointer<SonicDeviceInfo> info);
typedef GetPlaybackDeviceInfoDart =
    void Function(int index, Pointer<SonicDeviceInfo> info);

typedef GetCaptureDeviceCountC = Int32 Function();
typedef GetCaptureDeviceCountDart = int Function();

typedef GetCaptureDeviceInfoC =
    Void Function(Int32 index, Pointer<SonicDeviceInfo> info);
typedef GetCaptureDeviceInfoDart =
    void Function(int index, Pointer<SonicDeviceInfo> info);

final class SonicDeviceInfo extends Struct {
  @Array(256)
  external Array<Uint8> name;

  @Array(256)
  external Array<Uint8> id;

  @Int32()
  external int isDefault;

  @Int32()
  external int backend;
}

class SonicAudioBindings {
  final DynamicLibrary _lib;

  late final SonicInitDart init;
  late final SonicDisposeDart dispose;

  late final PlayerLoadDart playerLoad;
  late final PlayerLoadAsyncDart playerLoadAsync;
  late final PlayerGetLoadStatusDart playerGetLoadStatus;
  late final PlayerPlayDart playerPlay;
  late final PlayerPauseDart playerPause;
  late final PlayerStopDart playerStop;
  late final PlayerSeekDart playerSeek;
  late final PlayerSetVolumeDart playerSetVolume;
  late final PlayerSetOutputDeviceDart playerSetOutputDevice;
  late final PlayerSetBufferDurationDart playerSetBufferDuration;
  late final PlayerSetNativeRateDart playerSetNativeRate;
  late final PlayerSetExclusiveAudioDart playerSetExclusiveAudio;

  late final PlayerGetStateDart playerGetState;
  late final PlayerGetPositionDart playerGetPosition;
  late final PlayerGetDurationDart playerGetDuration;

  late final GetPlaybackDeviceCountDart getPlaybackDeviceCount;
  late final GetPlaybackDeviceInfoDart getPlaybackDeviceInfo;
  late final GetCaptureDeviceCountDart getCaptureDeviceCount;
  late final GetCaptureDeviceInfoDart getCaptureDeviceInfo;

  SonicAudioBindings(this._lib) {
    init = _lib.lookupFunction<SonicInitC, SonicInitDart>('sonic_audio_init');
    dispose = _lib.lookupFunction<SonicDisposeC, SonicDisposeDart>(
      'sonic_audio_dispose',
    );

    playerLoad = _lib.lookupFunction<PlayerLoadC, PlayerLoadDart>(
      'sonic_audio_player_load',
    );
    playerLoadAsync = _lib
        .lookupFunction<PlayerLoadAsyncC, PlayerLoadAsyncDart>(
          'sonic_audio_player_load_async',
        );
    playerGetLoadStatus = _lib
        .lookupFunction<PlayerGetLoadStatusC, PlayerGetLoadStatusDart>(
          'sonic_audio_player_get_load_status',
        );
    playerPlay = _lib.lookupFunction<PlayerPlayC, PlayerPlayDart>(
      'sonic_audio_player_play',
    );
    playerPause = _lib.lookupFunction<PlayerPauseC, PlayerPauseDart>(
      'sonic_audio_player_pause',
    );
    playerStop = _lib.lookupFunction<PlayerStopC, PlayerStopDart>(
      'sonic_audio_player_stop',
    );
    playerSeek = _lib.lookupFunction<PlayerSeekC, PlayerSeekDart>(
      'sonic_audio_player_seek',
    );
    playerSetVolume = _lib
        .lookupFunction<PlayerSetVolumeC, PlayerSetVolumeDart>(
          'sonic_audio_player_set_volume',
        );
    playerSetOutputDevice = _lib
        .lookupFunction<PlayerSetOutputDeviceC, PlayerSetOutputDeviceDart>(
          'sonic_audio_player_set_output_device',
        );
    playerSetBufferDuration = _lib
        .lookupFunction<PlayerSetBufferDurationC, PlayerSetBufferDurationDart>(
          'sonic_audio_player_set_buffer_duration',
        );
    playerSetNativeRate = _lib
        .lookupFunction<PlayerSetNativeRateC, PlayerSetNativeRateDart>(
          'sonic_audio_player_set_native_rate_enabled',
        );
    playerSetExclusiveAudio = _lib
        .lookupFunction<PlayerSetExclusiveAudioC, PlayerSetExclusiveAudioDart>(
          'sonic_audio_player_set_exclusive_audio_enabled',
        );

    playerGetState = _lib.lookupFunction<PlayerGetStateC, PlayerGetStateDart>(
      'sonic_audio_player_get_state',
    );
    playerGetPosition = _lib
        .lookupFunction<PlayerGetPositionC, PlayerGetPositionDart>(
          'sonic_audio_player_get_position',
        );
    playerGetDuration = _lib
        .lookupFunction<PlayerGetDurationC, PlayerGetDurationDart>(
          'sonic_audio_player_get_duration',
        );

    getPlaybackDeviceCount = _lib
        .lookupFunction<GetPlaybackDeviceCountC, GetPlaybackDeviceCountDart>(
          'sonic_audio_get_playback_device_count',
        );
    getPlaybackDeviceInfo = _lib
        .lookupFunction<GetPlaybackDeviceInfoC, GetPlaybackDeviceInfoDart>(
          'sonic_audio_get_playback_device_info',
        );
    getCaptureDeviceCount = _lib
        .lookupFunction<GetCaptureDeviceCountC, GetCaptureDeviceCountDart>(
          'sonic_audio_get_capture_device_count',
        );
    getCaptureDeviceInfo = _lib
        .lookupFunction<GetCaptureDeviceInfoC, GetCaptureDeviceInfoDart>(
          'sonic_audio_get_capture_device_info',
        );
  }
}

class SonicAudioBridge {
  static SonicAudioBridge? _instance;
  late final DynamicLibrary _dylib;
  late final SonicAudioBindings _bindings;

  SonicAudioBridge._() {
    if (Platform.isLinux) {
      _dylib = DynamicLibrary.open('libsonic_audio.so');
    } else if (Platform.isWindows) {
      _dylib = DynamicLibrary.open('sonic_audio.dll');
    } else if (Platform.isAndroid) {
      _dylib = DynamicLibrary.open('libsonic_audio.so');
    } else {
      throw UnsupportedError(
        'Unsupported platform: ${Platform.operatingSystem}',
      );
    }
    _bindings = SonicAudioBindings(_dylib);
  }

  static SonicAudioBridge get instance => _instance ??= SonicAudioBridge._();
  SonicAudioBindings get bindings => _bindings;
}
