const express = require("express");
var http = require("http");
const app = express();
const cors = require('cors');
const port = process.env.PORT || 3000;
var server = http.createServer(app);
var io = require("socket.io")(server);
const mongoose = require("mongoose");
const getWord = require("./apis/generateWord");
const Room = require("./models/Room");
const FirstChar = require("./models/Firstchar");
const dotenv = require("dotenv");
const songsData = require('./apis/songs.json');
dotenv.config();

//middleware
app.use(express.json());
app.use(cors());

mongoose
    .connect("mongodb+srv://vikram:vikram@cluster0.wsgcmdk.mongodb.net/?retryWrites=true&w=majority", {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        useCreateIndex: true,
        useFindAndModify: false,
    })
    .then(() => {
        console.log("connection successful");
    })
    .catch((e) => {
        console.log(e);
    });

// sockets

app.get("/firstchar",async (req, res) => {
     const Obj = await FirstChar.find({});

     return res.send({data:Obj[0].firstChar});
});


app.post("/getsongs", async(req, res) =>{
    let data = req.body;
    let temp = false;
    console.log(data)
    let songLyrics = data.lyrics;
    let firstChar = data.firstCharacter;
    let splitwords = songLyrics.split(' ');
    if (splitwords.length >= 6) {
        for (let i = 0; i < songsData.length; i++) {
            let dataWords = songsData[i].lyrics;
            let dataWordsSplit = dataWords.split(' ');
            let count = 0;

            for (let j = 0; j < 6; j++) {
                // let ss = splitwords[j];["helo","fg"]
                if (splitwords[j].toLowerCase() === dataWordsSplit[j].toLowerCase()) {
                    count++;
                }
            }
            if (count >= 4 && splitwords[0].toLowerCase()[0] === firstChar.toLowerCase()) {
                let lastWord = splitwords[splitwords.length - 1]
                 await FirstChar.updateOne({_id:'64298b7e2f333f3ad88c9d57'},{$set:{firstChar:lastWord[lastWord.length - 1]}})
                temp =true
                res.send({
                    "songName": songsData[i].name,
                    "singer": songsData[i].singer,
                    "album": songsData[i].album,
                    "lastLetter": lastWord[lastWord.length - 1]
                })
            }

        }
    }
    if(temp===false){
    await FirstChar.updateOne({_id:'64298b7e2f333f3ad88c9d57'},{$set:{firstChar:"m"}})
    res.send({
            "lastLetter": ""
        });
    }

});

app.post("/updateUserPoints", async(req, res) =>{
    let data = req.body;
    let roomId = data.roomid;
    let playerId = data.playerid;
    let points = data.points;
    let updatedResult = await Room.updateOne(
      { _id: roomId, 'players._id': playerId },
      { $inc: { 'players.$[player].points': points } },
      { arrayFilters: [{ 'player._id': playerId }] }
    )
    let roomData = await Room.find({_id:roomId});
    if(updatedResult){
    res.send({"data":roomData});
    }
    else{
    res.send("Unsuccessful");
    }

});



