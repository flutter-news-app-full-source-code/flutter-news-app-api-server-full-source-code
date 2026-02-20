import 'package:json_annotation/json_annotation.dart';

/// A [JsonConverter] for handling [DateTime] objects.
class DateTimeConverter implements JsonConverter<DateTime, String> {
  /// {@macro date_time_converter}
  const DateTimeConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json);

  @override
  String toJson(DateTime object) => object.toIso8601String();
}

/// A [JsonConverter] for handling nullable [DateTime] objects.
class NullableDateTimeConverter implements JsonConverter<DateTime?, String?> {
  /// {@macro nullable_date_time_converter}
  const NullableDateTimeConverter();

  @override
  DateTime? fromJson(String? json) =>
      json == null ? null : DateTime.parse(json);

  @override
  String? toJson(DateTime? object) => object?.toIso8601String();
}
