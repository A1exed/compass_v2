import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import 'Database.dart';
import 'VisitModel.dart';
import 'app_localizations.dart';

void main() {
  runApp(Compass());
}

class Compass extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: [
        const Locale('en', 'US'),
        const Locale('ru', 'RU'),
      ],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode &&
              supportedLocale.countryCode == locale.countryCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      title: 'Compass',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      home: CompassPage(title: 'Compass'),
    );
  }
}

class CompassPage extends StatefulWidget {
  CompassPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _CompassPageState createState() => _CompassPageState();
}

class _CompassPageState extends State<CompassPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('compass')),
        actions: <Widget>[new IconButton(icon: new Icon(Icons.info_outline_rounded), onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Information()),
          );
        },),],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(child: _buildCompass(),),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Map()),
          );
        },
        child: Icon(Icons.navigation_outlined),
      ),
    );
  }
  Widget _buildCompass() {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error reading heading: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }

        int direction = snapshot.data.heading.round();

        return Material(
          clipBehavior: Clip.antiAlias,
          elevation: 4.0,
          child: Container(
            padding: EdgeInsets.all(16.0),
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(top: 50),
              child: Column(
                children: [
                  Text(
                    '$direction°',
                    style: Theme.of(context).textTheme.headline5,
                  ),
                  Image.asset('image/cursor.png', width: MediaQuery.of(context).size.width / 15,),
                  Transform.rotate(
                    angle: ((direction ?? 0) * (math.pi / 180) * -1),
                    child: Image.asset('image/compass_img.png', width: MediaQuery.of(context).size.width / 1.2,),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class Map extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: [
        const Locale('en', 'US'),
        const Locale('ru', 'RU'),
      ],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode &&
              supportedLocale.countryCode == locale.countryCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      title: 'Compass',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      home: MapPage(title: 'Map'),
    );
  }
}

class MapPage extends StatefulWidget {
  MapPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {

  Completer<GoogleMapController> _controller = Completer();

  StreamSubscription positionStream;

  Position _position;

  static final CameraPosition _initialPosition = CameraPosition(
    target: LatLng(53.42796133580664, 50.085749655962),
    zoom: 15.0,
  );

  Set<Polyline> polylineList = Set<Polyline>();

  List<LatLng> points = List();

  bool askingPermission = false;

  @override
  void initState() {
    super.initState();
    this.getLocationPermission();
    _position = Position();
    updateLocation();
    positionStream = Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _position = position;
        _updateCamera();
        points.add(LatLng(_position.latitude, _position.longitude));
        polylineList = {
          new Polyline(
            polylineId: PolylineId(_position.toString()),
            color: Colors.amber,
            width: 4,
            points: points,
          )
        };
      });
    });
  }

  void updateLocation() async {
    Position newPosition = await Geolocator.getCurrentPosition().timeout(new Duration(seconds: 5));

    setState(() {
      _position = newPosition;
    });
  }

  Future<bool> getLocationPermission() async {
    setState(() {
      this.askingPermission = true;
    });
    bool result;
    final Location location = Location();
    await location.getLocation();
    try {
      if (await Permission.location.isGranted)
        result = true;
      else {
        result = await Permission.location.isGranted;
      }
    } catch (log, trace) {
      result = false;
      print('getLocationPermission/log: $log');
      print('getLocationPermission/trace: $trace');
    } finally {
      setState(() {
        this.askingPermission = false;
      });
    }
    return result;
  }

  Future<void> _updateCamera() async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(new CameraPosition(target: LatLng(_position.latitude, _position.longitude), zoom: 15.0)));
    setState(() {

    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: new IconButton(icon: new Icon(Icons.arrow_back_rounded), onPressed: () {
          positionStream.pause();
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Compass()),
          );
        }, ),
        title: Text(AppLocalizations.of(context).translate('map')),
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        myLocationEnabled: true,
        polylines: polylineList,
        initialCameraPosition: _initialPosition,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
      ),
    );
  }

}

class Information extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: [
        const Locale('en', 'US'),
        const Locale('ru', 'RU'),
      ],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode &&
              supportedLocale.countryCode == locale.countryCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      title: 'Compass',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      home: InformationPage(title: 'Information'),
    );
  }
}

