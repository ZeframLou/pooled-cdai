pragma solidity >=0.4.21 <0.6.0;

/**
 * @title The interface for the KyberNetworkProxy smart contract
 */
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

interface KyberNetworkProxy {
  function getExpectedRate(ERC20 src, ERC20 dest, uint srcQty) external view
      returns (uint expectedRate, uint slippageRate);

  function tradeWithHint(
    ERC20 src, uint srcAmount, ERC20 dest, address payable destAddress, uint maxDestAmount,
    uint minConversionRate, address walletId, bytes calldata hint) external payable returns(uint);
}
