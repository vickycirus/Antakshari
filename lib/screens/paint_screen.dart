import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cuadro/screens/voice_detection_screen.dart';
import 'package:cuadro/models/custom_painter.dart';
import 'package:cuadro/models/touch_point.dart';
import 'package:cuadro/screens/home_screen.dart';
import 'package:cuadro/sidebar/player_score_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

class PaintScreen extends StatefulWidget {
  final Map data;
  final String screenFrom;
  PaintScreen({this.data, this.screenFrom});
  @override
  _PaintScreenState createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> {
  GlobalKey globalKey = GlobalKey();
  List<TouchPoints> points = [];
  double opacity = 1.0;
  StrokeCap strokeType = StrokeCap.round;
  Color selectedColor;
  double strokeWidth;
  IO.Socket socket;
  Map dataOfRoom;
  List<Widget> textBlankWidget = [];
  List<Map> messages = [];
  List<Map> scoreboard = [];
  TextEditingController textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  var focusNode = FocusNode();
  var scaffoldKey = GlobalKey<ScaffoldState>();
  bool isTextInputReadOnly = false;
  String _firstChar='Y';
  final correctData='';
  stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';

  String songName = '';
  String singer = '';
  String album ='';
  String lastCharacter = '';
  Timer _timer;
  int _start = 40;
  int roundTime = 40;
  int guessedUserCtr = 0;
  bool isShowFinalLeaderboard = false;
  String winner;
  int maxPoints = 0;



  void startTimer() {
    const oneSec = const Duration(seconds: 1);
    _timer = new Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_start == 0) {
          print("timer 0");
          socket.emit("change-turn", dataOfRoom["name"]);
          setState(() {
            getData();
            timer.cancel();
          });
        } else {
          setState(() {
            _start--;
          });
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    connect();
    getData();
    selectedColor = Colors.black;
    strokeWidth = 2.0;
    _speech = stt.SpeechToText();

  }

  void renderTextBlank(String text) {
    textBlankWidget.clear();
    for (int i = 0; i < text.length; i++) {
      textBlankWidget.add(Text(
        "_",
        style: TextStyle(fontSize: 30),
      ));
    }
  }

  void verifySongLyrics() async{
    print("The texst is");
    print(_text);
    String url = "http://127.0.0.1:3000/getsongs";
    final bodyServer = jsonEncode({"lyrics": _text,
        "firstCharacter": _firstChar});

// Send the data to the backend
    http.Response response = await http.post(
      Uri.parse(url),
      headers:{'Content-Type': 'application/json'},
      body: bodyServer,
    );

// Check the response status code
    if (response.statusCode == 200) {
      getData();
      final dataBack = json.decode(response.body);
      String test = dataBack['lastLetter'];
      if(test.length>0) {
        songName = dataBack['songName'];
        singer = dataBack['singer'];
        album = dataBack['album'];
        lastCharacter = dataBack['lastLetter'];
        print("Song details");
        print(songName);

      }
      else{
        lastCharacter='';
        print(" i AM FALSE");
        print(lastCharacter);
      }
    } else {
      // The request failed

      lastCharacter='';
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  void getData() async {
    var url = Uri.parse('http://127.0.0.1:3000/firstchar');
    var response = await http.get(url);
    final temp = json.decode(response.body);
    _firstChar = temp['data'];
    print("response body");
    // print(response.body);
    print("first char");
    print(_firstChar);
  }


  String getRandomCharacter() {
    final random = Random();
    final randomNumber = random.nextInt(26) + 65;
    final randomAlphabet = String.fromCharCode(randomNumber);
    return randomAlphabet;
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) => setState(() {
          _text = result.recognizedWords;
        }),
      );
    }
  }
//stop
  void _stopListening() {
    setState(() => _isListening = false);
    _speech.stop();
  }

