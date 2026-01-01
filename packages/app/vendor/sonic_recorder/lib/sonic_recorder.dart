import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

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

typedef InitContextC = Int32 Function();
typedef InitContextDart = int Function();

typedef GetDeviceCountC = Int32 Function();
typedef GetDeviceCountDart = int Function();

typedef GetDeviceInfoC =
    Void Function(Int32 index, Pointer<SonicDeviceInfo> info);
typedef GetDeviceInfoDart =
    void Function(int index, Pointer<SonicDeviceInfo> info);

typedef RecorderStartC =
    Int32 Function(Int32 deviceIndex, Int32 sampleRate, Int32 channels, Int32 bitDepth);
typedef RecorderStartDart =
    int Function(int deviceIndex, int sampleRate, int channels, int bitDepth);

typedef RecorderStopC = Int32 Function();
typedef RecorderStopDart = int Function();

typedef RecorderReadC =
    Int32 Function(Pointer<Int16> pOutput, Int32 frameCount);
typedef RecorderReadDart = int Function(Pointer<Int16> pOutput, int frameCount);

typedef RecorderReadS32C =
    Int32 Function(Pointer<Int32> pOutput, Int32 frameCount);
typedef RecorderReadS32Dart = int Function(Pointer<Int32> pOutput, int frameCount);

class SonicRecorder {
  static const String _libName = 'sonic_recorder';
  late final DynamicLibrary _dylib;
  late final InitContextDart _initContext;
  late final GetDeviceCountDart _getDeviceCount;
  late final GetDeviceInfoDart _getDeviceInfo;
  late final RecorderStartDart _start;
  late final RecorderStopDart _stop;
  late final RecorderReadDart _read;
  late final RecorderReadS32Dart _readS32;

  SonicRecorder() {
    if (Platform.isLinux) {
      _dylib = DynamicLibrary.open('lib$_libName.so');
    } else if (Platform.isWindows) {
      _dylib = DynamicLibrary.open('$_libName.dll');
    } else {
      throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
    }

    _initContext = _dylib.lookupFunction<InitContextC, InitContextDart>(
      'sonic_recorder_init_context',
    );
    _getDeviceCount = _dylib
        .lookupFunction<GetDeviceCountC, GetDeviceCountDart>(
          'sonic_recorder_get_device_count',
        );
    _getDeviceInfo = _dylib.lookupFunction<GetDeviceInfoC, GetDeviceInfoDart>(
      'sonic_recorder_get_device_info',
    );
    _start = _dylib.lookupFunction<RecorderStartC, RecorderStartDart>(
      'sonic_recorder_start',
    );
    _stop = _dylib.lookupFunction<RecorderStopC, RecorderStopDart>(
      'sonic_recorder_stop',
    );
    _read = _dylib.lookupFunction<RecorderReadC, RecorderReadDart>(
      'sonic_recorder_read',
    );
    _readS32 = _dylib.lookupFunction<RecorderReadS32C, RecorderReadS32Dart>(
       'sonic_recorder_read_s32',
    );
  }

  int start(int deviceIndex, int sampleRate, int channels, int bitDepth) =>
      _start(deviceIndex, sampleRate, channels, bitDepth);
  int stop() => _stop();
  int read(Pointer<Int16> buffer, int frameCount) => _read(buffer, frameCount);
  int readS32(Pointer<Int32> buffer, int frameCount) => _readS32(buffer, frameCount);

  int init() {
    return _initContext();
  }

  List<AudioDevice> getDevices() {
    final count = _getDeviceCount();
    if (count <= 0) return [];

    final devices = <AudioDevice>[];

    final infoPointer = calloc<SonicDeviceInfo>();

    try {
      for (var i = 0; i < count; i++) {
        _getDeviceInfo(i, infoPointer);

        Pointer<Utf8> namePtr = Pointer.fromAddress(
          infoPointer.address,
        ).cast<Utf8>();
        String deviceName = namePtr.toDartString();

        final backendId = infoPointer.ref.backend;
        String backendName = "Unknown";
        if (backendId == 1) {
          backendName = 'ALSA';
        } else if (backendId == 2) {
          backendName = 'PulseAudio';
        } else if (backendId == 3) {
          backendName = 'WASAPI';
        } else {
          backendName = 'Unknown ($backendId)';
        }

        devices.add(
          AudioDevice(
            name: deviceName,
            isDefault: infoPointer.ref.isDefault != 0,
            backend: backendName,
            id: "$backendName:$i",
          ),
        );
      }
    } finally {
      calloc.free(infoPointer);
    }

    return devices;
  }
}

class AudioDevice {
  final String name;
  final bool isDefault;
  final String backend;
  final String id;

  AudioDevice({
    required this.name,
    required this.isDefault,
    required this.backend,
    required this.id,
  });

  @override
  String toString() => "$name [$backend] ${isDefault ? '(Default)' : ''}";
}
