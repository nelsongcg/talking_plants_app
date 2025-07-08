import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart' show Options, FormData, MultipartFile;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

import '../services/auth_service.dart';
import '../services/api.dart';
import '../widgets/primary_button.dart';
import '../utils/routes.dart';

class PlantPhotoScreen extends StatefulWidget {
  const PlantPhotoScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  State<PlantPhotoScreen> createState() => _PlantPhotoScreenState();
}

class _PlantPhotoScreenState extends State<PlantPhotoScreen> {
  final _picker = ImagePicker();
  final _nickCtl = TextEditingController();

  TextEditingController? _plantCtl;           // assigned on first build()
  Map<String, dynamic>? _selectedPlant;

  XFile? _shot;
  bool   _uploading = false;

  @override
  void dispose() {
    // _plantCtl?.dispose();
    _nickCtl.dispose();
    super.dispose();
  }

  /* ─── take a photo ─────────────────────────────────── */
  Future<void> _takePhoto() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (x != null && mounted) setState(() => _shot = x);
    } catch (e) {
      _show('Camera error: $e');
    }
  }

  /* ─── search plants ────────────────────────────────── */
  Future<List<Map<String, dynamic>>> _searchPlants(String q) async {
    if (q.trim().isEmpty) return [];
    final auth = AuthService();
    final jwt  = await auth.getJwt();
    try {
        final r = await dio.get(
          '/api/plants',
          queryParameters: {'q': q, 'limit': 20},
          options: Options(headers: {'Authorization': 'Bearer $jwt'}),
        );
      return (r.data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  void _resetPlant() {
    setState(() {
      _selectedPlant = null;
      _plantCtl?.clear();
    });
  }

  /* ─── upload ───────────────────────────────────────── */
Future<void> _upload() async {
  if (_uploading) return;
  if (_shot == null)          { _show('Take a photo first'); return; }
  if (_selectedPlant == null) { _show('Please pick a plant from the list'); return; }

  setState(() => _uploading = true);

  try {
    // 1) compress the image
    final originalFile = File(_shot!.path);
    final targetPath = p.join(
      originalFile.parent.path,
      'cmp_${p.basename(_shot!.path)}',
    );
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      originalFile.path,
      targetPath,
      quality: 60,    // 0–100
      minWidth: 800,  // max dimensions
      minHeight: 600,
    );
    final fileToUpload = compressedFile ?? originalFile;

    // 2) build multipart
    final mf = await MultipartFile.fromFile(
      fileToUpload.path,
      filename: p.basename(fileToUpload.path),
      contentType: MediaType('image', 'jpeg'),
    );

    // 3) build form & POST
    final auth = AuthService();
    final jwt  = await auth.getJwt();
    final form = FormData.fromMap({
      'device_id'  : widget.deviceId,
      'plant_id'   : _selectedPlant!['id'].toString(),
      'avatar_name': _nickCtl.text.trim(),
      'photo'      : mf,
    });

    final r = await dio.post(
      '/api/plants/photo',
      data: form,
      options: Options(
        headers: {'Authorization': 'Bearer $jwt'},
        // Dio will automatically add the correct multipart boundary
      ),
    );

    if (r.statusCode == 201 && mounted) {
      _show('Plant registered!');
      Navigator.pushReplacementNamed(context, Routes.connectWifi);
    } else {
      throw Exception('[${r.statusCode}] ${r.data}');
    }
  } catch (e) {
    _show('Upload failed: $e');
  } finally {
    if (mounted) setState(() => _uploading = false);
  }
}
  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ─── UI ───────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    if (widget.deviceId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        _show('No device found to set up.');
      });
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Image.asset('assets/images/italktoplantsvertical_v2.png', height: 80),
              const SizedBox(height: 32),
              Text('Take a photo of your plant and pick its type', style: ts.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // ── preview ──
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  image: _shot != null ? DecorationImage(image: FileImage(File(_shot!.path)), fit: BoxFit.cover) : null,
                ),
                alignment: Alignment.center,
                child: _shot == null ? Icon(Icons.photo_camera_outlined, size: 80, color: cs.onSurface.withOpacity(.4)) : null,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: InkWell(
                  onTap: _takePhoto,
                  borderRadius: BorderRadius.circular(32),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                    child: Icon(_shot == null ? Icons.camera_alt : Icons.refresh, color: Colors.white, size: 28),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── plant selector ──
              TypeAheadField<Map<String, dynamic>>(
                suggestionsCallback: _searchPlants,
                itemBuilder: (context, item) => ListTile(title: Text(item['common_name_en'] ?? item['scientific_name'])),
                emptyBuilder: (_) => const ListTile(title: Text('No plants found')),
                onSelected: (item) {
                  final name = item['common_name_en'] ?? item['scientific_name'];
                  setState(() {
                    _selectedPlant = item;
                    _plantCtl?.text = name;
                    _plantCtl?.selection = TextSelection.collapsed(offset: name.length);
                  });
                },
                builder: (context, controller, focusNode) {
                  // Save the internal controller reference once
                  _plantCtl ??= controller;

                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    readOnly: _selectedPlant != null,
                    decoration: InputDecoration(
                      labelText: 'Plant type',
                      filled: true,
                      fillColor: cs.surfaceVariant,
                      suffixIcon: _selectedPlant != null
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: _resetPlant)
                          : null,
                    ),
                    onChanged: (_) {
                      if (_selectedPlant != null) {
                        setState(() => _selectedPlant = null);
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // ── nickname ──
              TextField(
                controller: _nickCtl,
                decoration: InputDecoration(labelText: 'Nickname', filled: true, fillColor: cs.surfaceVariant),
              ),
              const SizedBox(height: 32),

              PrimaryButton(
                label: _uploading ? 'Uploading…' : 'Save & continue',
                loading: _uploading,
                enabled: !_uploading,
                onPressed: _upload,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
