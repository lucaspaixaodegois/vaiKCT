import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PhotoFramePage extends StatefulWidget {
  const PhotoFramePage({super.key});

  @override
  _PhotoFramePageState createState() => _PhotoFramePageState();
}

class _PhotoFramePageState extends State<PhotoFramePage> {
  File? _selfieImage;
  File? _previewImageFile;
  final ImagePicker _picker = ImagePicker();
  final GlobalKey _canvasKey = GlobalKey();

  final String _defaultSelfiePath = 'assets/self.jpg';
  final String _molduraPath = 'assets/moldura_pub_geral.png';
  final String _medalhaPath = 'assets/medalha_jan.png';
  final String meta = '100 km';

  double _offsetX = 0.0; // Posição inicial X
  double _offsetY = 0.0; // Posição inicial Y
  double _scale = 1.0; // Escala inicial
  double _previousScale = 1.0;

  void _centerImage() {
    setState(() {
      final canvasSize = MediaQuery.of(context).size.width;
      // Centralizar a imagem no container
      _offsetX =
          (canvasSize - (_selfieImage != null ? canvasSize * _scale : 0)) / 2;
      _offsetY =
          (canvasSize - (_selfieImage != null ? canvasSize * _scale : 0)) / 2;
      _scale = 1.0; // Redefine a escala para o valor padrão
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selfieImage = File(pickedFile.path);
      });
      _centerImage(); // Centraliza a imagem carregada
    }
  }

  Future<void> _generateFinalImage() async {
    try {
      // Captura o widget atual como imagem com a escala apropriada
      final RenderRepaintBoundary boundary = _canvasKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      final double devicePixelRatio = ui.window.devicePixelRatio;
      final ui.Image image =
          await boundary.toImage(pixelRatio: devicePixelRatio);

      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception("Falha ao gerar byteData da imagem.");
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Salva a imagem capturada
      final tempDir = await getTemporaryDirectory();
      final File outputFile = File('${tempDir.path}/montagem_final.png');
      await outputFile.writeAsBytes(pngBytes);

      setState(() {
        _previewImageFile = outputFile;
      });
    } catch (e) {
      debugPrint("Erro ao gerar imagem final: $e");
    }
  }

  Future<void> _shareFinalImage() async {
    if (_previewImageFile != null) {
      try {
        await Share.shareXFiles([XFile(_previewImageFile!.path)],
            text: "Confira minha montagem!");
      } catch (e) {
        debugPrint("Erro ao compartilhar imagem: $e");
      }
    } else {
      debugPrint("Nenhuma imagem gerada para compartilhar.");
    }
  }

  void _showPreviewDialog(BuildContext context) {
    if (_previewImageFile != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Preview da Montagem Final"),
            content: Image.file(_previewImageFile!),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("Fechar"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _shareFinalImage();
                },
                child: const Text("Compartilhar"),
              ),
            ],
          );
        },
      );
    } else {
      debugPrint("Nenhuma imagem gerada para preview.");
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
                      _scale =
                          (_previousScale * details.scale).clamp(0.025, 6.0);
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
                        // Texto dinâmico na medalha
                        Positioned(
                          top: canvasSize *
                              0.36, // Ajusta a posição vertical do texto
                          left: canvasSize *
                              0.0001, // Ajusta a posição horizontal do texto
                          child: Container(
                            width: canvasSize *
                                0.45, // Define a largura proporcional do espaço do texto
                            height: canvasSize *
                                0.1, // Define a altura proporcional do espaço do texto
                            alignment: Alignment
                                .center, // Centraliza o texto dentro do container
                            child: FittedBox(
                              fit: BoxFit
                                  .scaleDown, // Garante que o texto se ajuste ao tamanho do container
                              child: Text(
                                meta, // Texto dinâmico da variável meta
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize:
                                      30, // Tamanho inicial da fonte (ajustado dinamicamente pelo FittedBox)
                                  fontWeight: FontWeight
                                      .bold, // Negrito para destacar o texto
                                  color: Colors.black, // Cor do texto
                                ),
                              ),
                            ),
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
                    Text("Tirar ou enviar foto"),
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
                    onPressed: () async {
                      await _generateFinalImage();
                      _showPreviewDialog(context);
                    },
                    child: const Text("Gerar e Compartilhar"),
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
