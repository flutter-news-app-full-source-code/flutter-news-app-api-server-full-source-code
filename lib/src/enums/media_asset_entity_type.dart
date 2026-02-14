// lib/src/enums/media_asset_entity_type.dart
import 'package:core/core.dart' show Headline, Source, Topic;
import 'package:flutter_news_app_api_server_full_source_code/src/models/media_asset.dart'
    show MediaAsset;
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart'
    show MediaAsset;
import 'package:json_annotation/json_annotation.dart';

/// {@template media_asset_entity_type}
/// Defines the type of entity a media asset can be associated with.
///
/// This is used to create a polymorphic relationship between a [MediaAsset]
/// and other models like [Headline], [Topic], or [Source].
/// {@endtemplate}
@JsonEnum()
enum MediaAssetEntityType {
  /// The asset is associated with a [Headline].
  headline,

  /// The asset is associated with a [Topic].
  topic,

  /// The asset is associated with a [Source].
  source,
}
