pragma solidity >=0.4.21 <0.6.0;

import "./PooledCDAI.sol";

contract PooledCDAIFactory {
  function createPCDAI(string memory name, string memory symbol, address _beneficiary) public returns (PooledCDAI) {
    return new PooledCDAI(name, symbol, _beneficiary);
  }
}