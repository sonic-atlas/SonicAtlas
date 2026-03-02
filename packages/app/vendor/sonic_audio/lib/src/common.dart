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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioDevice &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          backend == other.backend &&
          index == other.index;

  @override
  int get hashCode => name.hashCode ^ backend.hashCode ^ index.hashCode;

  @override
  String toString() => '$name [$backend]${isDefault ? ' (Default)' : ''}';
}
