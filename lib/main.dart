import 'dart:async';
import 'dart:ffi';

import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter/material.dart';
import 'package:geocoder/services/distant_google.dart';
import 'package:html/dom_parsing.dart';
import 'package:html/parser.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_place/google_place.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoder/geocoder.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;
import 'package:timezone_utc_offset/timezone_utc_offset.dart';
import 'package:intl/intl.dart';
import 'package:web_scraper/web_scraper.dart';

void main() => runApp(MaterialApp(
  home: MyApp(),
)
);

class MosquePlace {
  final String name;
  final String address;
  final String website;
  final List<Photo> photos;
  final List<String> prayerTimes;

  const MosquePlace(this.name, this.address, this.website, this.photos, this.prayerTimes);
}


class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late GoogleMapController mapController;
  var googlePlace = GooglePlace("AIzaSyDwZlTdj8G2gQP5ZK7kE2iq1ofan9RswrE");
  final LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );
  List<Marker> _markers = <Marker>[];
  Map mosqueData = Map<String, List<dynamic>>();
  final _navKey = GlobalKey<NavigatorState>();

  Future<void> _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    Location pos;

    StreamSubscription<Position> positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) async {
              pos = Location(lat: position.latitude, lng: position.longitude);
              mapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: LatLng(position.latitude, position.longitude),zoom: 11),
                ),
              );

              final mosquesNearby = await googlePlace.search.getNearBySearch(
                  pos, 6000,
                  type: "mosque");

              for (var mosque in mosquesNearby.results) {
                final mosqueDetails = await googlePlace.details.get(mosque.placeId);
                var mosqueLat = mosque.geometry.location.lat;
                var mosqueLng = mosque.geometry.location.lng;
                final mosqueCoords = adhan.Coordinates(mosqueLat, mosqueLng);
                final date = adhan.DateComponents.from(DateTime.now());
                var params = adhan.CalculationMethod.other.getParameters();

                Future<String> getCountryName() async {
                  final mosqueCds = new Coordinates(mosqueLat, mosqueLng);
                  var addresses = await Geocoder.local.findAddressesFromCoordinates(mosqueCds);
                  var first = addresses.first;
                  return first.countryName; // this will return country name
                }

                String countryName = await getCountryName();
                if (countryName == "United Arab Emirates") {
                  params = adhan.CalculationMethod.dubai.getParameters();
                }
                else if (countryName == "Kuwait") {
                  params = adhan.CalculationMethod.kuwait.getParameters();
                }
                else if (countryName == "Egypt") {
                  params = adhan.CalculationMethod.egyptian.getParameters();
                }
                else if (countryName == "Pakistan") {
                  params = adhan.CalculationMethod.karachi.getParameters();
                }
                else if (countryName == "Qatar") {
                  params = adhan.CalculationMethod.qatar.getParameters();
                }
                else if (countryName == "Singapore") {
                  params = adhan.CalculationMethod.singapore.getParameters();
                }
                else if (countryName == "United States" || countryName == "Canada"
                    || countryName == "Mexico") {
                  params = adhan.CalculationMethod.north_america.getParameters();
                }

                final timezone = tzmap.latLngToTimezoneString(mosqueLat, mosqueLng);
                final prayerTimesResult = adhan.PrayerTimes(mosqueCoords, date, params, utcOffset: getTimezoneUTCOffset(timezone));
                List<String> prayerTimes = [
                  DateFormat.Hm().format(prayerTimesResult.fajr),
                  DateFormat.Hm().format(prayerTimesResult.dhuhr),
                  DateFormat.Hm().format(prayerTimesResult.asr),
                  DateFormat.Hm().format(prayerTimesResult.maghrib),
                  DateFormat.Hm().format(prayerTimesResult.isha)
                ];

                //web scraping here
                final webScraper = WebScraper(mosqueDetails.result.website);
                try {
                  if (await webScraper.loadWebPage('')) {
                    String elements = webScraper.getPageContent();
                    print(elements);
                  }
                }
                catch(e) {
                  //do nothing
                }


                List<dynamic> data =
                [
                  mosqueDetails.result.formattedAddress,
                  mosqueDetails.result.website,
                  mosqueLat,
                  mosqueLng,
                  mosque.photos,
                  prayerTimes
                ];
                mosqueData[mosqueDetails.result.name] = data;
                //data: [addr, website, lat, lng, photos, prayerTimes]
              }


              setState(() {
                _markers.clear();
                for (var key in mosqueData.keys) {
                  //use placeId to get data on mosque location
                  //final mosqueDetails = await googlePlace.details.get(mosque.placeId);
                  _markers.add(
                      Marker(
                        markerId: MarkerId(key),
                        position: LatLng(mosqueData[key][2], mosqueData[key][3]),
                        infoWindow: InfoWindow(
                          title: key,
                          snippet: mosqueData[key][0],
                        ),
                        onTap: () async {
                          //if tapped, show screen containing mosque name, address, and prayer times

                          MosquePlace location = new MosquePlace(key, mosqueData[key][0], mosqueData[key][1], mosqueData[key][4], mosqueData[key][5]);
                          //issues with trying to use Navigator right now
                          Navigator.of(context).push(new MaterialPageRoute(builder:
                              (BuildContext context) => new DetailScreen(mosquePlace: location)));
                        }
                      )
                  );
                }
              });
        });


  }

  @override
  Widget build(BuildContext context){

    print(Set<Marker>.of(_markers).toString());

    return MaterialApp(
      home: Scaffold(
        body: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: const CameraPosition(
            target: LatLng(45.521563, -122.677433),
            zoom: 11.0,
          ),
          myLocationEnabled: true,
          markers: Set<Marker>.of(_markers),
        ),
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  // In the constructor, require a Todo.
  const DetailScreen({Key? key, required this.mosquePlace}) : super(key: key);

  // Declare a field that holds the Todo.
  final MosquePlace mosquePlace;

  @override
  Widget build(BuildContext context) {
    // Use the Todo to create the UI.
    return Scaffold(
      appBar: AppBar(
        title: Text(mosquePlace.name),
      ),
      body: Column(
        children: <Widget>[
          new Padding(
            padding: const EdgeInsets.all(8.0),
            child: new Container(
              color: Colors.white,
              height: 100.0,
            ),
          ),
          Text(mosquePlace.address),
          Text("Fajr: ${mosquePlace.prayerTimes[0]}\n"
              "Dhuhr: ${mosquePlace.prayerTimes[1]}\n"
              "Asr: ${mosquePlace.prayerTimes[2]}\n"
              "Maghrib: ${mosquePlace.prayerTimes[3]}\n"
              "Isha: ${mosquePlace.prayerTimes[4]}")
        ],
      ),
      
    );
  }
}
