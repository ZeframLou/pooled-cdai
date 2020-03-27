pragma solidity 0.5.17;

import "./lib/CloneFactory.sol";
import "./PooledCDAI.sol";

contract PooledCDAIFactory is CloneFactory {

  address public libraryAddress;

  event CreatePool(address sender, address pool, bool indexed renounceOwnership);

  constructor(address _libraryAddress) public {
    libraryAddress = _libraryAddress;
  }

  function createPCDAI(string memory name, string memory symbol, address beneficiary, bool renounceOwnership) public returns (PooledCDAI) {
    PooledCDAI pcDAI = _createPCDAI(name, symbol, beneficiary, renounceOwnership);
    emit CreatePool(msg.sender, address(pcDAI), renounceOwnership);
    return pcDAI;
  }

  function _createPCDAI(string memory name, string memory symbol, address beneficiary, bool renounceOwnership) internal returns (PooledCDAI) {
    address payable clone = _toPayableAddr(createClone(libraryAddress));
    PooledCDAI pcDAI = PooledCDAI(clone);
    pcDAI.init(name, symbol, beneficiary);
    if (renounceOwnership) {
      pcDAI.renounceOwnership();
    } else {
      pcDAI.transferOwnership(msg.sender);
    }
    return pcDAI;
  }

  function _toPayableAddr(address _addr) internal pure returns (address payable) {
    return address(uint160(_addr));
  }
}