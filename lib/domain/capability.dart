/// Provider capability states. `unknown` is the default until verified.
enum CapabilityState { unknown, unsupported, readOnly, writeOnly, readWrite }

extension CapabilityStateX on CapabilityState {
  bool get isReadable =>
      this == CapabilityState.readOnly || this == CapabilityState.readWrite;
  bool get isWritable =>
      this == CapabilityState.writeOnly || this == CapabilityState.readWrite;
  bool get isKnown => this != CapabilityState.unknown;
}

/// Resources whose capabilities are tracked independently.
enum CapabilityResource {
  books,
  downloads,
  progress,
  status,
  shelves,
  bookmarks,
  annotations,
}

/// Per-resource capability matrix for a provider instance.
class CapabilityMatrix {
  const CapabilityMatrix(this.states);

  final Map<CapabilityResource, CapabilityState> states;

  CapabilityState stateOf(CapabilityResource resource) =>
      states[resource] ?? CapabilityState.unknown;

  bool canRead(CapabilityResource resource) => stateOf(resource).isReadable;
  bool canWrite(CapabilityResource resource) => stateOf(resource).isWritable;

  CapabilityMatrix copyWith(CapabilityResource resource, CapabilityState state) {
    final next = Map<CapabilityResource, CapabilityState>.from(states);
    next[resource] = state;
    return CapabilityMatrix(next);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'states': states.map((k, v) => MapEntry(k.name, v.name)),
      };

  factory CapabilityMatrix.fromJson(Map<String, dynamic> json) {
    final raw = json['states'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final states = <CapabilityResource, CapabilityState>{};
    for (final entry in raw.entries) {
      final resource = CapabilityResource.values
          .firstWhere((r) => r.name == entry.key, orElse: () => CapabilityResource.books);
      final state = CapabilityState.values
          .firstWhere((s) => s.name == entry.value, orElse: () => CapabilityState.unknown);
      states[resource] = state;
    }
    return CapabilityMatrix(states);
  }

  /// Default matrix: everything unknown.
  static CapabilityMatrix allUnknown() => CapabilityMatrix(
        {for (final r in CapabilityResource.values) r: CapabilityState.unknown},
      );

  @override
  bool operator ==(Object other) =>
      other is CapabilityMatrix &&
      other.states.length == states.length &&
      states.entries.every((e) => other.states[e.key] == e.value);

  @override
  int get hashCode => Object.hashAll(states.entries);
}
