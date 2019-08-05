const PooledCDAIFactory = artifacts.require("PooledCDAIFactory");

module.exports = function(deployer) {
  deployer.deploy(PooledCDAIFactory);
};