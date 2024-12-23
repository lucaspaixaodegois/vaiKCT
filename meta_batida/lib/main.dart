import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  final GlobalKey _canvasKey = GlobalKey();

  final String _defaultSelfiePath = 'assets/self.jpg';
  final String _molduraPath = 'assets/moldura.png';
  final String _medalhaPath = 'assets/medalha20km.png';

  double _offsetX = 0.0; // Posição inicial X
  double _offsetY = 0.0; // Posição inicial Y
  double _scale = 1.0; // Escala inicial
  double _previousScale = 1.0;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selfieImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _shareFinalImage() async {
    try {
      // Captura o widget atual como imagem
      final RenderRepaintBoundary boundary = _canvasKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage();
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Salva a imagem capturada
      final tempDir = await getTemporaryDirectory();
      final File outputFile = File('${tempDir.path}/montagem_final.png');
      await outputFile.writeAsBytes(pngBytes);

      // Compartilha a imagem gerada
      await Share.shareXFiles([XFile(outputFile.path)],
          text: "Confira minha montagem!");
    } catch (e) {
      debugPrint("Erro ao compartilhar imagem: $e");
    }
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
              child: RepaintBoundary(
                key: _canvasKey,
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
                            child:
                                Image.asset(_medalhaPath, fit: BoxFit.contain),
                          ),
                        ),
                      ],
                    ),
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
                  children: const [
                    Text("Escolha ou tire sua Self"),
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
