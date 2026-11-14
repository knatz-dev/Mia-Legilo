import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/reader_engines/reader_engine.dart';

void main() {
  test('BridgeMessage round trip', () {
    const msg = BridgeMessage(type: 'location', payload: <String, dynamic>{'cfi': '/6/4', 'percentage': 0.5});
    final decoded = BridgeMessage.fromJson(msg.toJson());
    expect(decoded.type, 'location');
    expect(decoded.payload?['cfi'], '/6/4');
  });
}
