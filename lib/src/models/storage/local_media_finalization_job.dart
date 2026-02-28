import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/utils/converters/date_time_converter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'local_media_finalization_job.g.dart';

/// {@template local_media_finalization_job}
/// Represents a job to finalize a media asset uploaded via the local storage
/// provider.
///
/// This record is created by the `upload-local` endpoint and processed by a
/// background worker to achieve asynchronous finalization, mirroring the
/// webhook-based flow of cloud providers.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class LocalMediaFinalizationJob extends Equatable {
  /// {@macro local_media_finalization_job}
  const LocalMediaFinalizationJob({
    required this.id,
    required this.mediaAssetId,
    required this.publicUrl,
    required this.createdAt,
  });

  /// Creates a [LocalMediaFinalizationJob] from JSON data.
  factory LocalMediaFinalizationJob.fromJson(Map<String, dynamic> json) =>
      _$LocalMediaFinalizationJobFromJson(json);

  /// The unique identifier for this job.
  final String id;

  /// The ID of the [MediaAsset] to be finalized.
  final String mediaAssetId;

  /// The public URL that the media asset will have upon finalization.
  final String publicUrl;

  /// The timestamp when this job was created.
  /// This is used by MongoDB's TTL index to clean up stale jobs.
  @DateTimeConverter()
  final DateTime createdAt;

  /// Converts this [LocalMediaFinalizationJob] instance to JSON data.
  Map<String, dynamic> toJson() => _$LocalMediaFinalizationJobToJson(this);

  @override
  List<Object> get props => [id, mediaAssetId, publicUrl, createdAt];
}
