// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mixpanel_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MixpanelResponse<T> _$MixpanelResponseFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => $checkedCreate('MixpanelResponse', json, ($checkedConvert) {
  final val = MixpanelResponse<T>(
    data: $checkedConvert('data', (v) => fromJsonT(v)),
  );
  return val;
});

MixpanelSegmentationData _$MixpanelSegmentationDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MixpanelSegmentationData', json, ($checkedConvert) {
  final val = MixpanelSegmentationData(
    series: $checkedConvert(
      'series',
      (v) => (v as List<dynamic>).map((e) => e as String).toList(),
    ),
    values: $checkedConvert(
      'values',
      (v) => (v as Map<String, dynamic>).map(
        (k, e) => MapEntry(
          k,
          (e as List<dynamic>).map((e) => (e as num).toInt()).toList(),
        ),
      ),
    ),
  );
  return val;
});