io.on("connection", (socket) => {
    console.log("connected");
    console.log(socket.id, "has joined");
    socket.on("test", (data) => {
        console.log(data);
    });

    // white board related sockets
    socket.on("paint", ({
        details,
        roomName
    }) => {
        io.to(roomName).emit("points", {
            details: details
        });
    });



    socket.on("clean-screen", (roomId) => {
        io.to(roomId).emit("clear-screen", "");
    });

    socket.on("stroke-width", (stroke) => {
        io.emit("stroke-width", stroke);
    });

    // game related sockets
    // creating game
    socket.on("create-game", async ({
        nickname,
        name,
        occupancy,
        maxRounds
    }) => {
        try {
            const existingRoom = await Room.findOne({
                name
            });
            if (existingRoom) {
                socket.emit("notCorrectGame", "Room with that name already exists");
                return;
            }
            let room = new Room();
            const word = getWord();
            room.word = word;
            room.name = name;
            room.occupancy = occupancy;
            room.maxRounds = maxRounds;
            let player = {
                socketID: socket.id,
                nickname,
                isPartyLeader: true,
            };
            room.players.push(player);
            room = await room.save();
            socket.join(name);
            io.to(name).emit("updateRoom", room);
        } catch (err) {
            console.log(err);
        }
    });

    // joining game
    socket.on("join-game", async ({
        nickname,
        name
    }) => {
        try {
            let room = await Room.findOne({
                name
            });
            if (!room) {
                socket.emit("notCorrectGame", "Please enter a valid room name");
                return;
            }
            if (room.isJoin) {
                // waiting for players
                let player = {
                    socketID: socket.id,
                    nickname,
                };
                room.players.push(player);
                socket.join(name);
                if (room.players.length === room.occupancy) {
                    room.isJoin = false;
                }
                room.turn = room.players[room.turnIndex];
                room = await room.save();
                io.to(name).emit("updateRoom", room);
            } else {
                socket.emit(
                    "notCorrectGame",
                    "The Game is in progress, please try later!"
                );
            }
        } catch (err) {
            console.log(err.toString());
        }
    });

    socket.on("updateScore", async (name) => {
        console.log("update score index");
        try {
            const room = await Room.findOne({
                name
            });
            io.to(name).emit("updateScore", room);
        } catch (err) {
            console.log(err.toString());
        }
    });

    socket.on("change-turn", async (name) => {
        console.log("Change Turn!");
        try {
            let room = await Room.findOne({
                name
            });
            let idx = room.turnIndex;
            if (idx + 1 === room.players.length) {
                room.currentRound += 1;
                console.log("current round increase");
            }
            if (room.currentRound <= room.maxRounds) {
                const word = getWord();
                room.word = word;
                room.turnIndex = (idx + 1) % room.players.length;
                room.turn = room.players[room.turnIndex];
                room = await room.save();
                console.log("changing turn blah");
                io.to(name).emit("change-turn", room);
                console.log("change turn sss");
            } else {
                io.to(name).emit("show-leaderboard", room.players);
            }
        } catch (err) {
            console.log(err.toString());
        }
    });

    socket.on("color-change", async (data) => {
        io.to(data.roomName).emit("color-change", data.color);
    });

    // sending messages in paint screen
    socket.on("msg", async (data) => {
        try {
            if (data.msg === data.word) {
                // increment points algorithm = totaltime/timetaken *10 = 30/20
                let room = await Room.find({
                    name: data.roomName
                });
                let userPlayer = room[0].players.filter(
                    (player) => player.nickname === data.username
                );
                if (data.timeTaken !== 0) {
                    userPlayer[0].points += Math.round((200 / data.timeTaken) * 10);
                }
                room = await room[0].save();
                io.to(data.roomName).emit("msg", {
                    username: data.username,
                    msg: "guessed it!",
                    guessedUserCtr: data.guessedUserCtr + 1,
                });
                socket.emit("closeInput", "");
                // not sending points here, will send after every user has guessed
            } else {
                io.to(data.roomName).emit("msg", {
                    username: data.username,
                    msg: data.msg,
                    guessedUserCtr: data.guessedUserCtr,
                });
            }
        } catch (err) {
            console.log(err.toString());
        }
    });

    socket.on("disconnect", async () => {
        console.log("disconnected");
        try {
            let room = await Room.findOne({
                "players.socketID": socket.id
            });
            console.log(room);
            for (let i = 0; i < room.players.length; i++) {
                if (room.players[i].socketID === socket.id) {
                    room.players.splice(i, 1);
                    break;
                }
            }
            room = await room.save();
            if (room.players.length === 1) {
                socket.broadcast.to(room.name).emit("show-leaderboard", room.players);
            } else {
                socket.broadcast.to(room.name).emit("user-disconnected", room);
            }
        } catch (err) {
            console.log(err.toString());
        }
    });
});

server.listen(port, "0.0.0.0", () => {
    console.log("server started & running on " + port);
});