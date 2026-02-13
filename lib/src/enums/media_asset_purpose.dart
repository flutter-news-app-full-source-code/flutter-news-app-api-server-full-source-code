// lib/src/enums/media_asset_purpose.dart
import 'package:json_annotation/json_annotation.dart';

/// {@template media_asset_purpose}
/// Defines the intended use of a media asset.
///
/// This is used to apply different logic or validation based on where the
/// media will be used (e.g., a user's profile picture vs. a headline image).
/// {@endtemplate}
@JsonEnum()
enum MediaAssetPurpose {
  /// The media is intended for use as a user's profile photo.
  userProfilePhoto,

  /// The media is intended for use as a headline's main image.
  headlineImage,
}
