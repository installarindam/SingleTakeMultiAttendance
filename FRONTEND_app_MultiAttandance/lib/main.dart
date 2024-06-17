import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';

import 'addstudent.dart';

List<CameraDescription> cameras = [];
late String baseUrl;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://prxgvtqbxkzljeyjrwst.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InByeGd2dHFieGt6bGpleWpyd3N0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcxMzg4NjY5MywiZXhwIjoyMDI5NDYyNjkzfQ.1b6-zNoFIwCrKIL73kwsIifEQGpdyzFT_ncKwlD6Pbg',
  );
  final supabase = Supabase.instance.client;
  final response = await supabase.from('baseurl').select('url').single();

  if (response != null) {
    baseUrl = response['url'] as String;
    print("base_url = $baseUrl");
  }

  try {
    cameras = await availableCameras();
  } catch (e) {
    print('Error initializing cameras: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: ThemeData(
        primaryColor: Colors.deepPurple,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Colors.deepPurpleAccent,
        ),
      ),
      home: CameraScreen(),
      routes: {
        '/checkAttendance': (context) => CheckAttendanceScreen(),
      },
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isRecording = false;
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _currentRecordingTime = '';
  late VideoPlayerController _videoPlayerController;
  bool _isVideoPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
    );
    _initializeCameraController();
    _stopwatch = Stopwatch();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isRecording) {
        setState(() {
          _currentRecordingTime = _getRecordingTime();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer.cancel();
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
    }
    _videoPlayerController.dispose();
    super.dispose();
  }

  void _initializeCameraController() {
    _initializeControllerFuture = _controller.initialize().catchError((error) {
      print('Error initializing camera controller: $error');
    });
  }

  void _startStopRecording() async {
    if (!_isRecording) {
      try {
        await _initializeControllerFuture;
        await _controller.startVideoRecording();
        _stopwatch.start();
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        print(e);
      }
    } else {
      try {
        _stopwatch.stop();
        XFile videoFile = await _controller.stopVideoRecording();
        print('Video recorded: ${videoFile.path}');
        _stopwatch.reset(); // Reset the stopwatch
        _showVideoPreview(videoFile.path);
        setState(() {
          _isRecording = false;
          _currentRecordingTime = '';
        });
      } catch (e) {
        print(e);
      }
    }
  }

  String _getRecordingTime() {
    Duration duration = _stopwatch.elapsed;
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showVideoPreview(String videoPath) {
    _videoPlayerController = VideoPlayerController.file(File(videoPath))
      ..initialize().then((_) {
        setState(() {
          _isVideoPlaying = true;
        });
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Container(
                width: double.maxFinite,
                height: 300,
                child: AspectRatio(
                  aspectRatio: _videoPlayerController.value.aspectRatio,
                  child: VideoPlayer(_videoPlayerController),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {

                    showDialog(
                      context: context,
                      barrierDismissible: false, // Prevent dialog from being dismissed by tapping outside
                      builder: (BuildContext context) {
                        return WillPopScope(
                          onWillPop: () async {
                            // Prevent back button press during animation
                            return false;
                          },
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                    );

                    try {
                      final supabase = Supabase.instance.client;
                      final response = await supabase.from('baseurl').select('url').single();
                      var burl;
                      if (response != null) {
                        final String? baseUrl = response['url'] as String?;
                        burl = response['url'] as String?;
                        print("base_url = $baseUrl");
                      }

                    // Prepare the request data
                    var url = baseUrl + "/advpredict";
                    var request = http.MultipartRequest('POST', Uri.parse(url));

                    // Add the secret code to the Authorization header
                    request.headers['Authorization'] =
                    'Bearer xmqoqxTzdyBsZw3YI0ZZGuqVI6dDWaVLfBA+69Kbcp0=';
                    request.files
                        .add(await http.MultipartFile.fromPath('file', videoPath));

                    // Send the request
                    var qresponse = await request.send();

                    // Handle the response
                    if (qresponse.statusCode == 200) {
                      // Parse the response JSON

                      // Close the loading dialog
                      Navigator.of(context).pop();

                      print("video upload success");
                      var responseData =
                      await qresponse.stream.bytesToString();
                      var jsonResponse = jsonDecode(responseData);
                      print("success mesage");
                      print(jsonResponse);
                      List<dynamic> facesList = jsonResponse['unique_faces'];
                      _showFacesDialog(facesList);
                      Fluttertoast.showToast(
                        msg: "Video uploaded successfully",
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.green,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                      // Do something with jsonResponse
                    } else {
                      // Handle errors
                      Navigator.of(context).pop();
                      print('Request failed with status: ${qresponse.statusCode}');
                      Fluttertoast.showToast(
                        msg: "Video upload Failed",
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.redAccent,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    }
                    } catch (e) {
                      print(e);
                      Fluttertoast.showToast(
                        msg: "An error occurred",
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.redAccent,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    }
                  },
                  child: Text('Submit'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _videoPlayerController.pause();
                    _videoPlayerController.seekTo(Duration.zero);
                    Navigator.of(context).pop();
                    setState(() {
                      _isVideoPlaying = false;
                    });
                  },
                  child: Text('Close'),
                ),
              ],
            );
          },
        ).then((_) {
          // Ensure that video player is disposed after dialog is closed
          _videoPlayerController.dispose();
        });
        _videoPlayerController.play();
      });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Exit App?'),
            content: Text('Do you want to exit the app?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Yes'),
              ),
            ],
          ),
        ) ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Camera'),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              DrawerHeader(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/a.png"), // Replace with your image path
                    fit: BoxFit.cover, // Adjust fit as needed (cover, fill, etc.)
                  ),
                ),
                child: Text(
                  'MultiAttendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
              ListTile(
                title: Text('Add Student'),
                onTap: () async {
                  // Handle the "Add Student" action here
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddStudentScreen()),
                  ); // Close the drawer
                  _initializeCameraController(); // Reinitialize the camera controller after returning
                },
              ),
              ListTile(
                title: Text('Check Attendance'),
                onTap: () {
                  Navigator.of(context).pushNamed('/checkAttendance');
                },
              ),
              // Add more options as needed
            ],
          ),
        ),
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
        floatingActionButton: FloatingActionButton(
          onPressed: _startStopRecording,
          child: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: BottomAppBar(
          color: Colors.transparent,
          child: Container(
            height: 60,
            child: Center(
              child: Text(
                _isRecording ? 'Recording: $_currentRecordingTime' : 'Tap to start recording',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }



  void _showFacesDialog(List facesList) {
    // Map to keep track of toggled states for each face
    Map<String, bool> faceToggles = { for (var face in facesList) face: true };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Detected Faces'),
              content: Container(
                width: double.maxFinite,
                height: 200,
                child: ListView.builder(
                  itemCount: facesList.length,
                  itemBuilder: (context, index) {
                    String face = facesList[index];
                    return ListTile(
                      title: Text(face),
                      trailing: Switch(
                        value: faceToggles[face]!,
                        onChanged: (bool value) {
                          setState(() {
                            faceToggles[face] = value;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Get the toggled-on faces
                    List<String> presentFaces = faceToggles.entries
                        .where((entry) => entry.value)
                        .map((entry) => entry.key)
                        .toList();

                    // Format the current date in YYYY-MM-DD format
                    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

                    // Convert the list of faces into a comma-separated string
                    String namesString = presentFaces.join(',');

                    // Prepare the data to be inserted
                    final supabase = Supabase.instance.client;
                    try {
                      print("names "+namesString);
                      await supabase.from('attendance').insert({
                        'date': currentDate,
                        'names': namesString,
                      });
                      Fluttertoast.showToast(
                        msg: "Attendance recorded successfully",
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.green,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    } catch (e) {
                      print(e);
                      Fluttertoast.showToast(
                        msg: "An error occurred",
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.redAccent,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    }

                    Navigator.of(context).pop();
                  },
                  child: Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }



}
class CheckAttendanceScreen extends StatefulWidget {
  @override
  _CheckAttendanceScreenState createState() => _CheckAttendanceScreenState();
}

class _CheckAttendanceScreenState extends State<CheckAttendanceScreen> {
  Map<String, int> attendanceMap = {};
  int totalClasses = 0;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.from('attendance').select();
      if (response !=null) {
        print("attendace data");
        print(response);
        List<Map<String, dynamic>> data = response as List<Map<String, dynamic>>;
        _calculateAttendance(data);
      } else {
        //print('Error fetching attendance data: ${response.error?.message}');
      }
    } catch (e) {
      print('Error fetching attendance data: $e');
    }
  }

  void _calculateAttendance(List<Map<String, dynamic>> data) {
    Map<String, int> attendanceCount = {};
    int total = 0;
    Set<String> uniqueClasses = {};
    for (var entry in data) {
      String names = entry['names'];
      List<String> nameList = names.split(',');

      for (var name in nameList) {
        attendanceCount[name] = (attendanceCount[name] ?? 0) + 1;
        uniqueClasses.add(name);
      }
    }
    setState(() {
      attendanceMap = attendanceCount;
      totalClasses = uniqueClasses.length;
      total=totalClasses;
    });
  }

  double calculatePercentage(int attended, int total) {
    return (attended / total) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Report'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8.0, 16.0, 8.0),
            child: Chip(
              label: Text('Total Classes: $totalClasses'),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text(
                'Attendance Report',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              DataTable(
                columns: [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Percentage')),
                ],
                rows: attendanceMap.entries.map<DataRow>((entry) {
                  String name = entry.key;
                  int attended = entry.value ?? 0;
                  double percentage = calculatePercentage(attended, totalClasses);
                  return DataRow(
                    cells: [
                      DataCell(Text(name)),
                      DataCell(
                        Text(
                          '${percentage.toStringAsFixed(2)}%',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}