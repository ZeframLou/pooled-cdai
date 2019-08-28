const PooledCDAI = artifacts.require("PooledCDAI");

module.exports = function(deployer) {
  deployer.deploy(PooledCDAI);
};