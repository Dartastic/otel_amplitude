// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_amplitude_suppression.dart';

const _loggerName = 'package.amplitude';

/// Bridges Amplitude analytics events (logEvent, setUserId,
/// identify with user properties) into OpenTelemetry log records.
class OTelAmplitude {
  OTelAmplitude({
    LoggerProvider? loggerProvider,
    this.forwardLogEvent,
    this.forwardSetUserId,
  }) : _loggerProvider = loggerProvider;

  final LoggerProvider? _loggerProvider;

  final void Function(String type, Map<String, Object?>? properties)?
      forwardLogEvent;
  final void Function(String userId)? forwardSetUserId;

  OTelLogger _logger() =>
      (_loggerProvider ?? OTel.loggerProvider()).getLogger(_loggerName);

  void logEvent(String eventType, {Map<String, Object?>? eventProperties}) {
    forwardLogEvent?.call(eventType, eventProperties);
    if (amplitudeInstrumentationSuppressed()) return;
    _emit(
      body: 'amplitude.log_event $eventType',
      eventType: 'log_event',
      attrs: [OTel.attributeString('amplitude.event.type', eventType)],
      flatPrefix: 'amplitude.event_property.',
      payload: eventProperties,
    );
  }

  void setUserId(String userId) {
    forwardSetUserId?.call(userId);
    if (amplitudeInstrumentationSuppressed()) return;
    _emit(
      body: 'amplitude.set_user_id $userId',
      eventType: 'set_user_id',
      attrs: [
        OTel.attributeString('amplitude.user.id', userId),
        OTel.attributeString(User.userId.key, userId),
      ],
    );
  }

  void _emit({
    required String body,
    required String eventType,
    required List<Attribute<Object>> attrs,
    String? flatPrefix,
    Map<String, Object?>? payload,
  }) {
    final all = <Attribute<Object>>[
      OTel.attributeString('amplitude.event_type', eventType),
      ...attrs,
    ];
    if (payload != null && flatPrefix != null) {
      payload.forEach((k, v) {
        if (v == null) return;
        final key = '$flatPrefix$k';
        if (v is String) {
          all.add(OTel.attributeString(key, v));
        } else if (v is int) {
          all.add(OTel.attributeInt(key, v));
        } else if (v is double) {
          all.add(OTel.attributeDouble(key, v));
        } else if (v is bool) {
          all.add(OTel.attributeBool(key, v));
        } else {
          all.add(OTel.attributeString(key, v.toString()));
        }
      });
    }
    _logger().emit(
      severityNumber: Severity.INFO,
      severityText: 'info',
      body: body,
      attributes: OTel.attributes(all),
    );
  }
}
