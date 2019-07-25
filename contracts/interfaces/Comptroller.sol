pragma solidity >=0.4.21 <0.6.0;

// Compound finance comptroller
interface Comptroller {
  function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
  function markets(address cToken) external view returns (bool isListed, uint256 collateralFactorMantissa);
}