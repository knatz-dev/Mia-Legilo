/// Source of a metadata field value.
enum MetadataProvenance { standard, providerCustom, local }

/// A value paired with its provenance.
class ProvenancedValue<T> {
  const ProvenancedValue({required this.value, required this.provenance});

  final T value;
  final MetadataProvenance provenance;

  Map<String, dynamic> toJson(Object? Function(T) encode) =>
      <String, dynamic>{'value': encode(value), 'provenance': provenance.name};

  static ProvenancedValue<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Object?) decode,
  ) =>
      ProvenancedValue<T>(
        value: decode(json['value']),
        provenance: MetadataProvenance.values.firstWhere(
          (p) => p.name == json['provenance'],
          orElse: () => MetadataProvenance.standard,
        ),
      );
}
