const PooledCDAIFactory = artifacts.require("PooledCDAIFactory");
const PooledCDAI = artifacts.require("PooledCDAI");

module.exports = function(deployer) {
  deployer.then(async () => {
    let lib = await PooledCDAI.deployed();
    deployer.deploy(PooledCDAIFactory, lib.address);
  });
};