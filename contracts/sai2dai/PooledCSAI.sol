pragma solidity 0.5.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "../interfaces/CERC20.sol";


contract PooledCSAI is ERC20, Ownable {
    uint256 internal constant PRECISION = 10**18;

    address public constant CDAI_ADDRESS = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
    address public constant DAI_ADDRESS = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;

    string private _name;
    string private _symbol;

    address public beneficiary; // the account that will receive the interests from Compound

    event Mint(address indexed sender, address indexed to, uint256 amount);
    event Burn(address indexed sender, address indexed to, uint256 amount);
    event WithdrawInterest(
        address indexed sender,
        address beneficiary,
        uint256 amount,
        bool indexed inDAI
    );
    event SetBeneficiary(address oldBeneficiary, address newBeneficiary);

    /**
     * @dev Sets the values for `name` and `symbol`. Both of
     * these values are immutable: they can only be set once during
     * construction.
     */
    function init(
        string memory name,
        string memory symbol,
        address _beneficiary
    ) public {
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
        ERC20 dai = ERC20(DAI_ADDRESS);
        require(
            dai.transferFrom(msg.sender, address(this), amount),
            "Failed to transfer DAI from msg.sender"
        );

        // use `amount` DAI to mint cDAI
        CERC20 cDAI = CERC20(CDAI_ADDRESS);
        require(dai.approve(CDAI_ADDRESS, 0), "Failed to clear DAI allowance");
        require(
            dai.approve(CDAI_ADDRESS, amount),
            "Failed to set DAI allowance"
        );
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
        CERC20 cDAI = CERC20(CDAI_ADDRESS);
        require(cDAI.redeemUnderlying(amount) == 0, "Failed to redeem");

        // transfer DAI to `to`
        ERC20 dai = ERC20(DAI_ADDRESS);
        require(dai.transfer(to, amount), "Failed to transfer DAI to target");

        // emit event
        emit Burn(msg.sender, to, amount);

        return true;
    }

    function accruedInterestCurrent() public returns (uint256) {
        CERC20 cDAI = CERC20(CDAI_ADDRESS);
        return
            cDAI
                .exchangeRateCurrent()
                .mul(cDAI.balanceOf(address(this)))
                .div(PRECISION)
                .sub(totalSupply());
    }

    function accruedInterestStored() public view returns (uint256) {
        CERC20 cDAI = CERC20(CDAI_ADDRESS);
        return
            cDAI
                .exchangeRateStored()
                .mul(cDAI.balanceOf(address(this)))
                .div(PRECISION)
                .sub(totalSupply());
    }

    function withdrawInterestInDAI() public returns (bool) {
        // calculate amount of interest in DAI
        uint256 interestAmount = accruedInterestCurrent();

        // burn cDAI
        CERC20 cDAI = CERC20(CDAI_ADDRESS);
        require(cDAI.redeemUnderlying(interestAmount) == 0, "Failed to redeem");

        // transfer DAI to beneficiary
        ERC20 dai = ERC20(DAI_ADDRESS);
        require(
            dai.transfer(beneficiary, interestAmount),
            "Failed to transfer DAI to beneficiary"
        );

        emit WithdrawInterest(msg.sender, beneficiary, interestAmount, true);

        return true;
    }

    function withdrawInterestInCDAI() public returns (bool) {
        // calculate amount of cDAI to transfer
        CERC20 cDAI = CERC20(CDAI_ADDRESS);
        uint256 interestAmountInCDAI = accruedInterestCurrent()
            .mul(PRECISION)
            .div(cDAI.exchangeRateCurrent());

        // transfer cDAI to beneficiary
        require(
            cDAI.transfer(beneficiary, interestAmountInCDAI),
            "Failed to transfer cDAI to beneficiary"
        );

        // emit event
        emit WithdrawInterest(
            msg.sender,
            beneficiary,
            interestAmountInCDAI,
            false
        );

        return true;
    }

    function setBeneficiary(address newBeneficiary)
        public
        onlyOwner
        returns (bool)
    {
        require(newBeneficiary != address(0), "Beneficiary can't be zero");
        emit SetBeneficiary(beneficiary, newBeneficiary);

        beneficiary = newBeneficiary;

        return true;
    }

    function() external payable {
        revert("Contract doesn't support receiving Ether");
    }
}
