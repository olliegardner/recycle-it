import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:device_info/device_info.dart';
import 'package:recycle_it/animation.dart';

import 'credentials.dart';

import 'package:mongo_dart/mongo_dart.dart' as mongo;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:recase/recase.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

//potentially have negative keywords
//offer user an option 'did we get this correct'
//if not add all the labels to  a 'risk' filter

var firstCamera;

var recyclables = [
  "plastic bottle",
  "plastic",
  "paper",
  "glass",
  "cardboard",
  "packaging",
  "cup",
  "bottle",
  "bottled",
  "can",
  "aerosol",
  "deoderant",
  "aluminium",
  "foil",
  "puree",
  "polythene",
  "film",
  "wrap",
  "newspaper",
  "magazine",
  "envelope",
  "carrier",
  "catalogue",
  "phone directory",
  "drinkware",


  "interior design",
  "room"
];

var negativeKeywords = ["reusable"];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();
  firstCamera = cameras.first;

  runApp(
    MaterialApp(
      home: HomePage(),
    ),
  );
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.green.shade300,

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: width,
              child: TextLiquidFill(
                text: "Recycle It",
                waveColor: Colors.white,
                boxBackgroundColor: Colors.green.shade300,
                textStyle: TextStyle(
                  fontSize: 55.0,
                  fontWeight: FontWeight.w300,
                ),
                boxHeight: height / 3,
                loadDuration: Duration(milliseconds: 3000),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(width/7, 0, width/7, height/7),
              child: ShowUp(
                child: Text(
                  "Give us an image of your rubbish and we'll tell you whether it is recyclable.",
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                delay: 1250,
                bottom: 0.5,
              ),
            ),
          ], 
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 6.0,
        icon: Icon(
          Icons.camera_alt,
          color: Colors.green.shade300,
        ),
        label: Text(
          "Take Picture",
          style: TextStyle(
            fontSize: 14.0,
            color: Colors.green.shade300,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TakePictureScreen(camera: firstCamera)
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.green.shade300,
        child: new Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.map),
              color: Colors.white,
              iconSize: 35,
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MapPage()
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.menu),
              color: Colors.white,
              iconSize: 35,
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StatsPage()
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}

class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;

  const TakePictureScreen({
    Key key,
    @required this.camera,
  }) : super(key: key);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  CameraController _controller;
  Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.ultraHigh);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 30.0),
        child: FloatingActionButton(
          onPressed: () async {
            try {
              await _initializeControllerFuture;

              final path = join(
                (await getTemporaryDirectory()).path,
                '${DateTime.now()}.png',
              );

              await _controller.takePicture(path);

              final bytes = File(path).readAsBytesSync();
              String img64 = base64Encode(bytes);

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => RecyclePage(base64img: img64),
                ),
              );
            } catch (e) {
              print(e);
            }
          },
          tooltip: 'Camera',
          child: Icon(
            Icons.camera
          ),
          backgroundColor: Colors.green.shade300,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class RecyclePage extends StatefulWidget {
  final String base64img;

  const RecyclePage({Key key, this.base64img}) : super(key: key);

  @override
  _RecyclePageState createState() => _RecyclePageState();
}

class _RecyclePageState extends State<RecyclePage> {
  Map data;
  List recyclableData = [];
  int returnAddInfo = 0;

  Future request() async {
    String url = 'https://vision.googleapis.com/v1/images:annotate?key=' + key;

    final body = jsonEncode({
      "requests": [
        {
          "image": {"content": "${widget.base64img}"},
          "features": [
            {"type": "LABEL_DETECTION", "maxResults": 25}
          ]
        }
      ]
    });

    final response = await http.post(url,
        headers: {
          "accept-encoding": "appplication/json",
          "Content-Type": "'application/json'"
        },
        body: body);

    if (response.statusCode == 200) {
      data = json.decode(response.body);

      print(response.body);

      List temp = [];
      var addInfo;

      if (data['responses'][0]['labelAnnotations'].length != null) {
        for (int i = 0;
            i < data['responses'][0]['labelAnnotations'].length;
            i++) {
          if (recyclables.contains(data['responses'][0]['labelAnnotations'][i]
                  ['description']
              .toLowerCase())) {
            temp.add(data['responses'][0]['labelAnnotations'][i]['description']
                    .toLowerCase());
          }
        }
        for (int i = 0;
            i < data['responses'][0]['labelAnnotations'].length;
            i++) {
          if (negativeKeywords.contains(data['responses'][0]['labelAnnotations']
                  [i]['description']
              .toLowerCase())) {
            //hit a negative so clear string
            temp = [];
          }
        }
        if (temp != []) {
          DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
          var id = '';
          if (Platform.isAndroid) {
            AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
            id =androidInfo.androidId;
            print('Running on ${androidInfo.androidId}');
          } else if (Platform.isIOS) {
            IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
            id = iosInfo.identifierForVendor;

            print('Running on ${iosInfo.identifierForVendor}');
          }

          mongo.Db db = new mongo.Db(dburl);
          await db.open();

          var coll = db.collection('data');
          await coll.insert({
            'uuid': id,
            'kws': temp,
            'created_at': new DateTime.now()
          });

          addInfo = await coll.count({
            'uuid': id
          });
        } else {
          print('dont insert unrecyclable doc');
        }
      }

      while (recyclableData == []) {
        return Center(child: CircularProgressIndicator());
      }

      setState(() {
        if (temp == []) {
          recyclableData = ['No matches'];
        } else {
          recyclableData = temp;
          returnAddInfo = addInfo;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    request();
  }

  @override
  Widget build(BuildContext context) {
    if (recyclableData.length > 0) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Recycle It"),
          backgroundColor: Colors.green.shade300,
          automaticallyImplyLeading: false,        
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShowUp(
                child: Text(
                  recyclableData[0].toString().titleCase,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28
                  ),
                ),
                delay: 750,
                bottom: 5.0
              ),
              for (var i = 1; i < recyclableData.length; i++)
                ShowUp(
                  child: Text(
                    recyclableData[i].toString().titleCase,
                    style: TextStyle(
                      fontSize: 20
                    ),
                  ),
                  delay: 1250, 
                  bottom: 5.0,
                ),
              ShowUp(
                child: Text(
                  "Items Scanned: ${returnAddInfo.toString()}",
                ),
                delay: 1750,
                bottom: 5.0,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage()
              ),
            );
          },
          tooltip: 'Home',
          child: Icon(Icons.home),
          backgroundColor: Colors.green.shade300,
        ),
      );
    } else {
      return Center(
        child: Icon(
          Icons.check,
          color: Colors.green.shade300,
          size: 100,
        )
      );
    }
  }
}

/* page to render the heat map */
class MapPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Recycle It"),
        backgroundColor: Colors.green.shade300,
        automaticallyImplyLeading: false,        
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "This is the map page",
            )
          ], 
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage()
            ),
          );
        },
        tooltip: 'Home',
        child: Icon(
          Icons.home
        ),
        backgroundColor: Colors.green.shade300,
      ),
    );
  }
}

/* page to render the stats page */
class StatsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Recycle It"),
        backgroundColor: Colors.green.shade300,
        automaticallyImplyLeading: false,        
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "This is the stats page",
            )
          ], 
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage()
            ),
          );
        },
        tooltip: 'Home',
        child: Icon(
          Icons.home
        ),
        backgroundColor: Colors.green.shade300,
      ),
    );
  }
}
