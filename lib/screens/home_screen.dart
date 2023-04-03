import 'package:cuadro/screens/create_room_screen.dart';
import 'package:cuadro/screens/join_room_screen.dart';
import 'package:flutter/material.dart';
import 'package:cuadro/screens/voice_detection_screen.dart';

class HomeScreen extends StatefulWidget {
  final String data;
  HomeScreen({this.data});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // @override
  // void initState() {
  //   super.initState();
  //   if (widget.data != "") {
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //       content: Text("data"),
  //     ));
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 30.0),
            Text(
              "Welcome to Online Antakshari!",
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 40.0),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 30.0),
              child: Text(
                "Create or join a room to start playing with your friends!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18.0,
                ),
              ),
            ),
            SizedBox(height: 60.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CreateRoomScreen(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    primary: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    minimumSize: Size(
                      MediaQuery.of(context).size.width / 2.8,
                      50,
                    ),
                  ),
                  child: Text(
                    "Create a Room",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => JoinRoomScreen(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    primary: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    minimumSize: Size(
                      MediaQuery.of(context).size.width / 2.8,
                      50,
                    ),
                  ),
                  child: Text(
                    "Join a Room",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );

  }
}