  void connect() {
    socket = IO.io("http://192.168.0.5:3000", <String, dynamic>{
      "transports": ["websocket"],
      "autoConnect": false,
    });
    socket.connect();
    if (widget.screenFrom == "createRoom") {
      // creating room
      socket.emit("create-game", widget.data);
    } else {
      // joining room
      socket.emit("join-game", widget.data);
    }
    socket.onConnect((data) {
      print("connected");
      socket.on("updateRoom", (roomData) {
        setState(() {
          renderTextBlank(roomData["word"]);
          dataOfRoom = roomData;
        });
        if (roomData["isJoin"] != true) {
          // started timer as game started
          startTimer();
        }
        scoreboard.clear();
        for (int i = 0; i < roomData["players"].length; i++) {
          setState(() {
            scoreboard.add({
              "username": roomData["players"][i]["nickname"],
              "points": roomData["players"][i]["points"].toString()
            });
          });
        }
      });

      // updating scoreboard
      socket.on("updateScore", (roomData) {
        scoreboard.clear();
        for (int i = 0; i < roomData["players"].length; i++) {
          setState(() {
            scoreboard.add({
              "username": roomData["players"][i]["nickname"],
              "points": roomData["players"][i]["points"].toString()
            });
          });
        }
      });

      // Not correct game
      socket.on(
          "notCorrectGame",
          (data) => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => HomeScreen(data: data)),
              (route) => false));

      // getting the painting on the screen
      socket.on("points", (point) {
        if (point["details"] != null) {
          setState(() {
            points.add(
              TouchPoints(
                  points: Offset((point["details"]["dx"]).toDouble(),
                      (point["details"]["dy"]).toDouble()),
                  paint: Paint()
                    ..strokeCap = strokeType
                    ..isAntiAlias = true
                    ..color = selectedColor.withOpacity(opacity)
                    ..strokeWidth = strokeWidth),
            );
          });
        } else {
          setState(() {
            points.add(null);
          });
        }
      });

      socket.on("closeInput", (_) {
        socket.emit("updateScore", widget.data["name"]);
        FocusScope.of(context).unfocus();
        setState(() {
          isTextInputReadOnly = true;
        });
      });

      socket.on("change-turn", (data) {
        String oldWord = dataOfRoom["word"];
        showDialog(
          context: scaffoldKey.currentContext,
          barrierDismissible: true,
          builder: (newContext) {
            Future.delayed(Duration(seconds: 3), () {
              setState(() {
                dataOfRoom = data;
                renderTextBlank(data["word"]);
                isTextInputReadOnly = false;
                _start = 40;
                guessedUserCtr = 0;
                points.clear();
              });
              // cancelling the before timer
              Navigator.of(scaffoldKey.currentContext).pop(true);
              _timer.cancel();
              startTimer();
            });
            if (dataOfRoom["turn"]["nickname"] == widget.data["nickname"] && lastCharacter.length > 0) {
              return AlertDialog(
                title: Text('You Sang Correct'),
                content: Text('Songs is :$songName'),
              );
            } else if(dataOfRoom["turn"]["nickname"] == widget.data["nickname"] && lastCharacter.length ==0) {
              return AlertDialog(
                title: Text('You Sang Wrong'),
                content: Text('wrong'),
              );
            }
            else{
              return AlertDialog(
                title: Center(child: Text("${dataOfRoom["turn"]["nickname"]} Turn Completed")),
              );
            }
          },
        );
      });


      socket.on("show-leaderboard", (roomPlayers) {
        print(scoreboard);
        scoreboard.clear();
        for (int i = 0; i < roomPlayers.length; i++) {
          setState(() {
            scoreboard.add({
              "username": roomPlayers[i]["nickname"],
              "points": roomPlayers[i]["points"].toString()
            });
          });
          if (maxPoints < int.parse(scoreboard[i]["points"])) {
            winner = scoreboard[i]["username"];
            maxPoints = int.parse(scoreboard[i]["points"]);
            print(maxPoints);
            print(winner);
          }
        }
        setState(() {
          _timer.cancel();
          isShowFinalLeaderboard = true;
        });
      });

      socket.on("msg", (messageData) {
        setState(() {
          messages.add(messageData);
          guessedUserCtr = messageData["guessedUserCtr"];
        });
        if (guessedUserCtr == dataOfRoom["players"].length - 1) {
          // length-1 because we don't have to include the host to guess.
          // next round
          print("message change turn");
          socket.emit("change-turn", dataOfRoom["name"]);
        }
        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 40,
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut);
      });

      // changing stroke width of pen
      socket.on(
          "stroke-width",
          (stroke) => this.setState(() {
                strokeWidth = stroke.toDouble();
              }));

      // changing the color of pen
      socket.on("color-change", (colorString) {
        int value = int.parse(colorString, radix: 16);
        Color otherColor = new Color(value);
        setState(() {
          selectedColor = otherColor;
        });
      });

      // clearing off the screen with clean button
      socket.on(
          "clear-screen",
          (data) => this.setState(() {
                points.clear();
              }));

