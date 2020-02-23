import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:device_info/device_info.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:recycle_it/animation.dart';

import 'credentials.dart';

import 'package:geolocator/geolocator.dart';


import 'package:mongo_dart/mongo_dart.dart' as mongo;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:recase/recase.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:liquid_progress_indicator/liquid_progress_indicator.dart';

//potentially have negative keywords
//offer user an option 'did we get this correct'
//if not add all the labels to  a 'risk' filter

var firstCamera;

var recyclables = [
  "plastic bottle",
  "plastic",
  "paper",
  "glass",
  "glass bottle",
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
  "tin",
  "tin can",
  "can",
  "aluminum",
  "aluminum can",
  "interior design",
  "room"
];

var negativeKeywords = ["reusable"];
Position position;
List<Placemark> placemark;

var coll;
mongo.Db db;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();
  firstCamera = cameras.first;

  position = await Geolocator().getCurrentPosition(desiredAccuracy: LocationAccuracy.lowest);
  print(position);
  placemark = await Geolocator().placemarkFromCoordinates(position.latitude,position.longitude,localeIdentifier:"en_UK");

  db = new mongo.Db(dburl);
  await db.open();
  coll = db.collection('data');

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
                boxHeight: height / 6,
                loadDuration: Duration(milliseconds: 3000),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ShowUp(
                  child: Icon(
                    Icons.location_on,
                    color: Colors.white,
                  ),
                  delay: 2000,
                  bottom: 0.5,
                ),
                ShowUp(
                  child: Text(
                    placemark[0].administrativeArea,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                    ),
                  ),
                  delay: 2250,
                  bottom: 0.5,
                ),
              ],
            ),
            SizedBox(height: height / 26),
            Padding(
              padding: EdgeInsets.fromLTRB(width/7, 0, width/7, 0),
              child: ShowUp(
                child: Text(
                  "Take a picture of your rubbish and we will tell you whether it is recyclable.",
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                delay: 2250,
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
                builder: (context) => TakePictureScreen(camera: firstCamera)),
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
                  MaterialPageRoute(builder: (context) => MapPage()),
                  //MaterialPageRoute(builder: (context) => LiquidCircularProgressIndicatorPage()),
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
                  MaterialPageRoute(builder: (context) => StatsPage()),
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
            return Center(
              child: CircularProgressIndicator(
                backgroundColor: Colors.green,
                valueColor: new AlwaysStoppedAnimation<Color>(
                  Colors.green.shade300
                ),
              ),
            );
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
          child: Icon(Icons.camera),
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
  List scoreData = [];
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

      List temp = ['NOT RECYCLABLE'];
      List temp2 = [0.0];
      var addInfo;

      if (data['responses'][0]['labelAnnotations'].length != null) {
        for (int i = 0; i < data['responses'][0]['labelAnnotations'].length; i++) {
          if (recyclables.contains(data['responses'][0]['labelAnnotations'][i]['description'].toLowerCase())) {
            if (temp.contains('NOT RECYCLABLE')) temp.remove('NOT RECYCLABLE');

            if (temp2.contains(0.0)) temp2.remove(0.0);

            temp.add(data['responses'][0]['labelAnnotations'][i]['description'].toLowerCase());
            temp2.add(data['responses'][0]['labelAnnotations'][i]['score']);
          }
        }

        for (int i = 0; i < data['responses'][0]['labelAnnotations'].length; i++) {
          if (negativeKeywords.contains(data['responses'][0]['labelAnnotations'][i]['description'].toLowerCase())) {
            //hit a negative so clear string
            temp = ['NOT RECYCLABLE'];
            temp2 = [0.0];
          }
        }
        if (temp != []) {
          DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
          var id = '';
          if (Platform.isAndroid) {
            AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
            id = androidInfo.androidId;
            print('Running on ${androidInfo.androidId}');
          } else if (Platform.isIOS) {
            IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
            id = iosInfo.identifierForVendor;

            print('Running on ${iosInfo.identifierForVendor}');
          }

          if (!temp.contains('NOT RECYCLABLE') && !temp2.contains(0.0)) {
            await coll.insert(
                {'uuid': id, 'kws': temp, 'created_at': new DateTime.now(), 'lat': position.latitude, "long": position.longitude});
          }

          addInfo = await coll.count({'uuid': id});
        } else {
          temp = ['NOT RECYCLABLE'];
          temp2 = [0.0];
        }
      }

      print(temp);

      setState(() {
        if (temp == []) {
          recyclableData = [];
          scoreData = [];
        } else {
          recyclableData = temp;
          scoreData = temp2;
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
    print(recyclableData);

    if (recyclableData.length != 0 && recyclableData != null && scoreData.length != 0 && scoreData != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Recycle It"),
          backgroundColor: Colors.green.shade300,
          automaticallyImplyLeading: false,        
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ShowUp(
                child:Text(
                  "Your rubbish is recyclable!",
                  style: TextStyle(
                    fontSize: 26.0,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                delay: 750,
                bottom: 0.5,
              ),
              ShowUp(
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: LiquidCircularProgressIndicator(
                    value: scoreData[0],
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation(Colors.green.shade300),
                    direction: Axis.vertical,
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.fromLTRB(0, 28, 0, 0),
                          child:
                          Text(
                            recyclableData[0].toString().titleCase,
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,                        
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(0, 12, 0, 0),
                          child:
                          Text(
                            (scoreData[0] * 100).toString().substring(0,4) + "%",
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,                        
                          ),
                        ),
                      ],
                    ),
                    borderColor: Colors.grey.shade200,
                    borderWidth: 2.0,
                  ),
                ),
              delay: 1250,
              bottom: 5.0,
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                for (var i = 1; i < recyclableData.length && i < 5; i++)
                  ShowUp(
                    child: SizedBox(
                      width: 75,
                      height: 75,
                      child: LiquidCircularProgressIndicator(
                        value: scoreData[i],
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(Colors.green.shade300),
                        direction: Axis.vertical,
                        center: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.fromLTRB(0, 14, 0, 0),
                              child:
                              Text(
                                recyclableData[i].toString().titleCase,
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                                textAlign: TextAlign.center,                        
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(0, 6, 0, 0),
                              child:
                              Text(
                                (scoreData[i] * 100).toString().substring(0,4) + "%",
                                style: TextStyle(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black,
                                ),
                                textAlign: TextAlign.center,                        
                              ),
                            ),
                          ],
                        ),
                        borderColor: Colors.grey.shade200,
                        borderWidth: 2.0,
                      ),
                    ),
                    delay: 2250,
                    bottom: 5.0,
                  ),
              ],
            ),
            ShowUp(
              child: Text(
                "Items Scanned: ${returnAddInfo.toString()}",
              ),
              delay: 3250,
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
      return Scaffold(
        appBar: AppBar(
        title: Text("Recycle It"),
        backgroundColor: Colors.green.shade300,
      ),
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            backgroundColor: Colors.green,
            valueColor: new AlwaysStoppedAnimation<Color>(
              Colors.green.shade300
            ),
          ),
        ),
      );
    }
  }
}

