import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:geocoder/geocoder.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

void main() => runApp(WeatherApp());

class WeatherApp extends StatefulWidget {
  @override
  _WeatherAppState createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  int temperature;
  String location = '';
  int woeid = 0;
  String weather = 'clear';
  String abbrevation = '';
  String errorMessage = '';

  String searchApiUrl =
      'https://www.metaweather.com/api/location/search/?query=';
  String locationApiUrl = 'https://www.metaweather.com/api/location/';

  Position currentPosition;

  var minTemperatureForecast = new List(7);
  var maxTemperatureForecast = new List(7);
  var abbreviationForecast = new List(7);
  @override
  void initState() {
    super.initState();
    //fetchLocation();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    await Geolocator.getCurrentPosition()
        .then((value) => {currentPosition = value});

    final coordinates =
        Coordinates(currentPosition.latitude, currentPosition.longitude);
    var addresses =
        await Geocoder.local.findAddressesFromCoordinates(coordinates);
    var first = addresses.first;

    onTextFieldSubmitted(first.locality);
  }

  Future<void> onTextFieldSubmitted(String input) async {
    await fetchSearch(input);
    await fetchLocation();
    await fetchLocationDay();
  }

  Future<void> fetchSearch(String input) async {
    try {
      var searchResult = await http.get(searchApiUrl + input);
      var result = json.decode(searchResult.body)[0];

      setState(() {
        location = result["title"];
        woeid = result["woeid"];
        errorMessage = "";
      });
    } catch (error) {
      setState(() {
        errorMessage =
            "Sorry, we don't have data about this city. Try another one..";
      });
    }
  }

  Future<void> fetchLocation() async {
    var locationResult = await http.get(locationApiUrl + woeid.toString());
    var result = json.decode(locationResult.body);
    var consolidatedWeather = result["consolidated_weather"];
    var data = consolidatedWeather[0];

    setState(() {
      temperature = data["the_temp"].round();
      weather = data["weather_state_name"].replaceAll(' ', '').toLowerCase();
      abbrevation = data["weather_state_abbr"];
    });
  }

  Future<void> fetchLocationDay() async {
    var today = DateTime.now();
    for (var i = 0; i < 7; i++) {
      var locationDayResult = await http.get(locationApiUrl +
          woeid.toString() +
          "/" +
          DateFormat('y/M/d')
              .format(today.add(Duration(days: i + 1)))
              .toString());
      var result = json.decode(locationDayResult.body);
      var data = result[0];

      setState(() {
        minTemperatureForecast[i] = data["min_temp"].round();
        maxTemperatureForecast[i] = data["max_temp"].round();
        abbreviationForecast[i] = data["weather_state_abbr"];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/$weather.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.dstATop,
            ),
          ),
        ),
        child: temperature == null
            ? Center(child: CircularProgressIndicator())
            : Scaffold(
                resizeToAvoidBottomPadding: false,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0.0,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 20.0),
                      child: GestureDetector(
                        onTap: getCurrentLocation,
                        child: Icon(
                          Icons.location_city,
                          size: 36.0,
                        ),
                      ),
                    )
                  ],
                ),
                backgroundColor: Colors.transparent,
                body: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        Center(
                          child: Image.network(
                            'https://www.metaweather.com/static/img/weather/png/$abbrevation.png',
                            width: 100,
                          ),
                        ),
                        Center(
                          child: Text(
                            temperature.toString() + ' °C',
                            style:
                                TextStyle(color: Colors.white, fontSize: 60.0),
                          ),
                        ),
                        Center(
                          child: Text(
                            location,
                            style:
                                TextStyle(color: Colors.white, fontSize: 40.0),
                          ),
                        ),
                      ],
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: abbreviationForecast[6] == null &&
                              maxTemperatureForecast[6] == null &&
                              minTemperatureForecast[6] == null
                          ? Center(
                              child: CircularProgressIndicator(),
                            )
                          : Row(
                              children: [
                                for (var i = 0; i < 7; i++)
                                  forecastElement(
                                    i + 1,
                                    abbreviationForecast[i],
                                    maxTemperatureForecast[i],
                                    minTemperatureForecast[i],
                                  ),
                              ],
                            ),
                    ),
                    Column(
                      children: <Widget>[
                        Container(
                          width: 300,
                          child: TextField(
                            onSubmitted: (String input) {
                              onTextFieldSubmitted(input);
                            },
                            style: TextStyle(color: Colors.white, fontSize: 25),
                            decoration: InputDecoration(
                              hintText: 'Search another location...',
                              hintStyle: TextStyle(
                                  color: Colors.white, fontSize: 18.0),
                              prefixIcon:
                                  Icon(Icons.search, color: Colors.white),
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.only(right: 32.0, left: 32.0),
                          child: Text(errorMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: Platform.isAndroid ? 15.0 : 20.0)),
                        )
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

Widget forecastElement(
    daysFromNow, abbrevation, maxTemperature, minTemperature) {
  var now = DateTime.now();
  var oneDayfromNow = now.add(Duration(days: daysFromNow));
  return Padding(
    padding: const EdgeInsets.only(left: 16.0),
    child: Container(
      decoration: BoxDecoration(
        color: Color.fromRGBO(205, 212, 228, 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              DateFormat.E().format(oneDayfromNow),
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
              ),
            ),
            Text(
              DateFormat.MMMd().format(oneDayfromNow),
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Image.network(
                'https://www.metaweather.com/static/img/weather/png/$abbrevation.png',
                width: 50,
              ),
            ),
            Text(
              'High: ' + maxTemperature.toString() + ' °C',
              style: TextStyle(color: Colors.white, fontSize: 20.0),
            ),
            Text(
              'Low: ' + minTemperature.toString() + ' °C',
              style: TextStyle(color: Colors.white, fontSize: 20.0),
            ),
          ],
        ),
      ),
    ),
  );
}
