const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const CertixNFT = artifacts.require('CertixNFT');
const FIRST = true

if(FIRST){
    module.exports = async function (deployer) {
        const ethereumNetworkId = 0;
        await deployProxy(CertixNFT, ["CtxNFT", "CtxNFT"], { deployer, initializer: 'initialize' });
    };
}else{
    module.exports = async function (deployer) {
        const existingProxyAddress = '0xBF8567237Cee2ced478E3039ddB907c4E1175e9d';
        await upgradeProxy(existingProxyAddress, CertixNFT, { deployer, initializer: 'initialize' });
    };
}