class InformationPage extends StatelessWidget {
  InformationPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: new IconButton(icon: new Icon(Icons.arrow_back_rounded), onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Compass()),
          );
        },),
        title: Text(AppLocalizations.of(context).translate('information')),
      ),
      body: Column(
        children: <Widget>[
          Container(height: MediaQuery.of(context).size.height * 0.003, width: MediaQuery.of(context).size.width, color: Colors.amber,),
          FlatButton(
            child: Text(AppLocalizations.of(context).translate('db'), style: Theme.of(context).textTheme.headline6,),
            minWidth: double.infinity,
            height: MediaQuery.of(context).size.height * 0.08,
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DB()),
              );
            },
          ),
          Container(height: MediaQuery.of(context).size.height * 0.003, width: MediaQuery.of(context).size.width, color: Colors.amber,),
          FlatButton(
            child: Text(AppLocalizations.of(context).translate('logIn'), style: Theme.of(context).textTheme.headline6,),
            minWidth: double.infinity,
            height: MediaQuery.of(context).size.height * 0.08,
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Login()),
              );
            },
          ),
          Container(height: MediaQuery.of(context).size.height * 0.003, width: MediaQuery.of(context).size.width, color: Colors.amber,),
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.59),
            child: Column(
              textDirection: TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.start,
              verticalDirection: VerticalDirection.down,
              children: <Widget>[
                Container(height: MediaQuery.of(context).size.height * 0.003, width: MediaQuery.of(context).size.width, color: Colors.amber,),
                Container(padding: EdgeInsets.only(left: 50), child: Text(AppLocalizations.of(context).translate('developers'), style: TextStyle(fontWeight: FontWeight.bold,), textDirection: TextDirection.ltr,),),
                Container(padding: EdgeInsets.only(left: 30), child: Text(AppLocalizations.of(context).translate('pashin'), textDirection: TextDirection.ltr,),),
                Container(padding: EdgeInsets.only(left: 30), child: Text(AppLocalizations.of(context).translate('karpov'), textDirection: TextDirection.ltr,),),
                Container(padding: EdgeInsets.only(left: 50), child: Text(AppLocalizations.of(context).translate('contact'), style: TextStyle(fontWeight: FontWeight.bold), textDirection: TextDirection.ltr,),),
                Container(padding: EdgeInsets.only(left: 30), child: Text(AppLocalizations.of(context).translate('mail'), textDirection: TextDirection.ltr,),),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: [
        const Locale('en', 'US'),
        const Locale('ru', 'RU'),
      ],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode &&
              supportedLocale.countryCode == locale.countryCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      title: 'Compass',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      home: DBPage(title: 'DB'),
    );
  }
}

class DBPage extends StatefulWidget {
  DBPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _DBPageState createState() => _DBPageState();
}

class _DBPageState extends State<DBPage> {

  List<Visit> listVisits = [
    Visit(city: "Samara", count: 163),
  ];

  final idController = TextEditingController();
  final cityController = TextEditingController();
  final countController = TextEditingController();

