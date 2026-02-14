// lib/src/services/storage/i_storage_service.dart
/// {@template i_storage_service}
/// An abstract interface for a cloud storage service.
///
/// This contract defines the essential operations for managing file uploads,
/// such as generating signed URLs for direct client uploads.
/// {@endtemplate}
abstract class IStorageService {
  /// Generates a short-lived, signed URL that grants a client temporary
  /// permission to upload a file directly to a specific path in cloud storage.
  ///
  /// - [storagePath]: The full, unique path in the storage bucket where the
  ///   file will be stored (e.g., 'user-media/user-id/uuid.jpg').
  /// - [contentType]: The MIME type of the file to be uploaded (e.g., 'image/jpeg').
  ///
  /// Returns a [Future] that completes with the signed URL string.
  Future<String> generateUploadUrl({
    required String storagePath,
    required String contentType,
  });

  /// Deletes an object from the cloud storage bucket.
  ///
  /// - [storagePath]: The full path to the object to be deleted.
  ///
  /// Returns a [Future] that completes when the deletion is successful.
  Future<void> deleteObject({required String storagePath});
}
