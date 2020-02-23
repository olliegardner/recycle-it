import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:device_info/device_info.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:recycle_it/animation.dart';
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

import 'credentials.dart';

//potentially have negative keywords
//offer user an option 'did we get this correct'
//if not add all the labels to  a 'risk' filter
var firstCamera;

var recyclables = [
  "paper",
  "cardboard",
  "packaging",
  "cup",
  "aerosol",
  "deoderant",
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

var plastics = [
  "plastic bottle",
  "plastic",
];

var glass = [
  "glass",
  "glass bottle",
];

var cans = [
  "tin",
  "tin can",
  "can",
  "aluminum",
  "aluminum can",
];

var food = [
  "dish",
  "food",
  "cuisine",
  "fast food",
  "junk food",
  "fruit",
  "citruis",
  "vegetables"
];

Map<String, Color> binColours = {
  'Mixed recycling': Colors.blue.shade300,
  'Plastic recycling': Colors.red.shade300,
  'Glass recycling': Colors.teal.shade300,
  'Can recycling': Colors.blueGrey.shade300,
  'Food recycling': Colors.brown.shade300
};

Map<String, String> binColoursString = {
  'Mixed recycling': "Blue",
  'Plastic recycling': "Red",
  'Glass recycling': "Teal",
  'Can recycling': "Grey",
  'Food recycling': "Brown"
};

var negativeKeywords = ["reusable"];
Position position;
List<Placemark> placemark;

var coll;
mongo.Db db;

var uuid;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    uuid = androidInfo.androidId;
  } else if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    uuid = iosInfo.identifierForVendor;
  } else {
    uuid = null;
  }

  final cameras = await availableCameras();
  firstCamera = cameras.first;

  position = await Geolocator()
      .getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
  placemark = await Geolocator().placemarkFromCoordinates(
      position.latitude, position.longitude,
      localeIdentifier: "en_UK");

  db = new mongo.Db(dburl);
  await db.open();
  coll = db.collection('data');

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
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
      appBar: AppBar(
        backgroundColor: Colors.green.shade300,
        elevation: 0.0,
        actions: <Widget>[
          IconButton(
              icon: Icon(
                Icons.insert_chart,
                size: 35.0,
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StatsPage(),
                  ),
                );
              },
              padding: const EdgeInsets.only(
                right: 15.0
              ),
            ),
        ],
      ),

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
                    placemark[0].locality,
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
            SizedBox(
              height: height / 26
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(width / 7, 0, width / 7, 0),
              child: ShowUp(
                child: Text(
                  "Take a picture of your rubbish and we'll tell you whether it is recyclable or not.",
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
              padding: const EdgeInsets.only(left: 15.0),
              onPressed: () {
                coll = db.collection('data');

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MapPage()),
                  //MaterialPageRoute(builder: (context) => LiquidCircularProgressIndicatorPage()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.calendar_today),
              color: Colors.white,
              iconSize: 35,
              padding: const EdgeInsets.only(right: 15.0),
              onPressed: () {
                coll = db.collection('data');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => CalendarPage()),
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
                valueColor:
                    new AlwaysStoppedAnimation<Color>(Colors.green.shade300),
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
  String whichbin = '';

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

      List temp = ['NOT RECYCLABLE'];
      List temp2 = [0.0];
      var addInfo;

      if (data['responses'][0]['labelAnnotations'].length != null) {
        for (int i = 0;
            i < data['responses'][0]['labelAnnotations'].length;
            i++) {
          var compareData = data['responses'][0]['labelAnnotations'][i]
                  ['description']
              .toLowerCase();
          if (recyclables.contains(compareData) ||
              plastics.contains(compareData) ||
              glass.contains(compareData) ||
              cans.contains(compareData) ||
              food.contains(compareData)) {
            if (temp.contains('NOT RECYCLABLE')) temp.remove('NOT RECYCLABLE');
            if (temp2.contains(0.0)) temp2.remove(0.0);
            

            temp.add(data['responses'][0]['labelAnnotations'][i]['description'].toLowerCase());
            if (whichbin == ''){
              if(recyclables.contains(compareData)){whichbin = 'Mixed recycling';}
              else if(plastics.contains(compareData)){whichbin = 'Plastic recycling';}
              else if(glass.contains(compareData)){whichbin = 'Glass recycling';}
              else if(cans.contains(compareData)){whichbin = 'Can recycling';}
              else if(food.contains(compareData)){whichbin = 'Food recycling';}
            };
            temp2.add(data['responses'][0]['labelAnnotations'][i]['score']);
          }
        }

        for (int i = 0;
            i < data['responses'][0]['labelAnnotations'].length;
            i++) {
          if (negativeKeywords.contains(data['responses'][0]['labelAnnotations']
                  [i]['description']
              .toLowerCase())) {
            //hit a negative so clear string
            temp = ['NOT RECYCLABLE'];
            temp2 = [0.0];
          }
        }
        if (temp != []) {
          if (!temp.contains('NOT RECYCLABLE') && !temp2.contains(0.0)) {
            await coll.insert({
              'uuid': uuid,
              'kws': temp,
              'created_at': new DateTime.now(),
              'lat': position.latitude,
              "long": position.longitude,
              "type": whichbin
            });
          }

          addInfo = await coll.count({'uuid': uuid});
        } else {
          temp = ['NOT RECYCLABLE'];
          temp2 = [0.0];
        }
      }

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
    print(whichbin);
    print(scoreData);

    if (recyclableData.length != 0 && recyclableData != null) {
      if (recyclableData.length == 1 && recyclableData[0] == 'NOT RECYCLABLE') {
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
              ShowUp(
                child: Text(
                  "Not recyclable",
                  style: TextStyle(
                    fontSize: 28.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                delay: 1500,
                bottom: 0.5,
              ),
              SizedBox(
                height: 15,
              ),
              ShowUp(
                child: Text(
                  "Put your rubbish in the general waste",
                  style: TextStyle(
                    fontSize: 14.0,
                  ),
                ),
                delay: 2000,
                bottom: 0.5,
              ),
            ]
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            },
            tooltip: 'Home',
            child: Icon(Icons.home),
            backgroundColor: Colors.green.shade300,
          ),
        );
      } else
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
                  child: Text(
                    whichbin.titleCase,
                    style: TextStyle(
                      fontSize: 28.0,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  delay: 750,
                  bottom: 0.5,
                ),
                ShowUp(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: LiquidCircularProgressIndicator(
                      value: scoreData[0],
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation(Colors.green.shade300),
                      direction: Axis.vertical,
                      center: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 26, 0, 0),
                            child: Text(
                              recyclableData[0].toString().titleCase,
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 15, 0, 0),
                            child: Text(
                              (scoreData[0] * 100).toString().substring(0, 4) +
                                  "%",
                              style: TextStyle(
                                fontSize: 14.0,
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
                    for (var i = 1; i < recyclableData.length; i++)
                      ShowUp(
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: LiquidCircularProgressIndicator(
                            value: scoreData[i],
                            backgroundColor: Colors.grey.shade100,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.green.shade300),
                            direction: Axis.vertical,
                            center: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Padding(
                                  padding: EdgeInsets.fromLTRB(0, 14, 0, 0),
                                  child: Text(
                                    recyclableData[i].toString().titleCase,
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
                                  child: Text(
                                    (scoreData[i] * 100)
                                            .toString()
                                            .substring(0, 4) +
                                        "%",
                                    style: TextStyle(
                                      fontSize: 11.0,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ShowUp(
                      child: Icon(
                        Icons.cached,
                        color: binColours[whichbin]
                      ),
                      delay: 2750,
                      bottom: 5.0,
                    ),   
                    ShowUp(
                      child: Text(
                        " " + binColoursString[whichbin] + " " + "recycling bin".titleCase,
                        style: TextStyle(
                          color: binColours[whichbin],
                          fontSize: 20.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      delay: 3250,
                      bottom: 5.0,
                    ),
                  ],
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
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
            valueColor:
                new AlwaysStoppedAnimation<Color>(Colors.green.shade300),
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
  static final CameraPosition _cameraPosition = CameraPosition(
    target: LatLng(position.latitude, position.longitude),
    zoom: 14,
  );

  Map<String, Marker> _markers = {};

  Future<void> _onMapCreated(GoogleMapController controller) async {
    coll = db.collection('data');
    var locations = await coll.find(mongo.where.gt("lat", 0)).toList();

    setState(() {
      _markers.clear();

      int counter = 0;
      var iconColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

      for (var loc in locations) {
        if (loc['type'] == 'Mixed recycling'){ iconColor = BitmapDescriptor.defaultMarkerWithHue(210.0);}
        else if (loc['type'] == 'Plastic recycling'){ iconColor = BitmapDescriptor.defaultMarkerWithHue(359.0);}
        else if (loc['type'] == 'Glass recycling'){ iconColor = BitmapDescriptor.defaultMarkerWithHue(178.0);}
        else if (loc['type'] == 'Can recycling'){ iconColor = BitmapDescriptor.defaultMarkerWithHue(263.0);}
        else if (loc['type'] == 'Food recycling'){ iconColor = BitmapDescriptor.defaultMarkerWithHue(42.0);}

        final marker = Marker(
          markerId: MarkerId(counter.toString()),
          position: LatLng(loc['lat'], loc['long']),
          draggable: false,
          icon: iconColor,
          
          infoWindow: InfoWindow(
            onTap: () {
           return Scaffold(
             body: Text("helo"),
           );
        }),
          
        );
        _markers[counter.toString()] = marker;
        counter++;
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
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        },
        tooltip: 'Home',
        child: Icon(Icons.home),
        backgroundColor: Colors.green.shade300,
      ),
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage();

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

/* page to render the calendar page */
class _CalendarPageState extends State<CalendarPage> {
  List data;
  String htmlBody = "";

  Future request() async {
    String qstring = placemark[0]
        .postalCode
        .replaceFirst(' ', '+')
        .substring(0, placemark[0].postalCode.length - 1);
    String geoLocationURL =
        'https://exeter.gov.uk/repositories/hidden-pages/address-finder/?qtype=bins&term=' +
            qstring;

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
    if (htmlBody != "") {
      return Scaffold(
        appBar: AppBar(
          title: Text("Recycle It"),
          backgroundColor: Colors.green.shade300,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Html(
                data: htmlBody,
                padding: EdgeInsets.all(20.0),
              )
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
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
            valueColor:
                new AlwaysStoppedAnimation<Color>(Colors.green.shade300),
          ),
        ),
      );
    }
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
  int htmlBody;
  List stats;
  int stats_total = 0;

  Future<void> request() async {
    var coll = db.collection('data');
    stats = [{'name':'plastic','num':await coll.count({"uuid":uuid,"type":"Plastic recycling"})},
    {'name':'food','num':await coll.count({"uuid":uuid,"type":"Food recycling"})},
    {'name':'mixed','num':await coll.count({"uuid":uuid,"type":"Mixed recycling"})},
    {'name':'can','num':await coll.count({"uuid":uuid,"type":"Can recycling"})},
    {'name':'glass','num':await coll.count({"uuid":uuid,"type":"Glass recycling"})}];
    
    for(int c = 0;c <stats.length;c++){
      stats_total += stats[c]['num'];
    }
    if (stats_total == 0){
      stats_total = 1;
    }
    setState(() {
      stats;
      stats_total;
      });
  }
  

  @override
  void initState() {
    super.initState();
    request();
  }

  @override
  Widget build(BuildContext context) {
    if (stats_total != 0) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Recycle It"),
          backgroundColor: Colors.green.shade300,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              for(int stat =0; stat<stats.length;stat++)
                ShowUp(
                    child: SizedBox(
                      
                      width: 150,
                      height: 50,
                      child: LiquidLinearProgressIndicator(
                        value: stats[stat]['num']/stats_total,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(Colors.green.shade300),
                        direction: Axis.horizontal,
                        center: Text(
                          stats[stat]['name'] + " - " + stats[stat]['num'].toString()
                        ),
                        borderColor: Colors.grey.shade200,
                        borderWidth: 2.0,
                      ),
                    ),
                    delay: 1250,
                    bottom: 0.5,
                  )

              
              ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
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
            valueColor:
                new AlwaysStoppedAnimation<Color>(Colors.green.shade300),
          ),
        ),
      );
    }
  }
}