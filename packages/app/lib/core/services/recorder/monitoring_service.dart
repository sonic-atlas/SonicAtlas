import 'package:sonic_audio/sonic_audio.dart';

class MonitoringService {
  final SonicRecorder _recorder;
  bool _isMonitoring = false;

  bool get isMonitoring => _isMonitoring;

  MonitoringService(this._recorder);

  Future<void> start() async {
    if (_isMonitoring) return;
    _recorder.setMonitor(true);
    _isMonitoring = true;
  }

  void stop() {
    if (!_isMonitoring) return;
    _recorder.setMonitor(false);
    _isMonitoring = false;
  }
}
