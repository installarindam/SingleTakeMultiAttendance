import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'main.dart';
import 'package:fluttertoast/fluttertoast.dart';


class AddStudentScreen extends StatefulWidget {
  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  List<XFile> _capturedImages = [];
  TextEditingController _textInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
    );
    await _controller.initialize();
    setState(() {
      _initializeControllerFuture = _controller.initialize();
    });
  }

  void _captureImage() async {
    try {
      final XFile imageFile = await _controller.takePicture();
      setState(() {
        _capturedImages.add(imageFile);
      });
      if (_capturedImages.length >= 5) {
        // If 5 images are captured, stop capturing further images
        _showImagesDialog();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _showImagesDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Captured Images'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 300.0,
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _capturedImages.length,
                    itemBuilder: (context, index) {
                      return Image.file(
                        File(_capturedImages[index].path),
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
                SizedBox(height: 16), // Add some space between the GridView and the input field
                TextField(
                  controller: _textInputController,
                  decoration: InputDecoration(
                    labelText: 'Enter some text',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Reset captured images count and close dialog
                setState(() {
                  _capturedImages.clear();
                  _textInputController.clear(); // Clear the text input
                });
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Check if the text input is not empty
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
                  final response = await supabase
                      .from('baseurl')
                      .select('url')
                      .single();
                  var burl;
                  if (response != null) {
                    final String? baseUrl = response['url'] as String?;
                    burl = response['url'] as String?;
                    print("base_url = $baseUrl");
                  }
                  String text = _textInputController.text;
                  if (text.isNotEmpty && _capturedImages.isNotEmpty) {
                    // Prepare the request data
                    var url = burl + "/scr_add_video_face";
                    var request = http.MultipartRequest('POST', Uri.parse(url));
                    request.fields['id'] = text; // Set the student ID
                    for (var image in _capturedImages) {
                      // Add each captured image to the request
                      request.files.add(await http.MultipartFile.fromPath(
                          'images', image.path));
                    }

                    // Add the secret code to the Authorization header
                    request.headers['Authorization'] =
                    'Bearer xmqoqxTzdyBsZw3YI0ZZGuqVI6dDWaVLfBA+69Kbcp0=';

                    // Send the request
                    var response = await request.send();

                    // Handle the response
                    if (response.statusCode == 200) {
                      // Parse the response JSON
                      Navigator.of(context).pop();
                      print("imagge upload success");
                      var responseData = await response.stream.bytesToString();
                      var jsonResponse = jsonDecode(responseData);
                      print(jsonResponse);
                      Fluttertoast.showToast(
                          msg: "Images uploaded successfully",
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.BOTTOM,
                          timeInSecForIosWeb: 1,
                          backgroundColor: Colors.green,
                          textColor: Colors.white,
                          fontSize: 16.0
                      );
                      // Do something with jsonResponse
                    }
                    else {
                      // Handle errors
                      Navigator.of(context).pop();
                      print(
                          'Request failed with status: ${response.statusCode}');
                      Fluttertoast.showToast(
                          msg: "Images upload Failed",
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.BOTTOM,
                          timeInSecForIosWeb: 1,
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          fontSize: 16.0
                      );
                    }

                    // Reset captured images and text input
                    setState(() {
                      _capturedImages.clear();
                      _textInputController.clear();
                    });
                    Navigator.of(context).pop();
                  } else {
                    // Show a snackbar to indicate that either the text input or captured images are empty
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(
                          'Please enter some text and capture at least one image')),
                    );
                  }
                }
                catch(e)
                {
                  Navigator.of(context).pop();
                  print(e);

                }
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Block back press
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Add Student'),
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
                title: Text('Take Attendance'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CameraScreen()),
                  );
                },
              ),

              ListTile(
                title: Text('Encode Faces'),
                onTap: () async {
                  // Handle Drawer Item 2 tap
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
                    final response = await supabase
                        .from('baseurl')
                        .select('url')
                        .single();
                    var burl;
                    if (response != null) {
                      final String? baseUrl = response['url'] as String?;
                      burl = response['url'] as String?;
                      print("base_url = $baseUrl");
                    }

                    var url = burl + "/encode";
                    var hrequest = http.MultipartRequest('GET', Uri.parse(url));
                    hrequest.headers['Authorization'] =
                    'Bearer xmqoqxTzdyBsZw3YI0ZZGuqVI6dDWaVLfBA+69Kbcp0=';
                    var qresponse = await hrequest.send();

                    // Handle the response
                    if (qresponse.statusCode == 200) {
                      // Parse the response JSON
                      Navigator.of(context).pop();
                      print("encode success");
                      var responseData =
                      await qresponse.stream.bytesToString();
                      var jsonResponse = jsonDecode(responseData);
                      print("success mesage");
                      print(jsonResponse);

                      Fluttertoast.showToast(
                        msg: "face encoded successfully",
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
                      print('Request failed with status: ${qresponse
                          .statusCode}');
                      Fluttertoast.showToast(
                        msg: "encode  Failed",
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.redAccent,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    }
                  }
                  catch(e)
                  {
                    Navigator.of(context).pop();
                    print(e);
                  }
                },
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: ElevatedButton(
                  onPressed: _captureImage,
                  child: Text('Capture'),
                ),
              ),
            ),
            Positioned(
              top: 16.0,
              right: 16.0,
              child: Text(
                'Captured: ${_capturedImages.length} / 5',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
