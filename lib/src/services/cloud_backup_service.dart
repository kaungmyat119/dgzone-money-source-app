import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/local_database.dart';
import 'data_transfer_service.dart';

class CloudBackupInfo {
  const CloudBackupInfo({required this.id, required this.name, required this.createdAt});
  final String id;
  final String name;
  final DateTime? createdAt;
}

class CloudBackupService {
  CloudBackupService._();
  static final instance = CloudBackupService._();

  static const _scope = drive.DriveApi.driveAppdataScope;
  static const _prefix = 'DGzone_Money_Cloud_';
  final GoogleSignIn _signIn = GoogleSignIn(scopes: const [_scope, 'email']);
  final DataTransferService _transfer = const DataTransferService();
  Future<void>? _activeUpload;

  GoogleSignInAccount? get account => _signIn.currentUser;

  Future<GoogleSignInAccount?> connect() => _signIn.signIn();
  Future<GoogleSignInAccount?> connectSilently() => _signIn.signInSilently();
  Future<void> disconnect() => _signIn.disconnect();

  Future<drive.DriveApi> _api({bool interactive = true}) async {
    final user = _signIn.currentUser ??
        await _signIn.signInSilently() ??
        (interactive ? await _signIn.signIn() : null);
    if (user == null) throw StateError('Google account is not connected');
    final headers = await user.authHeaders;
    return drive.DriveApi(_GoogleAuthClient(headers));
  }

  Future<CloudBackupInfo> upload(LocalDatabase database, {bool interactive = true}) async {
    final completer = Completer<void>();
    final previous = _activeUpload;
    _activeUpload = completer.future;
    if (previous != null) await previous;
    try {
      final api = await _api(interactive: interactive);
      final temp = await getTemporaryDirectory();
      final local = await _transfer.createBackup(database, destination: temp);
      final now = DateTime.now().toUtc();
      final name = '$_prefix${now.toIso8601String().replaceAll(':', '-')}.dgzbackup';
      final metadata = drive.File()
        ..name = name
        ..parents = const ['appDataFolder']
        ..appProperties = {'format': 'dgzone-money-backup', 'version': '2'};
      final created = await api.files.create(
        metadata,
        uploadMedia: drive.Media(local.openRead(), await local.length()),
        $fields: 'id,name,createdTime',
      );
      await database.saveSetting('last_cloud_backup_at', now.toIso8601String());
      await database.saveSetting('cloud_account_email', account?.email ?? '');
      await _prune(api);
      try { await local.delete(); } catch (_) {}
      return CloudBackupInfo(
        id: created.id!,
        name: created.name ?? name,
        createdAt: created.createdTime,
      );
    } finally {
      completer.complete();
      if (identical(_activeUpload, completer.future)) _activeUpload = null;
    }
  }

  Future<List<CloudBackupInfo>> list({bool interactive = true}) async {
    final api = await _api(interactive: interactive);
    final result = await api.files.list(
      spaces: 'appDataFolder',
      q: "name contains '$_prefix' and trashed = false",
      orderBy: 'createdTime desc',
      pageSize: 10,
      $fields: 'files(id,name,createdTime)',
    );
    return (result.files ?? const [])
        .where((file) => file.id != null)
        .map((file) => CloudBackupInfo(
              id: file.id!, name: file.name ?? 'DGzone Money Backup',
              createdAt: file.createdTime,
            ))
        .toList();
  }

  Future<void> restoreLatest(LocalDatabase database) async {
    final api = await _api();
    final backups = await list();
    if (backups.isEmpty) throw StateError('No cloud backup found');
    final media = await api.files.get(backups.first.id, downloadOptions: drive.DownloadOptions.fullMedia);
    if (media is! drive.Media) throw StateError('Unable to download cloud backup');
    final temp = await getTemporaryDirectory();
    final file = File('${temp.path}/${backups.first.name}');
    final sink = file.openWrite();
    await media.stream.pipe(sink);
    await _transfer.restoreBackup(database, file.path);
    await database.saveSetting('cloud_sync', 'true');
    await database.saveSetting('cloud_account_email', account?.email ?? '');
    await database.saveSetting('last_cloud_restore_at', DateTime.now().toUtc().toIso8601String());
    try { await file.delete(); } catch (_) {}
  }

  Future<void> syncIfEnabled(LocalDatabase database) async {
    if (await database.readSetting('cloud_sync') != 'true') return;
    try {
      await upload(database, interactive: false);
    } catch (error) {
      debugPrint('DGZ cloud: sync upload failed: $error');
    }
  }

  Future<void> runAutomaticBackupIfDue(LocalDatabase database) async {
    if (await database.readSetting('auto_backup') != 'true') return;
    final last = DateTime.tryParse(await database.readSetting('last_cloud_backup_at') ?? '');
    if (last != null && DateTime.now().toUtc().difference(last).inHours < 24) return;
    try {
      await upload(database, interactive: false);
    } catch (error) {
      debugPrint('DGZ cloud: automatic backup failed: $error');
    }
  }

  Future<void> _prune(drive.DriveApi api) async {
    final backups = await list(interactive: false);
    for (final old in backups.skip(5)) {
      await api.files.delete(old.id);
    }
  }
}

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this.headers);
  final Map<String, String> headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
