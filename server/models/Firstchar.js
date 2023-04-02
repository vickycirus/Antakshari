const mongoose = require("mongoose");

const firstCharSchema=new mongoose.Schema({

    firstChar:{
       type:String
    }
})

const firstCharModel=new mongoose.model("FirstChar",firstCharSchema);


module.exports=firstCharModel;