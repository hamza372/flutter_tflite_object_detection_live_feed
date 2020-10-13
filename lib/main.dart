import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';

const String ssd = "SSD MobileNet";
const String yolo = "Tiny YOLOv2";

List<CameraDescription> cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List _recognitions;
  String _model = ssd;
  double _imageHeight;
  double _imageWidth;
  CameraImage img;
  CameraController controller;
  bool isBusy = false;
  String result = "";
  bool selection = false;

  @override
  void initState() {
    super.initState();
    loadModel();
    initCamera();
  }

  @override
  void dispose(){
    super.dispose();
    controller.stopImageStream();
    Tflite.close();
  }

  Future loadModel() async {
    Tflite.close();
    try {
      String res;
      switch (_model) {
        case yolo:
          res = await Tflite.loadModel(
            model: "assets/yolov2_tiny.tflite",
            labels: "assets/yolov2_tiny.txt",
            // useGpuDelegate: true,
          );
          break;
        case ssd:
          res = await Tflite.loadModel(
            model: "assets/ssd_mobilenet.tflite",
            labels: "assets/ssd_mobilenet.txt",
            // useGpuDelegate: true,
          );
          break;
      }
      print(res);
    } on PlatformException {
      print('Failed to load model.');
    }
  }

  initCamera() {
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        controller.startImageStream((image) => {
              if (!isBusy) {isBusy = true, img = image, runModelOnFrame()}
            });
      });
    });
  }

  Future processFrame() async {
    switch (_model) {
      case yolo:
        await startObjectDetectionUsingYolo();
        break;
      case ssd:
        await startObjectDetectionUsingSSD();
        break;
    }
  }

  runModelOnFrame() async {
    _imageWidth = img.width + 0.0;
    _imageHeight = img.height + 0.0;
    _recognitions = await Tflite.detectObjectOnFrame(
      bytesList: img.planes.map((plane) {
        return plane.bytes;
      }).toList(),
      model: _model == yolo ? "YOLO" : "SSDMobileNet",
      imageHeight: img.height,
      imageWidth: img.width,
      imageMean: _model == yolo ? 0 : 127.5,
      imageStd: _model == yolo ? 255.0 : 127.5,
      numResultsPerClass: 1,
      threshold: _model == yolo ? 0.2 : 0.4,
    );
    print(_recognitions.length);
    isBusy = false;
    setState(() {
      img;
    });
  }

  startObjectDetectionUsingSSD() async {
    if (img != null) {
      {
        _imageWidth = img.width + 0.0;
        _imageHeight = img.height + 0.0;
        _recognitions = await Tflite.detectObjectOnFrame(
            bytesList: img.planes.map((plane) {
              return plane.bytes;
            }).toList(),
            imageHeight: img.height,
            imageWidth: img.width,
            threshold: 0.4,
            imageMean:127.5,
            imageStd: 127.5,
            numResultsPerClass: 1,
            // defaults to 0.1
            );
        isBusy = false;
      }
      print(_recognitions.length);
      setState(() {
        img;
      });
    }
  }

  startObjectDetectionUsingYolo() async {
    if (img != null) {
      {
        _imageWidth = img.width + 0.0;
        _imageHeight = img.height + 0.0;
        _recognitions = await Tflite.detectObjectOnFrame(
            bytesList: img.planes.map((plane) {
              return plane.bytes;
            }).toList(),
            imageHeight: img.height,
            imageWidth: img.width,
            imageMean: 0.0,
            imageStd: 255.0,
            model: "YOLO",
            threshold: 0.2,
            // defaults to 0.1
            );
        isBusy = false;
      }
      setState(() {
        img;
      });
    }
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageHeight == null || _imageWidth == null) return [];
    double factorX = screen.width;
    double factorY = _imageHeight ;// _imageWidth * screen.width;
    Color blue = Color.fromRGBO(37, 213, 253, 1.0);
    return _recognitions.map((re) {
      return Positioned(
        left: re["rect"]["x"] * factorX,
        top: re["rect"]["y"] * factorY,
        width: re["rect"]["w"] * factorX,
        height: re["rect"]["h"] * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            border: Border.all(
              color: blue,
              width: 2,
            ),
          ),
          child: Text(
            "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = blue,
              color: Colors.red,
              fontSize: 15.0,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> stackChildren = [];
    stackChildren.add(Positioned(
      top: 0.0,
      left: 0.0,
      width: size.width,
        height: size.height-100,
      child:  Container(
        height: size.height-100,
              child:(!controller.value.isInitialized) ? new Container(): AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            )
    ));

    if (img != null) {
      stackChildren.addAll(renderBoxes(size));
    }

    stackChildren.add(
      Container(
        height: size.height,
        alignment: Alignment.bottomCenter,
        child: Container(
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('SSD'),
              Switch(
                value: selection,
                onChanged: (value) {
                  setState(() {
                    selection = value;
                    if(value){
                      _model = yolo;
                      controller.stopImageStream();
                      //controller.dispose();
                      print(isBusy);
                      loadModel();
                      initCamera();
                    }else{
                      _model = ssd;
                      controller.stopImageStream();
                      controller.dispose();
                      loadModel();
                      initCamera();
                    }
                  });
                },
              ),
              Text('Yolo'),
            ],
          ),
        ),
      ),
    );

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
            margin: EdgeInsets.only(top: 50),
            color: Colors.black,
            child: Stack(
              children: stackChildren,
            )),
      ),
    );
  }
}
