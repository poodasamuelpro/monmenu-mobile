// lib/services/payment_upload_service.dart
// Service d'upload de preuve de paiement
// SEC-02: token jamais loggé — SEC-10: fichiers en répertoire privé uniquement
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';

/// Résultat d'une opération de sélection / compression d'image.
class ImagePickResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int? fileSizeBytes;

  const ImagePickResult._({
    required this.success,
    this.filePath,
    this.error,
    this.fileSizeBytes,
  });

  factory ImagePickResult.ok(String path, int size) =>
      ImagePickResult._(success: true, filePath: path, fileSizeBytes: size);

  factory ImagePickResult.err(String msg) =>
      ImagePickResult._(success: false, error: msg);
}

/// Résultat d'un upload de preuve.
class UploadResult {
  final bool success;
  final String? abonnementId;
  final String? reference;
  final String? error;
  final Map<String, dynamic>? rawResponse;

  const UploadResult._({
    required this.success,
    this.abonnementId,
    this.reference,
    this.error,
    this.rawResponse,
  });

  factory UploadResult.ok(Map<String, dynamic> data) => UploadResult._(
    success: true,
    abonnementId: data['abonnement_id'] as String?,
    reference: data['reference'] as String?,
    rawResponse: data,
  );

  factory UploadResult.err(String msg) =>
      UploadResult._(success: false, error: msg);
}

/// Données d'un upload en attente de reprise (stocké localement).
class PendingUpload {
  final String filePath;
  final String planId;
  final String methodePaiement;
  final String periodicite;
  final String numeroExpediteur;
  final DateTime savedAt;

  const PendingUpload({
    required this.filePath,
    required this.planId,
    required this.methodePaiement,
    required this.periodicite,
    required this.numeroExpediteur,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'file_path': filePath,
    'plan_id': planId,
    'methode_paiement': methodePaiement,
    'periodicite': periodicite,
    'numero_expediteur': numeroExpediteur,
    'saved_at': savedAt.toIso8601String(),
  };

  factory PendingUpload.fromJson(Map<String, dynamic> json) => PendingUpload(
    filePath: json['file_path'] as String,
    planId: json['plan_id'] as String,
    methodePaiement: json['methode_paiement'] as String,
    periodicite: json['periodicite'] as String,
    numeroExpediteur: json['numero_expediteur'] as String? ?? '',
    savedAt: DateTime.tryParse(json['saved_at'] as String) ?? DateTime.now(),
  );
}

/// Service gérant la sélection, compression, validation et upload de preuves.
///
/// Règles de sécurité appliquées :
/// - SEC-02 : aucun log du token Bearer
/// - SEC-10 : fichiers stockés dans le répertoire privé de l'application uniquement
/// - Compression 80% qualité, max 800×600 px
/// - Validation taille < 5 Mo côté client (la validation serveur reste la référence)
/// - Retry avec re-vérification du statut serveur avant renvoi
class PaymentUploadService {
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5 Mo
  static const int _compressQuality = 80;
  static const int _maxWidth = 800;
  static const int _maxHeight = 600;
  static const String _pendingFileName = 'pending_payment_upload.json';

  final ImagePicker _picker;
  final ApiService _api;

  PaymentUploadService({ImagePicker? picker, required ApiService api})
      : _picker = picker ?? ImagePicker(),
        _api = api;

  // ── Sélection + compression d'image ───────────────────────────────────────

  /// Ouvre la galerie ou la caméra, compresse et valide l'image.
  Future<ImagePickResult> pickAndCompressImage({
    required ImageSource source,
  }) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: _compressQuality,
        maxWidth: _maxWidth.toDouble(),
        maxHeight: _maxHeight.toDouble(),
      );

      if (picked == null) {
        return ImagePickResult.err('Sélection annulée.');
      }

      // Répertoire privé de l'app — SEC-10
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destPath = '${appDir.path}/payment_proof_$timestamp.jpg';

