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

  final String _defaultSelfiePath = 'assets/self.jpeg';
  final String _molduraPath = 'assets/moldura.png';
  final String _medalhaPath = 'assets/medalha10km.png';

  double _offsetX = 0.0; // Posição inicial X
  double _offsetY = 0.0; // Posição inicial Y
  double _selfieSize = 648.0; // Tamanho inicial da selfie
  bool _isDragging = false;
  double _scale = 1.0; // Fator de escala para o zoom
  double _previousScale = 1.0; // Escala anterior ao gesto de zoom

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
    final canvasSize = MediaQuery.of(context).size.width;
    setState(() {
      _offsetX = (_offsetX + deltaX).clamp(0.0, canvasSize - _selfieSize);
      _offsetY = (_offsetY + deltaY).clamp(0.0, canvasSize - _selfieSize);
    });
  }

  void _adjustSize(double scaleChange) {
    final canvasSize = MediaQuery.of(context).size.width;
    setState(() {
      _selfieSize = (_selfieSize * scaleChange).clamp(100.0, canvasSize);
      _centerSelfie(); // Reposiciona ao redimensionar
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
        width: _selfieSize.toInt(), height: _selfieSize.toInt());
    img.copyInto(finalImage, resizedSelfie,
        dstX: _offsetX.toInt(), dstY: _offsetY.toInt());

    // A moldura deve cobrir toda a imagem
    img.copyInto(finalImage, moldura, dstX: 0, dstY: 0);

    // A medalha deve ser colocada de maneira que não ultrapasse os limites
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

  void _moveSelfieLeft() {
    setState(() {
      _offsetX -= 10.0;
    });
  }

  void _moveSelfieRight() {
    setState(() {
      _offsetX += 10.0;
    });
  }

  void _moveSelfieUp() {
    setState(() {
      _offsetY -= 10.0;
    });
  }

  void _moveSelfieDown() {
    setState(() {
      _offsetY += 10.0;
    });
  }

  void _increaseSelfieSize() {
    setState(() {
      _selfieSize += 10.0; // Aumenta o tamanho da selfie
    });
  }

  void _decreaseSelfieSize() {
    setState(() {
      _selfieSize -= 10.0; // Diminui o tamanho da selfie
    });
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
              child: Container(
                width: canvasSize,
                height: canvasSize,
                color: Colors.white,
                child: Stack(
                  children: [
                    Positioned(
                      top: _offsetY,
                      left: _offsetX,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        decoration: BoxDecoration(
                          border: _isDragging
                              ? Border.all(color: Colors.blueAccent, width: 4)
                              : null,
                        ),
                        width: _selfieSize,
                        height: _selfieSize,
                        child: _selfieImage != null
                            ? Image.file(_selfieImage!, fit: BoxFit.fill)
                            : Image.asset(_defaultSelfiePath,
                                fit: BoxFit.cover),
                      ),
                    ),
                    Positioned.fill(
                      child: Image.asset(_molduraPath, fit: BoxFit.cover),
                    ),
                    Positioned(
                      // bottom: 20,
                      // left: 20,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Controle do zoom"),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 40,
                      color: Colors.orange,
                      icon: const Icon(Icons.zoom_in),
                      onPressed: _increaseSelfieSize,
                    ),
                    IconButton(
                      iconSize: 40,
                      color: Colors.orange,
                      icon: const Icon(Icons.zoom_out),
                      onPressed: _decreaseSelfieSize,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Ajuste sua foto utilizando as setas"),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 40,
                      color: Colors.orange,
                      icon: const Icon(Icons.arrow_circle_left_outlined),
                      onPressed: _moveSelfieLeft,
                    ),
                    IconButton(
                      iconSize: 40,
                      color: Colors.orange,
                      icon: const Icon(Icons.arrow_circle_right_outlined),
                      onPressed: _moveSelfieRight,
                    ),
                    IconButton(
                      iconSize: 40,
                      color: Colors.orange,
                      icon: const Icon(Icons.arrow_circle_up_outlined),
                      onPressed: _moveSelfieUp,
                    ),
                    IconButton(
                      iconSize: 40,
                      color: Colors.orange,
                      icon: const Icon(Icons.arrow_circle_down_outlined),
                      onPressed: _moveSelfieDown,
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
