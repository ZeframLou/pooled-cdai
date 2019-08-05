pragma solidity >=0.4.21 <0.6.0;

import "./PooledCDAI.sol";

contract PooledCDAIFactory {
  event CreatePool(address sender, address pool);

  function createPCDAI(string memory name, string memory symbol, address _beneficiary) public returns (PooledCDAI) {
    PooledCDAI pcDAI = new PooledCDAI(name, symbol, _beneficiary);
    pcDAI.transferOwnership(msg.sender);
    emit CreatePool(msg.sender, address(pcDAI));
    return pcDAI;
  }
}