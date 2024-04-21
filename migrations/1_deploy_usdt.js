const UsdtToken = artifacts.require("UsdtToken");

const FIRST = false


module.exports = function (deployer) {
    if(FIRST){
        deployer.deploy(UsdtToken, "Tether", "USDT", "100000000000000000000000000");
    }//0x89E9Ea46965AfcD8d54e9a47becC5F74535b2DdA
};