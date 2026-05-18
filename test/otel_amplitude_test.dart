// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_amplitude/otel_amplitude.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemoryLogExporter logs;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_amplitude-test',
    );
    logs = harness.logs;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(LogRecord r) {
    final list = r.attributes?.toList() ?? <Attribute<Object>>[];
    return {for (final a in list) a.key: a.value};
  }

  test('logEvent records event_type + properties', () async {
    OTelAmplitude().logEvent(
      'Purchase Completed',
      eventProperties: {'order.total': 19.99},
    );
    await harness.flushLogs();
    final r = logs.records.firstWhere(
      (r) => r.body == 'amplitude.log_event Purchase Completed',
    );
    final a = attrsOf(r);
    expect(a['amplitude.event_type'], 'log_event');
    expect(a['amplitude.event.type'], 'Purchase Completed');
    expect(a['amplitude.event_property.order.total'], 19.99);
  });

  test('setUserId records user.id', () async {
    OTelAmplitude().setUserId('u-1');
    await harness.flushLogs();
    final r = logs.records.firstWhere(
      (r) => r.body == 'amplitude.set_user_id u-1',
    );
    final a = attrsOf(r);
    expect(a['amplitude.user.id'], 'u-1');
    expect(a['user.id'], 'u-1');
  });

  test('suppression skips emit but forwards', () async {
    var forwarded = 0;
    await runWithoutAmplitudeInstrumentationAsync(() async {
      OTelAmplitude(forwardLogEvent: (_, __) => forwarded++).logEvent('x');
    });
    await harness.flushLogs();
    expect(forwarded, 1);
    expect(
      logs.records.where((r) => r.body == 'amplitude.log_event x'),
      isEmpty,
    );
  });
}
