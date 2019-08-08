pragma solidity >=0.4.21 <0.6.0;

import "./PooledCDAI.sol";
import "./interfaces/KyberNetworkProxy.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

contract KyberPooledCDAI is PooledCDAI {
  using SafeERC20 for ERC20;

  address public constant KYBER_ADDRESS = 0x818E6FECD516Ecc3849DAf6845e3EC868087B755;
  ERC20 internal constant ETH_TOKEN_ADDRESS = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
  bytes internal constant PERM_HINT = "PERM";
  uint internal constant MAX_QTY   = (10**28); // 10B tokens

  function mintWithETH(address to) public payable returns (bool) {
    // convert ETH to DAI
    ERC20 dai = ERC20(DAI_ADDRESS);
    (uint256 actualDAIAmount, uint256 actualETHAmount) = _kyberTrade(ETH_TOKEN_ADDRESS, msg.value, dai);

    // use `actualDAIAmount` DAI to mint cDAI
    CERC20 cDAI = CERC20(CDAI_ADDRESS);
    require(dai.approve(CDAI_ADDRESS, 0), "Failed to clear DAI allowance");
    require(dai.approve(CDAI_ADDRESS, actualDAIAmount), "Failed to set DAI allowance");
    require(cDAI.mint(actualDAIAmount) == 0, "Failed to mint cDAI");

    // mint `actualDAIAmount` pcDAI for `to`
    _mint(to, actualDAIAmount);

    // emit event
    emit Mint(msg.sender, to, actualDAIAmount);

    // return any leftover ETH
    if (actualETHAmount < msg.value) {
      msg.sender.transfer(msg.value.sub(actualETHAmount));
    }

    return true;
  }

  function mintWithToken(address to, address tokenAddress, uint256 amount) public returns (bool) {
    require(tokenAddress != address(ETH_TOKEN_ADDRESS), "Use mintWithETH() instead");
    require(tokenAddress != DAI_ADDRESS, "Use mint() instead");

    // transfer token to pool
    ERC20 token = ERC20(tokenAddress);
    token.safeTransferFrom(msg.sender, address(this), amount);

    // convert token to DAI
    ERC20 dai = ERC20(DAI_ADDRESS);
    (uint256 actualDAIAmount, uint256 actualTokenAmount) = _kyberTrade(token, amount, dai);

    // use `actualDAIAmount` DAI to mint cDAI
    CERC20 cDAI = CERC20(CDAI_ADDRESS);
    require(dai.approve(CDAI_ADDRESS, 0), "Failed to clear DAI allowance");
    require(dai.approve(CDAI_ADDRESS, actualDAIAmount), "Failed to set DAI allowance");
    require(cDAI.mint(actualDAIAmount) == 0, "Failed to mint cDAI");

    // mint `actualDAIAmount` pcDAI for `to`
    _mint(to, actualDAIAmount);

    // emit event
    emit Mint(msg.sender, to, actualDAIAmount);

    // return any leftover tokens
    if (actualTokenAmount < amount) {
      token.safeTransfer(msg.sender, amount.sub(actualTokenAmount));
    }

    return true;
  }

  function burnToETH(address payable to, uint256 amount) public returns (bool) {
    // burn `amount` pcDAI for msg.sender
    _burn(msg.sender, amount);

    // burn cDAI for `amount` DAI
    CERC20 cDAI = CERC20(CDAI_ADDRESS);
    require(cDAI.redeemUnderlying(amount) == 0, "Failed to redeem");

    // convert DAI to ETH
    ERC20 dai = ERC20(DAI_ADDRESS);
    (uint256 actualETHAmount, uint256 actualDAIAmount) = _kyberTrade(dai, amount, ETH_TOKEN_ADDRESS);

    // transfer ETH to `to`
    to.transfer(actualETHAmount);

    // emit event
    emit Burn(msg.sender, to, actualDAIAmount);

    // transfer any leftover DAI
    if (actualDAIAmount < amount) {
      require(dai.transfer(msg.sender, amount.sub(actualDAIAmount)), "Failed to return leftover DAI");
    }

    return true;
  }

  function burnToToken(address to, address tokenAddress, uint256 amount) public returns (bool) {
    require(tokenAddress != address(ETH_TOKEN_ADDRESS), "Use burnToETH() instead");
    require(tokenAddress != DAI_ADDRESS, "Use burn() instead");

    // burn `amount` pcDAI for msg.sender
    _burn(msg.sender, amount);

    // burn cDAI for `amount` DAI
    CERC20 cDAI = CERC20(CDAI_ADDRESS);
    require(cDAI.redeemUnderlying(amount) == 0, "Failed to redeem");

    // convert DAI to token
    ERC20 dai = ERC20(DAI_ADDRESS);
    ERC20 token = ERC20(tokenAddress);
    (uint256 actualTokenAmount, uint256 actualDAIAmount) = _kyberTrade(dai, amount, token);

    // transfer token to `to`
    token.safeTransfer(to, actualTokenAmount);

    // emit event
    emit Burn(msg.sender, to, actualDAIAmount);

    // transfer any leftover DAI
    if (actualDAIAmount < amount) {
      require(dai.transfer(msg.sender, amount.sub(actualDAIAmount)), "Failed to return leftover DAI");
    }

    return true;
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
      address(this),
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
}