pragma solidity 0.5.17;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./interfaces/CERC20.sol";

contract PooledCDAI is ERC20, Ownable {
  using SafeERC20 for ERC20;

  uint256 internal constant PRECISION = 10 ** 18;

  CERC20 public constant cDAI = CERC20(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
  ERC20 public constant dai = ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

  string private _name;
  string private _symbol;

  address public beneficiary; // the account that will receive the interests from Compound

  event Mint(address indexed sender, address indexed to, uint256 amount);
  event Burn(address indexed sender, address indexed to, uint256 amount);
  event WithdrawInterest(address indexed sender, address beneficiary, uint256 amount, bool indexed inDAI);
  event SetBeneficiary(address oldBeneficiary, address newBeneficiary);

  /**
    * @dev Sets the values for `name` and `symbol`. Both of
    * these values are immutable: they can only be set once during
    * construction.
    */
  function init(string memory name, string memory symbol, address _beneficiary) public {
    require(beneficiary == address(0), "Already initialized");

    _name = name;
    _symbol = symbol;

    // Set beneficiary
    require(_beneficiary != address(0), "Beneficiary can't be zero");
    beneficiary = _beneficiary;
    emit SetBeneficiary(address(0), _beneficiary);

    _transferOwnership(msg.sender);
  }

  /**
    * @dev Returns the name of the token.
    */
  function name() public view returns (string memory) {
    return _name;
  }

  /**
    * @dev Returns the symbol of the token, usually a shorter version of the
    * name.
    */
  function symbol() public view returns (string memory) {
    return _symbol;
  }

  /**
    * @dev Returns the number of decimals used to get its user representation.
    * For example, if `decimals` equals `2`, a balance of `505` tokens should
    * be displayed to a user as `5,05` (`505 / 10 ** 2`).
    *
    * Tokens usually opt for a value of 18, imitating the relationship between
    * Ether and Wei.
    *
    * NOTE: This information is only used for _display_ purposes: it in
    * no way affects any of the arithmetic of the contract, including
    * {IERC20-balanceOf} and {IERC20-transfer}.
    */
  function decimals() public pure returns (uint8) {
    return 18;
  }

  function mint(address to, uint256 amount) public returns (bool) {
    // transfer `amount` DAI from msg.sender
    dai.safeTransferFrom(msg.sender, address(this), amount);

    // use `amount` DAI to mint cDAI
    dai.safeApprove(address(cDAI), amount);
    require(cDAI.mint(amount) == 0, "Failed to mint cDAI");

    // mint `amount` pcDAI for `to`
    _mint(to, amount);

    // emit event
    emit Mint(msg.sender, to, amount);

    return true;
  }

  function burn(address to, uint256 amount) public returns (bool) {
    // burn `amount` pcDAI for msg.sender
    _burn(msg.sender, amount);

    // burn cDAI for `amount` DAI
    require(cDAI.redeemUnderlying(amount) == 0, "Failed to redeem");

    // transfer DAI to `to`
    dai.safeTransfer(to, amount);

    // emit event
    emit Burn(msg.sender, to, amount);

    return true;
  }

  function accruedInterestCurrent() public returns (uint256) {
    return cDAI.exchangeRateCurrent().mul(cDAI.balanceOf(address(this))).div(PRECISION).sub(totalSupply());
  }

  function accruedInterestStored() public view returns (uint256) {
    return cDAI.exchangeRateStored().mul(cDAI.balanceOf(address(this))).div(PRECISION).sub(totalSupply());
  }

  function withdrawInterestInDAI() public returns (bool) {
    // calculate amount of interest in DAI
    uint256 interestAmount = accruedInterestCurrent();

    // burn cDAI
    require(cDAI.redeemUnderlying(interestAmount) == 0, "Failed to redeem");

    // transfer DAI to beneficiary
    dai.safeTransfer(beneficiary, interestAmount);

    emit WithdrawInterest(msg.sender, beneficiary, interestAmount, true);

    return true;
  }

  function setBeneficiary(address newBeneficiary) public onlyOwner returns (bool) {
    require(newBeneficiary != address(0), "Beneficiary can't be zero");
    emit SetBeneficiary(beneficiary, newBeneficiary);

    beneficiary = newBeneficiary;

    return true;
  }
}