pragma solidity >=0.4.21 <0.6.0;

import "../PooledCDAI.sol";
import "../interfaces/KyberNetworkProxy.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

/**
  @dev An extension to PooledCDAI that enables minting & burning pcDAI using ETH & ERC20 tokens
    supported by Kyber Network, rather than just DAI. There's no need to deploy one for each pool,
    since it uses pcDAI as a black box.
 */
contract PooledCDAIKyberExtension {
  using SafeERC20 for ERC20;
  using SafeERC20 for PooledCDAI;
  using SafeMath for uint256;

  address public constant DAI_ADDRESS = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
  address public constant KYBER_ADDRESS = 0x818E6FECD516Ecc3849DAf6845e3EC868087B755;
  ERC20 internal constant ETH_TOKEN_ADDRESS = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
  bytes internal constant PERM_HINT = "PERM"; // Only use permissioned reserves from Kyber
  uint internal constant MAX_QTY   = (10**28); // 10B tokens

  function mintWithETH(PooledCDAI pcDAI, address to) public payable returns (bool) {
    // convert `msg.value` ETH to DAI
    ERC20 dai = ERC20(DAI_ADDRESS);
    (uint256 actualDAIAmount, uint256 actualETHAmount) = _kyberTrade(ETH_TOKEN_ADDRESS, msg.value, dai);

    // mint `actualDAIAmount` pcDAI
    _mint(pcDAI, to, actualDAIAmount);

    // return any leftover ETH
    if (actualETHAmount < msg.value) {
      msg.sender.transfer(msg.value.sub(actualETHAmount));
    }

    return true;
  }

  function mintWithToken(PooledCDAI pcDAI, address tokenAddress, address to, uint256 amount) public returns (bool) {
    require(tokenAddress != address(ETH_TOKEN_ADDRESS), "Use mintWithETH() instead");
    require(tokenAddress != DAI_ADDRESS, "Use mint() instead");

    // transfer `amount` token from msg.sender
    ERC20 token = ERC20(tokenAddress);
    token.safeTransferFrom(msg.sender, address(this), amount);

    // convert `amount` token to DAI
    ERC20 dai = ERC20(DAI_ADDRESS);
    (uint256 actualDAIAmount, uint256 actualTokenAmount) = _kyberTrade(token, amount, dai);

    // mint `actualDAIAmount` pcDAI
    _mint(pcDAI, to, actualDAIAmount);

    // return any leftover tokens
    if (actualTokenAmount < amount) {
      token.safeTransfer(msg.sender, amount.sub(actualTokenAmount));
    }

    return true;
  }

  function burnToETH(PooledCDAI pcDAI, address payable to, uint256 amount) public returns (bool) {
    // burn `amount` pcDAI for msg.sender to get DAI
    _burn(pcDAI, amount);

    // convert `amount` DAI to ETH
    ERC20 dai = ERC20(DAI_ADDRESS);
    (uint256 actualETHAmount, uint256 actualDAIAmount) = _kyberTrade(dai, amount, ETH_TOKEN_ADDRESS);

    // transfer `actualETHAmount` ETH to `to`
    to.transfer(actualETHAmount);

    // transfer any leftover DAI
    if (actualDAIAmount < amount) {
      dai.safeTransfer(msg.sender, amount.sub(actualDAIAmount));
    }

    return true;
  }

  function burnToToken(PooledCDAI pcDAI, address tokenAddress, address to, uint256 amount) public returns (bool) {
    require(tokenAddress != address(ETH_TOKEN_ADDRESS), "Use burnToETH() instead");
    require(tokenAddress != DAI_ADDRESS, "Use burn() instead");

    // burn `amount` pcDAI for msg.sender to get DAI
    _burn(pcDAI, amount);

    // convert `amount` DAI to token
    ERC20 dai = ERC20(DAI_ADDRESS);
    ERC20 token = ERC20(tokenAddress);
    (uint256 actualTokenAmount, uint256 actualDAIAmount) = _kyberTrade(dai, amount, token);

    // transfer `actualTokenAmount` token to `to`
    token.safeTransfer(to, actualTokenAmount);

    // transfer any leftover DAI
    if (actualDAIAmount < amount) {
      dai.safeTransfer(msg.sender, amount.sub(actualDAIAmount));
    }

    return true;
  }

  function _mint(PooledCDAI pcDAI, address to, uint256 actualDAIAmount) internal {
    ERC20 dai = ERC20(DAI_ADDRESS);
    dai.safeApprove(address(pcDAI), 0);
    dai.safeApprove(address(pcDAI), actualDAIAmount);
    require(pcDAI.mint(to, actualDAIAmount), "Failed to mint pcDAI");
  }

  function _burn(PooledCDAI pcDAI, uint256 amount) internal {
    // transfer `amount` pcDAI from msg.sender
    pcDAI.safeTransferFrom(msg.sender, address(this), amount);

    // burn `amount` pcDAI for DAI
    require(pcDAI.burn(address(this), amount), "Failed to burn pcDAI");
  }

  /**
   * @notice Get the token balance of an account
   * @param _token the token to be queried
   * @param _addr the account whose balance will be returned
   * @return token balance of the account
   */
  function _getBalance(ERC20 _token, address _addr) internal view returns(uint256) {
    if (address(_token) == address(ETH_TOKEN_ADDRESS)) {
      return uint256(_addr.balance);
    }
    return uint256(_token.balanceOf(_addr));
  }

  function _toPayableAddr(address _addr) internal pure returns (address payable) {
    return address(uint160(_addr));
  }

  /**
   * @notice Wrapper function for doing token conversion on Kyber Network
   * @param _srcToken the token to convert from
   * @param _srcAmount the amount of tokens to be converted
   * @param _destToken the destination token
   * @return _destPriceInSrc the price of the dest token, in terms of source tokens
   *         _srcPriceInDest the price of the source token, in terms of dest tokens
   *         _actualDestAmount actual amount of dest token traded
   *         _actualSrcAmount actual amount of src token traded
   */
  function _kyberTrade(ERC20 _srcToken, uint256 _srcAmount, ERC20 _destToken)
    internal
    returns(
      uint256 _actualDestAmount,
      uint256 _actualSrcAmount
    )
  {
    // Get current rate & ensure token is listed on Kyber
    KyberNetworkProxy kyber = KyberNetworkProxy(KYBER_ADDRESS);
    (, uint256 rate) = kyber.getExpectedRate(_srcToken, _destToken, _srcAmount);
    require(rate > 0, "Price for token is 0 on Kyber");

    uint256 beforeSrcBalance = _getBalance(_srcToken, address(this));
    uint256 msgValue;
    if (_srcToken != ETH_TOKEN_ADDRESS) {
      msgValue = 0;
      _srcToken.safeApprove(KYBER_ADDRESS, 0);
      _srcToken.safeApprove(KYBER_ADDRESS, _srcAmount);
    } else {
      msgValue = _srcAmount;
    }
    _actualDestAmount = kyber.tradeWithHint.value(msgValue)(
      _srcToken,
      _srcAmount,
      _destToken,
      _toPayableAddr(address(this)),
      MAX_QTY,
      rate,
      address(0),
      PERM_HINT
    );
    require(_actualDestAmount > 0, "Received 0 dest token");
    if (_srcToken != ETH_TOKEN_ADDRESS) {
      _srcToken.safeApprove(KYBER_ADDRESS, 0);
    }

    _actualSrcAmount = beforeSrcBalance.sub(_getBalance(_srcToken, address(this)));
  }

  function() external payable {}
}