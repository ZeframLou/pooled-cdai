pragma solidity >=0.4.21 <0.6.0;

import "./PooledCDAI.sol";

contract PooledCDAIFactory {
  event CreatePool(address sender, address pool, bool indexed renounceOwnership);

  function createPCDAI(string memory name, string memory symbol, address _beneficiary, bool renounceOwnership) public returns (PooledCDAI) {
    PooledCDAI pcDAI = _createPCDAI(name, symbol, _beneficiary, renounceOwnership);
    emit CreatePool(msg.sender, address(pcDAI), renounceOwnership);
    return pcDAI;
  }

  function _createPCDAI(string memory name, string memory symbol, address _beneficiary, bool renounceOwnership) internal returns (PooledCDAI) {
    PooledCDAI pcDAI = new PooledCDAI(name, symbol, _beneficiary);
    if (renounceOwnership) {
      pcDAI.renounceOwnership();
    } else {
      pcDAI.transferOwnership(msg.sender);
    }
    return pcDAI;
  }
}