      socket.on("user-disconnected", (data) {
        scoreboard.clear();
        for (int i = 0; i < data["players"].length; i++) {
          setState(() {
            scoreboard.add({
              "username": data["players"][i]["nickname"],
              "points": data["players"][i]["points"].toString()
            });
          });
        }
      });
    });

    // socket.emit("test", "Hello World");
    print("hey f ${socket.connected}");
  }

  @override
  void dispose() {
    socket.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;

    void selectColor() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Color Chooser'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: selectedColor,
              onColorChanged: (color) {
                String colorString = color.toString();
                String valueString = colorString.split('(0x')[1].split(')')[0];
                Map map = {
                  "color": valueString,
                  "roomName": dataOfRoom["name"],
                };
                socket.emit("color-change", map);
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("Close"))
          ],
        ),
      );
    }

    return Scaffold(
      key: scaffoldKey,
      drawer: PlayerScore(scoreboard),
      backgroundColor: Colors.white,
      body: dataOfRoom != null
          ? dataOfRoom["isJoin"] != true
              ? !isShowFinalLeaderboard
                  ? Stack(
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: width,
                              height: height * 0.2,
                              // child: GestureDetector(
                              //   onPanUpdate: dataOfRoom["turn"]["nickname"] ==
                              //           widget.data["nickname"]
                              //       ? (details) {
                              //           socket.emit("paint", {
                              //             "details": {
                              //               "dx": details.localPosition.dx,
                              //               "dy": details.localPosition.dy
                              //             },
                              //             "roomName": widget.data["name"]
                              //           });
                              //         }
                              //       : (_) {},
                              //   onPanStart: dataOfRoom["turn"]["nickname"] ==
                              //           widget.data["nickname"]
                              //       ? (details) {
                              //           socket.emit("paint", {
                              //             "details": {
                              //               "dx": details.localPosition.dx,
                              //               "dy": details.localPosition.dy
                              //             },
                              //             "roomName": widget.data["name"]
                              //           });
                              //         }
                              //       : (_) {},
                              //   onPanEnd: dataOfRoom["turn"]["nickname"] ==
                              //           widget.data["nickname"]
                              //       ? (details) {
                              //           socket.emit("paint", {
                              //             "details": null,
                              //             "roomName": widget.data["name"]
                              //           });
                              //         }
                              //       : (_) {},
                              //   child: SizedBox.expand(
                              //     child: ClipRRect(
                              //       borderRadius:
                              //           BorderRadius.all(Radius.circular(20.0)),
                              //       child: RepaintBoundary(
                              //         key: globalKey,
                              //         child: CustomPaint(
                              //           size: Size.infinite,
                              //           painter:
                              //               MyCustomPainter(pointsList: points),
                              //         ),
                              //       ),
                              //     ),
                              //   ),
                              // ),

                              child: Text(
                                "The Song should start with letter $_firstChar",
                                style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            dataOfRoom["turn"]["nickname"] ==
                                    widget.data["nickname"]
                                ? Row(
                                    children: <Widget>[
                                    //   IconButton(
                                    //       icon: Icon(
                                    //         Icons.color_lens,
                                    //         color: selectedColor,
                                    //       ),
                                    //       onPressed: () {
                                    //         selectColor();
                                    //       }),
                                    //   Expanded(
                                    //     child: Slider(
                                    //       min: 1.0,
                                    //       max: 10.0,
                                    //       label: "Stroke $strokeWidth",
                                    //       activeColor: selectedColor,
                                    //       value: strokeWidth,
                                    //       onChanged: (double value) {
                                    //         socket.emit("stroke-width", value);
                                    //       },
                                    //     ),
                                    //   ),
                                    //   IconButton(
                                    //       icon: Icon(
                                    //         Icons.layers_clear,
                                    //         color: Colors.black,
                                    //       ),
                                    //       onPressed: () {
                                    //         socket.emit("clean-screen",
                                    //             widget.data["name"]);
                                    //       }),
                                    ],
                                  )
                                : Center(
                                    child: Text(
                                      "${dataOfRoom["turn"]["nickname"]} is singing..",
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                            dataOfRoom["turn"]["nickname"] !=
                                    widget.data["nickname"]
                                ? Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: textBlankWidget,
                                  )
                                :
                                    // child: Text(
                                    //   dataOfRoom["word"],
                                    //   style: TextStyle(fontSize: 30),
                                    // ),
                                    // child:  ElevatedButton(
                                    //   onPressed: () {
                                    //     Navigator.push(
                                    //       context,
                                    //       MaterialPageRoute(builder: (context) => VoiceDetectionScreen()),
                                    //     );
                                    //   },
                                    //   child: Text('Start Voice Detection'),
                                    // ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [

                                    Center(
                                      child: Text(
                                        _text,
                                        style: TextStyle(fontSize: 32.0),
                                      ),
                                    ),
                                        Text(
                                        "The Song should start with letter $_firstChar",
                                        style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold),
                                        ),

                                    SizedBox(height: 20.0),
                                    FloatingActionButton(
                                      onPressed: _isListening ? _stopListening : _startListening,
                                      child: Icon(_isListening ? Icons.mic : Icons.mic_none),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        print("i am submit");
                                      verifySongLyrics();

                                      },
                                      style: ButtonStyle(
                                        backgroundColor: MaterialStateProperty.all(Colors.blue),
                                        textStyle: MaterialStateProperty.all(
                                          TextStyle(color: Colors.white),
                                        ),
                                        minimumSize: MaterialStateProperty.all(
                                          Size(MediaQuery.of(context).size.width / 2.5, 50),
                                        ),
                                      ),
                                      child: Text(
                                        "Submit",
                                        style: TextStyle(color: Colors.white, fontSize: 16),
                                      ),

                                    ),
                                  ],

                                ),

                            Container(
                              height: MediaQuery.of(context).size.height * 0.3,
                              child: ListView.builder(
                                  controller: _scrollController,
                                  shrinkWrap: true,
                                  // primary: true,
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    var msg = messages[index].values;
                                    return ListTile(
                                      title: Text(
                                        msg.elementAt(0),
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        msg.elementAt(1),
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 16),
                                      ),
                                    );
                                  }),
                            ),
                          ],
                        ),
                        dataOfRoom["turn"]["nickname"] !=
                                widget.data["nickname"]
                            ? Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  margin: EdgeInsets.only(left: 20, right: 20),
                                  child: TextField(
                                    readOnly: isTextInputReadOnly,
                                    autocorrect: false,
                                    focusNode: focusNode,
                                    controller: textEditingController,
                                    onSubmitted: (value) {
                                      if (value.trim().isNotEmpty) {
                                        Map map = {
                                          "username": widget.data["nickname"],
                                          "msg": value.trim(),
                                          "word": dataOfRoom["word"],
                                          "roomName": widget.data["name"],
                                          "totalTime": roundTime,
                                          "timeTaken": roundTime - _start,
                                          "guessedUserCtr": guessedUserCtr
                                        };
                                        socket.emit("msg", map);
                                        textEditingController.clear();
                                        FocusScope.of(context)
                                            .requestFocus(focusNode);
                                      }
                                    },
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: Colors.transparent,
                                            width: 0),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: Colors.transparent,
                                            width: 0),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      filled: true,
                                      fillColor: Color(0xffF5F6FA),
                                      hintText: "Your guess",
                                      hintStyle: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    textInputAction: TextInputAction.done,
                                  ),
                                ),
                              )
                            : Container(),
                        SafeArea(
                          child: IconButton(
                            icon: Icon(
                              Icons.menu,
                              color: Colors.black,
                            ),
                            onPressed: () =>
                                scaffoldKey.currentState.openDrawer(),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        height: double.maxFinite,
                        child: Column(
                          children: [
                            ListView.builder(
                              primary: true,
                              shrinkWrap: true,
                              itemCount: scoreboard.length,
                              itemBuilder: (BuildContext context, index) {
                                var data = scoreboard[index].values;
                                return ListTile(
                                  title: Text(
                                    data.elementAt(0),
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 23,
                                    ),
                                  ),
                                  trailing: Text(
                                    data.elementAt(1),
                                    style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold),
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "$winner has won the game!",
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 30),
                              ),
                            )
                          ],
                        ),
                      ),
                    )
              : SafeArea(
                  child: Column(
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.03),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Waiting for ${dataOfRoom["occupancy"] - dataOfRoom["players"].length} players to join",
                          style: TextStyle(
                            fontSize: 30,
                          ),
                        ),
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.06),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          readOnly: true,
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: dataOfRoom["name"]));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text("Copied!"),
                            ));
                          },
                          decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.transparent, width: 0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.transparent, width: 0),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              filled: true,
                              fillColor: Color(0xffF5F6FA),
                              hintText: "Tap to copy room name!",
                              hintStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              )),
                        ),
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.1),
                      Text(
                        "Players: ",
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                      ListView.builder(
                          primary: true,
                          shrinkWrap: true,
                          itemCount: dataOfRoom["players"].length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: Text(
                                "${index + 1}.",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              title: Text(
                                dataOfRoom["players"][index]["nickname"],
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          })
                    ],
                  ),
                )
          : Center(
              child: CircularProgressIndicator(),
            ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(
          bottom: 30,
        ),
        child: FloatingActionButton(
          onPressed: () {},
          elevation: 7,
          backgroundColor: Colors.white,
          child: Text(
            "$_start",
            style: TextStyle(color: Colors.black, fontSize: 22),
          ),
        ),
      ),
    );
  }
}
