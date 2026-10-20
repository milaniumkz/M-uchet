import 'company_access.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';

class DocumentFiles extends StatefulWidget {
  const DocumentFiles(
      {super.key, required this.repository, required this.documentId});
  final CommercialRepository repository;
  final String documentId;
  @override
  State<DocumentFiles> createState() => _DocumentFilesState();
}

class _DocumentFilesState extends State<DocumentFiles> {
  List<Map<String, dynamic>> files = [];
  bool busy = true;
  String? error;
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result =
          await widget.repository.related(widget.documentId, 'files');
      if (mounted) {
        setState(() => files = result);
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> upload() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null) {
        return;
      }
      final file = result.files.single;
      if (file.bytes == null) {
        throw const BackendException('file_read_failed');
      }
      if (mounted) {
        setState(() {
          busy = true;
          error = null;
        });
      }
      final saved = await widget.repository.api
          .uploadFile(widget.repository.companyId, file.bytes!, file.name);
      pending = widget.repository
          .action(widget.documentId, 'files', {'fileId': saved['id']});
      await attach();
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Не удалось выбрать или загрузить файл.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> attach() async {
    if (mounted) {
      setState(() => busy = true);
    }
    try {
      await pending!.execute(widget.repository.api);
      pending = null;
      await load();
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error =
            '${e.message} Повторите прикрепление уже загруженного файла.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> download(Map<String, dynamic> file) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final bytes = await widget.repository.api
          .downloadFile(widget.repository.companyId, file['id'] as String);
      await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить вложение',
          fileName: file['name'] as String,
          bytes: Uint8List.fromList(bytes));
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Не удалось сохранить файл.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        Wrap(spacing: 16, children: [
          FilledButton.icon(
              onPressed: busy || pending != null || !hasCompanyPermission(context,'files.write') || !hasCompanyPermission(context,'documents.write') ? null : upload,
              icon: const Icon(Icons.attach_file),
              label: const Text('Прикрепить файл')),
          if (pending != null)
            TextButton(
                onPressed: busy ? null : attach,
                child: const Text('Повторить прикрепление'))
        ]),
        const SizedBox(height: 20),
        ...files.map((file) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(file['name'] as String),
            subtitle: Text('${file['size']} байт'),
            trailing: IconButton(
                tooltip: 'Скачать вложение',
                onPressed: busy ? null : () => download(file),
                icon: const Icon(Icons.download_outlined)))),
        if (files.isEmpty && !busy) const Text('Вложений пока нет.')
      ]);
}