      // Compression supplémentaire via flutter_image_compress
      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        destPath,
        quality: _compressQuality,
        minWidth: 1,
        minHeight: 1,
        keepExif: false,
      );

      final finalPath = compressed?.path ?? destPath;

      // Copie si compression a échoué mais image disponible
      if (compressed == null) {
        await File(picked.path).copy(destPath);
      }

      // Validation taille < 5 Mo (côté client — ne remplace pas la validation serveur)
      final fileSize = await File(finalPath).length();
      if (fileSize > _maxFileSizeBytes) {
        await _safeDelete(finalPath);
        return ImagePickResult.err(
            'Image trop volumineuse (${(fileSize / 1024 / 1024).toStringAsFixed(1)} Mo). '
            'Maximum 5 Mo.');
      }

      return ImagePickResult.ok(finalPath, fileSize);
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('[PaymentUpload] pickAndCompress error: $e');
      return ImagePickResult.err('Erreur lors de la sélection de l\'image.');
    }
  }

  // ── Upload avec retry ──────────────────────────────────────────────────────

  /// Upload la preuve et gère la sauvegarde locale pour reprise en cas de coupure.
  ///
  /// SEC-07 : avant tout renvoi depuis le cache local, on re-vérifie le statut
  /// serveur pour éviter de soumettre une preuve déjà confirmée/rejetée.
  Future<UploadResult> uploadPreuve({
    required String filePath,
    required String planId,
    required String methodePaiement,
    required String periodicite,
    required String numeroExpediteur,
  }) async {
    // Vérifier que le fichier existe
    if (!File(filePath).existsSync()) {
      return UploadResult.err('Fichier preuve introuvable.');
    }

    // Tentative d'upload
    final result = await _attemptUpload(
      filePath: filePath,
      planId: planId,
      methodePaiement: methodePaiement,
      periodicite: periodicite,
      numeroExpediteur: numeroExpediteur,
    );

    if (result.success) {
      // Purge du fichier local après succès — SEC-10
      await _safeDelete(filePath);
      await _clearPendingUpload();
      return result;
    }

    // En cas d'échec réseau (code 0), sauvegarder pour reprise
    if (result.error != null &&
        (result.error!.contains('connexion') ||
            result.error!.contains('Délai') ||
            result.error!.contains('réseau'))) {
      await _savePendingUpload(PendingUpload(
        filePath: filePath,
        planId: planId,
        methodePaiement: methodePaiement,
        periodicite: periodicite,
        numeroExpediteur: numeroExpediteur,
        savedAt: DateTime.now(),
      ));
      return UploadResult.err(
          'Pas de connexion. La preuve sera envoyée automatiquement '
          'à la prochaine ouverture de l\'application.');
    }

    return result;
  }

  Future<UploadResult> _attemptUpload({
    required String filePath,
    required String planId,
    required String methodePaiement,
    required String periodicite,
    required String numeroExpediteur,
  }) async {
    final resp = await _api.soumettrePreuvePaiement(
      filePath: filePath,
      planId: planId,
      methodePaiement: methodePaiement,
      periodicite: periodicite,
      numeroExpediteur: numeroExpediteur,
    );

    if (resp.success && resp.data != null) {
      return UploadResult.ok(resp.data!);
    }
    return UploadResult.err(resp.error ?? 'Erreur lors de l\'upload.');
  }

  // ── Reprise d'upload au prochain lancement ─────────────────────────────────

  /// Vérifie s'il existe un upload en attente et le reprend si le statut
  /// serveur l'autorise.
  ///
  /// SEC-07 : re-vérification du statut avant renvoi automatique.
  Future<UploadResult?> retryPendingUploadIfNeeded() async {
    final pending = await _loadPendingUpload();
    if (pending == null) return null;

    // Vérifier que le fichier existe encore
    if (!File(pending.filePath).existsSync()) {
      await _clearPendingUpload();
      return null;
    }

    // SEC-07 : re-vérifier le statut actuel du serveur avant renvoi
    final statutResp = await _api.getAbonnementActif();
    if (statutResp.success && statutResp.data != null) {
      final statutTenant = statutResp.data!['statut_tenant'] as String?;
      // Si déjà en attente de confirmation ou actif, ne pas renvoyer
      if (statutTenant == 'en_attente_confirmation' ||
          statutTenant == 'actif') {
        await _clearPendingUpload();
        await _safeDelete(pending.filePath);
        if (kDebugMode) {
          debugPrint(
              '[PaymentUpload] Statut déjà $statutTenant — annulation du retry');
        }
        return null;
      }
    }

    // Retenter l'upload
    return uploadPreuve(
      filePath: pending.filePath,
      planId: pending.planId,
      methodePaiement: pending.methodePaiement,
      periodicite: pending.periodicite,
      numeroExpediteur: pending.numeroExpediteur,
    );
  }

  // ── Persistence locale (répertoire privé) ─────────────────────────────────

  Future<void> _savePendingUpload(PendingUpload upload) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$_pendingFileName');
      await file.writeAsString(jsonEncode(upload.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('[PaymentUpload] save pending error: $e');
    }
  }

  Future<PendingUpload?> _loadPendingUpload() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$_pendingFileName');
      if (!file.existsSync()) return null;
      final content = await file.readAsString();
      return PendingUpload.fromJson(
          jsonDecode(content) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('[PaymentUpload] load pending error: $e');
      return null;
    }
  }

  Future<void> _clearPendingUpload() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$_pendingFileName');
      if (file.existsSync()) await file.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[PaymentUpload] clear pending error: $e');
    }
  }

  Future<bool> hasPendingUpload() async {
    final pending = await _loadPendingUpload();
    if (pending == null) return false;
    return File(pending.filePath).existsSync();
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  /// Purge tous les fichiers de preuves locaux (après upload réussi ou session expirée).
  Future<void> purgeLocalProofs() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final files = appDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('payment_proof_'));
      for (final f in files) {
        await _safeDelete(f.path);
      }
      await _clearPendingUpload();
    } catch (e) {
      if (kDebugMode) debugPrint('[PaymentUpload] purge error: $e');
    }
  }
}
