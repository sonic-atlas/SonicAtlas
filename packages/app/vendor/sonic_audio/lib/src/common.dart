class AudioDevice {
  final String name;
  final bool isDefault;
  final String backend;
  final int index;

  const AudioDevice({
    required this.name,
    required this.isDefault,
    required this.backend,
    required this.index,
  });

  @override
  String toString() => '$name [$backend]${isDefault ? ' (Default)' : ''}';
}
