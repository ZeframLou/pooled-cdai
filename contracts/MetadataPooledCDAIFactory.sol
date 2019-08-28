pragma solidity >=0.4.21 <0.6.0;

import "./PooledCDAIFactory.sol";

contract MetadataPooledCDAIFactory is PooledCDAIFactory {
  event CreatePoolWithMetadata(address sender, address pool, bool indexed renounceOwnership, bytes metadata);

  function createPCDAIWithMetadata(
    string memory name,
    string memory symbol,
    address beneficiary,
    bool renounceOwnership,
    bytes memory metadata
  ) public returns (PooledCDAI) {
    PooledCDAI pcDAI = _createPCDAI(name, symbol, beneficiary, renounceOwnership);
    emit CreatePoolWithMetadata(msg.sender, address(pcDAI), renounceOwnership, metadata);
  }
}