/* page to render the heat map */
class MapPage extends StatefulWidget {
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {

  final CameraPosition _cameraPosition = CameraPosition(
    target: LatLng(position.latitude, position.longitude),
    zoom: 14,
  );

  final Map<String, Marker> _markers = {};
  
  Future<void> _onMapCreated(GoogleMapController controller) async {
    var locations = await coll.find();
    setState(() {
      _markers.clear();

      for (var loc in locations) {
        final marker = Marker(
          markerId: MarkerId(loc.uuid),
          position: LatLng(loc.lat, loc.lng),
        );
        _markers[loc.uuid] = marker;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Recycle It"),
        backgroundColor: Colors.green.shade300,
        automaticallyImplyLeading: false,        
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _cameraPosition,
        onMapCreated: _onMapCreated,
        markers: _markers.values.toSet(),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
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

class StatsPage extends StatefulWidget {

  const StatsPage();

  @override
  _StatsPageState createState() => _StatsPageState();
}

/* page to render the stats page */
class _StatsPageState extends State<StatsPage> {
  List data;
  String htmlBody = "";

  Future request() async {
    String qstring = placemark[0].postalCode.replaceFirst(' ', '+').substring(0,placemark[0].postalCode.length-1);
    String geoLocationURL = 'https://exeter.gov.uk/repositories/hidden-pages/address-finder/?qtype=bins&term=' + qstring;   

    final geoResponse = await http.get(geoLocationURL);
    
    data = json.decode(geoResponse.body);
    htmlBody = data[0]['Results'];

    setState(() {
        if (htmlBody == '') {
          htmlBody = '';
        } else {
          htmlBody = htmlBody;
        }
      });
  }

  @override
  void initState() {
    super.initState();
    request();
  } 

  @override
  Widget build(BuildContext context) {
    if (htmlBody!=""){
      return Scaffold(
        appBar: AppBar(
          title: Text("Recycle It"),
          backgroundColor: Colors.green.shade300,
          automaticallyImplyLeading: false,        
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children:[
              Html(
                data:htmlBody,
                padding: EdgeInsets.all(20.0),
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
    else {
      return Scaffold(
        appBar: AppBar(
          title: Text("Recycle It"),
          backgroundColor: Colors.green.shade300,
        ),
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            backgroundColor: Colors.green,
            valueColor: new AlwaysStoppedAnimation<Color>(
              Colors.green.shade300
            ),
          ),
        ),
      );
    }
  }
}
