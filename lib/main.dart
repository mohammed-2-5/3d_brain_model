// main.dart  📱  Flutter ↔ FastAPI
// يدعم:
//   • /predict       ← شرائح PNG
//   • /plot_preview  ← صورة معاينة (4 لوحات)
//   • /tumor_mesh    ← GLB شبكة الورم
//   • /brain_mesh    ← GLB دماغ كامل (جديد)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

void main() => runApp(const BrainSegApp());

/*────────────────── 1) تطبيق Flutter ──────────────────*/
class BrainSegApp extends StatelessWidget {
  const BrainSegApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Brain-Seg Demo',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
    debugShowCheckedModeBanner: false,
    home: const HomePage(),
  );
}

/*────────────────── 2) حالة الشاشة ──────────────────*/
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /*━━━━━━━━ 2-A) أداة مساعدة لتحويل PlatformFile → MultipartFile ━━━━━━━━*/
  http.MultipartFile _multipart({
    required String field,
    required PlatformFile pf,
  }) {
    if (pf.bytes != null) {
      return http.MultipartFile.fromBytes(field, pf.bytes!, filename: pf.name);
    }
    final bytes = File(pf.path!).readAsBytesSync();
    return http.MultipartFile.fromBytes(field, bytes, filename: pf.name);
  }

  /*━━━━━━━━ 2-B) الملفات المُختارة ━━━━━━━━*/
  PlatformFile? flairFile, t1ceFile, segFile;

  /*━━━━━━━━ 2-C) مخرجات / حالة ━━━━━━━━*/
  bool loading = false;
  final List<_Slice> slices = [];
  File? previewImg;
  File? tumorMeshFile;
  File? brainMeshFile;

  /*━━━━━━━━ 2-D) اختيار ملف ━━━━━━━━*/
  Future<void> _pickFile(String role) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (res == null || res.files.single.path == null) return;

    final f = res.files.single;
    final ok = f.path!.toLowerCase().endsWith('.nii') ||
        f.path!.toLowerCase().endsWith('.nii.gz');
    if (!ok) return _showErr('Only .nii or .nii.gz files are allowed');

    setState(() {
      switch (role) {
        case 'flair':
          flairFile = f;
          break;
        case 't1ce':
          t1ceFile = f;
          break;
        case 'seg':
          segFile = f;
          break;
      }
    });
  }

  /*━━━━━━━━ 2-E) إعداد HTTP ━━━━━━━━*/
  static final _http = IOClient(HttpClient()
    ..connectionTimeout = const Duration(minutes: 5)
    ..idleTimeout = const Duration(minutes: 5)
    ..maxConnectionsPerHost = 5);

  String get _base =>
      Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';

  /*──────────────── 2-F) /predict ─────────────────*/
  Future<void> _callPredict() async {
    if (flairFile == null || t1ceFile == null) return;

    setState(() {
      loading = true;
      slices.clear();
    });

    final req = http.MultipartRequest('POST', Uri.parse('$_base/predict'))
      ..files.add(_multipart(field: 'nifti_flair', pf: flairFile!))
      ..files.add(_multipart(field: 'nifti_t1ce', pf: t1ceFile!));

    try {
      final resp =
      await http.Response.fromStream(await _http.send(req).timeout(const Duration(minutes: 5)));
      debugPrint('[predict] status=${resp.statusCode}');
      if (resp.statusCode != 200) throw resp.body;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final docs = await getApplicationDocumentsDirectory();
      final runDir = Directory('${docs.path}/${data['run_id']}')..createSync();

      for (final m in data['slices']) {
        final bts = (await _http.get(Uri.parse('$_base${m['url']}'))).bodyBytes;
        final safe = (m['filename'] as String).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final file = File('${runDir.path}/$safe')..writeAsBytesSync(bts);
        slices.add(_Slice(title: m['title'], file: file));
      }
    } catch (e) {
      _showErr('Predict error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /*──────────────── 2-G) /plot_preview ─────────────*/
  Future<void> _callPreview() async {
    if (flairFile == null || segFile == null) return;

    setState(() {
      loading = true;
      previewImg = null;
    });

    final req = http.MultipartRequest('POST', Uri.parse('$_base/plot_preview'))
      ..files.add(_multipart(field: 'flair', pf: flairFile!))
      ..files.add(_multipart(field: 'seg', pf: segFile!));

    try {
      final resp = await http.Response.fromStream(await _http.send(req));
      debugPrint('[preview] status=${resp.statusCode}');
      if (resp.statusCode != 200) throw resp.body;

      final data = jsonDecode(resp.body);
      final bts = (await _http.get(Uri.parse('$_base${data['url']}'))).bodyBytes;
      final docs = await getApplicationDocumentsDirectory();
      previewImg = File('${docs.path}/preview.png')..writeAsBytesSync(bts);
    } catch (e) {
      _showErr('Preview error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /*──────────────── 2-H) /tumor_mesh ───────────────*/
  Future<void> _callTumorMesh() async {
    if (segFile == null) return;

    setState(() {
      loading = true;
      tumorMeshFile = null;
    });

    final req = http.MultipartRequest('POST', Uri.parse('$_base/tumor_mesh'))
      ..files.add(_multipart(field: 'seg', pf: segFile!))
      ..fields['iso_level'] = '0.5';

    try {
      final resp = await http.Response.fromStream(await _http.send(req));
      debugPrint('[tumor_mesh] status=${resp.statusCode}');
      if (resp.statusCode != 200) throw resp.body;

      final data = jsonDecode(resp.body);
      final bts = (await _http.get(Uri.parse('$_base${data['url']}'))).bodyBytes;
      final docs = await getApplicationDocumentsDirectory();
      tumorMeshFile = File('${docs.path}/tumor.glb')..writeAsBytesSync(bts);
    } catch (e) {
      _showErr('Tumour-mesh error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _callBrainMesh() async {
    if (segFile == null || flairFile == null) {          // ➜ تحقّق من الملفّين
      _showErr('Select both Flair and Seg files first');
      return;
    }

    setState(() {
      loading = true;
      brainMeshFile = null;
    });

    final req = http.MultipartRequest('POST', Uri.parse('$_base/brain_mesh'))
      ..files.add(_multipart(field: 'flair', pf: flairFile!))   // ⬅️ جديد
      ..files.add(_multipart(field: 'seg',   pf: segFile!))
      ..fields['label'] = '4';                        // أو أى قيمة مطلوبة

    try {
      final resp = await http.Response.fromStream(await _http.send(req));
      debugPrint('[brain_mesh] status=${resp.statusCode}');
      debugPrint('[brain_mesh] raw    =${resp.body}');
      if (resp.statusCode != 200) throw resp.body;

      final data  = jsonDecode(resp.body);
      final bts   = (await _http.get(Uri.parse('$_base${data['url']}'))).bodyBytes;
      final docs  = await getApplicationDocumentsDirectory();
      brainMeshFile = File('${docs.path}/brain.glb')..writeAsBytesSync(bts);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Brain mesh saved → ${brainMeshFile!.path}')),
        );
      }
    } catch (e) {
      _showErr('Brain-mesh error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  /*────────────────── 3) واجهة المستخدم ──────────────────*/
  @override
  Widget build(BuildContext context) {
    final canPredict = flairFile != null && t1ceFile != null && !loading;
    final canPreview = flairFile != null && segFile != null && !loading;
    final canTumorMesh = segFile != null && !loading;
    final canBrainMesh = segFile != null && !loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Brain-Seg Uploader')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _FileTile(label: 'Flair (.nii/.nii.gz)', file: flairFile, onTap: () => _pickFile('flair')),
              _FileTile(label: 'T1ce  (.nii/.nii.gz)', file: t1ceFile, onTap: () => _pickFile('t1ce')),
              _FileTile(label: 'Segmentation (.nii/.nii.gz)', file: segFile, onTap: () => _pickFile('seg')),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: canPredict ? _callPredict : null,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Predict'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                    onPressed: canPreview ? _callPreview : null,
                    icon: const Icon(Icons.image),
                    label: const Text('Preview'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: canTumorMesh ? _callTumorMesh : null,
                    icon: const Icon(Icons.threed_rotation),
                    label: const Text('Tumor 3-D'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: canBrainMesh ? _callBrainMesh : null,
                    icon: const Icon(Icons.public),
                    label: const Text('Brain 3-D'),
                  ),
                ],
              ),
              const Divider(height: 32),

              /* Preview image */
              if (previewImg != null) ...[
                Text('4-Panel Preview', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => OpenFilex.open(previewImg!.path),
                  child: Image.file(previewImg!, fit: BoxFit.cover),
                ),
                const Divider(height: 32),
              ],

              /* Tumour mesh */
              if (tumorMeshFile != null) ...[
                Text('Tumour mesh (rotate / pinch-zoom)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: ModelViewer(
                    src: 'file://${tumorMeshFile!.path}',
                    iosSrc: tumorMeshFile!.path,
                    alt: 'Tumour mesh',
                    cameraControls: true,
                    autoRotate: true,
                  ),
                ),
                const Divider(height: 32),
              ],

              /* Brain mesh */
              if (brainMeshFile != null) ...[
                Text('Whole-brain mesh', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: ModelViewer(
                    src: 'file://${brainMeshFile!.path}',
                    iosSrc: brainMeshFile!.path,
                    alt: 'Brain mesh',
                    cameraControls: true,
                    autoRotate: true,
                    backgroundColor: Colors.black,
                  ),
                ),
                const Divider(height: 32),
              ],

              /* PNG slices */
              if (slices.isEmpty)
                const Center(child: Text('No slices yet'))
              else
                ...slices.map(
                      (s) => Card(
                    child: ListTile(
                      leading: Image.file(
                        s.file,
                        width: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                      ),
                      title: Text(s.title),
                      onTap: () => OpenFilex.open(s.file.path),
                    ),
                  ),
                ),
            ],
          ),
          if (loading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  void _showErr(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/*────────────────── 4) عناصر مساعدة ──────────────────*/
class _FileTile extends StatelessWidget {
  const _FileTile({required this.label, required this.file, required this.onTap, super.key});
  final String label;
  final PlatformFile? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.insert_drive_file_outlined),
    title: Text(label),
    subtitle: Text(file?.name ?? 'لم يتم الاختيار'),
    trailing: TextButton(onPressed: onTap, child: const Text('Browse')),
  );
}

class _Slice {
  _Slice({required this.title, required this.file});
  final String title;
  final File file;
}
