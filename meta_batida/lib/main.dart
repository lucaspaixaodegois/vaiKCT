import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const PhotoFrameApp());
}

class PhotoFrameApp extends StatelessWidget {
  const PhotoFrameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PhotoFramePage(),
    );
  }
}

class PhotoFramePage extends StatefulWidget {
  const PhotoFramePage({super.key});

  @override
  _PhotoFramePageState createState() => _PhotoFramePageState();
}

class _PhotoFramePageState extends State<PhotoFramePage> {
  File? _selfieImage;
  final ImagePicker _picker = ImagePicker();

  final String _defaultSelfiePath = 'assets/self.jpg';
  final String _molduraPath = 'assets/moldura.png';
  final String _medalhaPath = 'assets/medalha20km.png';

  double _offsetX = 0.0; // Posição inicial X
  double _offsetY = 0.0; // Posição inicial Y
  double _selfieSize = 648.0; // Tamanho inicial da selfie
  double _scale = 1.0; // Escala inicial
  double _previousScale = 1.0;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selfieImage = File(pickedFile.path);
        _centerSelfie();
      });
    }
  }

  void _centerSelfie() {
    final canvasSize = MediaQuery.of(context).size.width;
    setState(() {
      _offsetX = (canvasSize - _selfieSize) / 2;
      _offsetY = (canvasSize - _selfieSize) / 2;
    });
  }

  void _adjustPosition(double deltaX, double deltaY) {
    setState(() {
      _offsetX += deltaX;
      _offsetY += deltaY;
    });
  }

  void _adjustScale(double scaleChange) {
    setState(() {
      _scale = (_scale * scaleChange).clamp(0.5, 3.0);
    });
  }

  Future<void> _shareFinalImage() async {
    try {
      final img.Image finalImage = await _createFinalImage();
      final File outputFile = await _saveImage(finalImage);
      await _shareImage(outputFile);
    } catch (e) {
      if (kDebugMode) {
        print("Erro ao compartilhar imagem: $e");
      }
    }
  }

  Future<img.Image> _createFinalImage() async {
    final img.Image moldura = await _loadAssetImage(_molduraPath);
    final img.Image medalha = await _loadAssetImage(_medalhaPath);
    final img.Image selfie = await _loadSelfie();

    const int canvasSize = 1080;
    final img.Image finalImage = img.Image(canvasSize, canvasSize);
    img.fill(finalImage, img.getColor(255, 255, 255));

    final img.Image resizedSelfie = img.copyResize(selfie,
        width: (_selfieSize * _scale).toInt(),
        height: (_selfieSize * _scale).toInt());
    img.copyInto(finalImage, resizedSelfie,
        dstX: _offsetX.toInt(), dstY: _offsetY.toInt());

    img.copyInto(finalImage, moldura, dstX: 0, dstY: 0);

    final img.Image resizedMedalha =
        img.copyResize(medalha, width: 1000, height: 1000);
    img.copyInto(finalImage, resizedMedalha, dstX: 100, dstY: 800);

    return finalImage;
  }

  Future<img.Image> _loadAssetImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    return img.decodeImage(data.buffer.asUint8List())!;
  }

  Future<img.Image> _loadSelfie() async {
    if (_selfieImage != null) {
      return img.decodeImage(File(_selfieImage!.path).readAsBytesSync())!;
    } else {
      return await _loadAssetImage(_defaultSelfiePath);
    }
  }

  Future<File> _saveImage(img.Image image) async {
    final tempDir = await getTemporaryDirectory();
    final File outputFile = File('${tempDir.path}/montagem_final.png');
    await outputFile.writeAsBytes(img.encodePng(image));
    return outputFile;
  }

  Future<void> _shareImage(File imageFile) async {
    await Share.shareXFiles([XFile(imageFile.path)],
        text: "Confira minha montagem!");
  }

  @override
  Widget build(BuildContext context) {
    final canvasSize = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Montagem de Foto com Moldura"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: GestureDetector(
                onScaleStart: (details) {
                  _previousScale = _scale;
                },
                onScaleUpdate: (details) {
                  setState(() {
                    _scale = (_previousScale * details.scale).clamp(0.5, 3.0);
                    _offsetX += details.focalPointDelta.dx;
                    _offsetY += details.focalPointDelta.dy;
                  });
                },
                child: Container(
                  width: canvasSize,
                  height: canvasSize,
                  color: Colors.white,
                  child: Stack(
                    children: [
                      Positioned(
                        top: _offsetY,
                        left: _offsetX,
                        child: Transform.scale(
                          scale: _scale,
                          child: _selfieImage != null
                              ? Image.file(_selfieImage!, fit: BoxFit.fill)
                              : Image.asset(_defaultSelfiePath,
                                  fit: BoxFit.fill),
                        ),
                      ),
                      Positioned.fill(
                        child: Image.asset(_molduraPath, fit: BoxFit.cover),
                      ),
                      Positioned(
                        child: SizedBox(
                          width: canvasSize * 1,
                          height: canvasSize * 1.3,
                          child: Image.asset(_medalhaPath, fit: BoxFit.contain),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Escolha ou tire sua Self"),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      color: Colors.orange,
                      iconSize: 40,
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                    IconButton(
                      color: Colors.orange,
                      iconSize: 40,
                      icon: const Icon(Icons.photo),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: _shareFinalImage,
                    child: const Text("Compartilhar Imagem"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
