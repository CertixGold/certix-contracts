const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const CertixToken = artifacts.require('CertixToken');
const FIRST = false
const bypass = false

if
if(FIRST){
    module.exports = async function (deployer) {
        await deployProxy(CertixToken, ["Certix Gold", "CERTIX", "12000000000000000000000000"], { deployer, initializer: 'initialize' });
    };
}else{
    module.exports = async function (deployer) {
        const existingProxyAddress = '0xD89AB639932eB22Fb34fe10De1eb1ef175F6DEa8';//ARB SEPOLIA
        await upgradeProxy(existingProxyAddress, CertixToken, { deployer, initializer: 'initialize' });
    };
}