  @override
  void dispose() {
    idController.dispose();
    cityController.dispose();
    countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: new IconButton(icon: new Icon(Icons.arrow_back_rounded), onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Information()),
          );
        }, ),
        title: Text(AppLocalizations.of(context).translate('db')),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FutureBuilder<List<Visit>>(
            future: DBProvider.db.getAllVisits(),
            builder: (BuildContext context, AsyncSnapshot<List<Visit>> snapshot) {
              if (snapshot.hasData) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height * 0.35,
                  child: ListView.builder(
                    itemCount: snapshot.data.length,
                    itemBuilder: (BuildContext context, int index) {
                      Visit item = snapshot.data[index];
                      return Dismissible(
                        key: UniqueKey(),
                        background: Container(color: Colors.red),
                        onDismissed: (direction) {
                          DBProvider.db.deleteVisit(item.id);
                        },
                        child: ListTile(
                          title: Text(item.city),
                          leading: Text(item.id.toString()),
                          trailing: Text(item.count.toString()),
                        ),
                      );
                    },
                  ),
                );
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Container(height: MediaQuery.of(context).size.height * 0.003, width: MediaQuery.of(context).size.width, color: Colors.amber,),
              Row(
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.only(left: 20, right: 5),
                    width: MediaQuery.of(context).size.width * 0.2,
                    height: MediaQuery.of(context).size.height * 0.08,
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      controller: idController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).translate('id'),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.only(left: 5, right: 5),
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: MediaQuery.of(context).size.height * 0.08,
                    child: TextFormField(
                      controller: cityController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).translate('city'),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.only(left: 5, right: 20),
                    width: MediaQuery.of(context).size.width * 0.2,
                    height: MediaQuery.of(context).size.height * 0.08,
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      controller: countController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).translate('count'),
                      ),
                    ),
                  ),
                ],
              ),
              Container(height: MediaQuery.of(context).size.height * 0.003, width: MediaQuery.of(context).size.width, color: Colors.amber,),
              Row(
                children: <Widget>[
                  FlatButton(
                    child: Text(AppLocalizations.of(context).translate('insert'), style: Theme.of(context).textTheme.headline6,),
                    minWidth: MediaQuery.of(context).size.width * 0.331,
                    height: MediaQuery.of(context).size.height * 0.08,
                    onPressed: () {
                      DBProvider.db.newVisit(Visit(city: cityController.text, count: int.parse(countController.text)));
                      DBProvider.db.getAllVisits();
                      setState(() {

                      });
                    },
                  ),
                  Container(height: MediaQuery.of(context).size.height * 0.08, width: MediaQuery.of(context).size.width * 0.0035, color: Colors.amber,),
                  FlatButton(
                    child: Text(AppLocalizations.of(context).translate('update'), style: Theme.of(context).textTheme.headline6,),
                    minWidth: MediaQuery.of(context).size.width * 0.331,
                    height: MediaQuery.of(context).size.height * 0.08,
                    onPressed: () {
                      DBProvider.db.updateVisit(Visit(id: int.parse(idController.text), city: cityController.text, count: int.parse(countController.text)));
                      DBProvider.db.getAllVisits();
                      setState(() {

                      });
                    },
                  ),
                  Container(height: MediaQuery.of(context).size.height * 0.08, width: MediaQuery.of(context).size.width * 0.0035, color: Colors.amber,),
                  FlatButton(
                    child: Text(AppLocalizations.of(context).translate('delete'), style: Theme.of(context).textTheme.headline6,),
                    minWidth: MediaQuery.of(context).size.width * 0.331,
                    height: MediaQuery.of(context).size.height * 0.08,
                    onPressed: () {
                      DBProvider.db.deleteVisit(int.parse(idController.text));
                      DBProvider.db.getAllVisits();
                      setState(() {

                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Login extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: [
        const Locale('en', 'US'),
        const Locale('ru', 'RU'),
      ],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode &&
              supportedLocale.countryCode == locale.countryCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      title: 'Compass',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      home: LoginPage(title: 'Log in'),
    );
  }
}

class LoginPage extends StatefulWidget {
  LoginPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  String username;
  String password;
  bool resultLogin;

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: new IconButton(icon: new Icon(Icons.arrow_back_rounded), onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Information()),
          );
        }, ),
        title: Text(AppLocalizations.of(context).translate('logIn')),
      ),
      body: Builder(
        builder: (context) => Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.08,
              child: TextFormField(
                controller: usernameController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).translate('username'),
                ),
              ),
            ),
            Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.08,
              child: TextFormField(
                controller: passwordController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).translate('password'),
                ),
              ),
            ),
            RaisedButton(
              child: Text(AppLocalizations.of(context).translate('signIn')),
              onPressed: () async {
                username = usernameController.text;
                password = passwordController.text;
                if (username != null && password != null) {
                  var url = 'http://192.168.43.59:8080/login?username=$username&password=$password';
                  await http.Client().get(url).then((response) {
                    var data = json.decode(response.body);
                    resultLogin = data['loginResult'];
                    if (resultLogin && resultLogin != null) {
                      _showToastWelcome(context);
                    } else {
                      _showToastFailed(context);
                    }
                  }).catchError((error) {
                    _showToastSleep(context);
                  });
                }
                setState(() {});
              },
            ),
          ],
        ),
      ),),
    );
  }

  void _showToastSleep(BuildContext context) {
    final scaffold = Scaffold.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).translate('connErr')),
      )
    );
  }

  void _showToastWelcome(BuildContext context) {
    final scaffold = Scaffold.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).translate('welcome')),
      )
    );
  }

  void _showToastFailed(BuildContext context) {
    final scaffold = Scaffold.of(context);
    scaffold.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('logInErr')),
        )
    );
  }
}