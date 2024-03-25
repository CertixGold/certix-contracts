const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const CertixToken = artifacts.require('CertixToken');
const FIRST = true

if(FIRST){
    module.exports = async function (deployer) {
        await deployProxy(CertixToken, ["Certix Gold", "CERTIX", "12000000000000000000000000"], { deployer, initializer: 'initialize' });
    };
}else{
    module.exports = async function (deployer) {
        const existingProxyAddress = '0xBF8567237Cee2ced478E3039ddB907c4E1175e9d';
        await upgradeProxy(existingProxyAddress, CertixToken, { deployer, initializer: 'initialize' });
    };
}
