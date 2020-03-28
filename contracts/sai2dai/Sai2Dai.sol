pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./PooledCSAI.sol";
import "../PooledCDAI.sol";
import "../MetadataPooledCDAIFactory.sol";
import "./ScdMcdMigration.sol";

contract Sai2Dai is Ownable {
    using SafeERC20 for IERC20;
    using SafeERC20 for PooledCSAI;

    uint256 public constant DEV_WEIGHT = 5;
    uint256 public constant BENEFICIARY_WEIGHT = 95;

    mapping (address => address) pSAI2pDAI;
    address public dev;

    MetadataPooledCDAIFactory public factory;
    IERC20 public constant sai = IERC20(0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359);
    IERC20 public constant dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ScdMcdMigration public constant mcdaiMigration = ScdMcdMigration(0xc73e0383F3Aff3215E6f04B0331D58CeCf0Ab849);

    constructor (address factoryAddress) public {
        dev = 0x332D87209f7c8296389C307eAe170c2440830A47;
        factory = MetadataPooledCDAIFactory(factoryAddress);
    }

    function migrate(address payable pSAIAddress, uint256 amount) public {
        // Transfer `amount` pSAI from `msg.sender`
        PooledCSAI pSAI = PooledCSAI(pSAIAddress);
        pSAI.safeTransferFrom(msg.sender, address(this), amount);

        // Burn `amount` pSAI for SAI
        pSAI.burn(address(this), amount);

        // Convert `amount` SAI to DAI
        sai.safeApprove(address(mcdaiMigration), amount);
        mcdaiMigration.swapSaiToDai(amount);

        // Create pDAI contract if not already created
        PooledCDAI pDAI;
        if (pSAI2pDAI[pSAIAddress] == address(0)) {
            PooledCDAI.Beneficiary[] memory beneficiaries = new PooledCDAI.Beneficiary[](2);
            beneficiaries[0] = PooledCDAI.Beneficiary({
                dest: pSAI.beneficiary(),
                weight: BENEFICIARY_WEIGHT
            });
            beneficiaries[1] = PooledCDAI.Beneficiary({
                dest: dev,
                weight: DEV_WEIGHT
            });
            pDAI = factory.createPCDAI(pSAI.name(), pSAI.symbol(), beneficiaries, false);
            pDAI.transferOwnership(pSAI.owner());
            pSAI2pDAI[pSAIAddress] = address(pDAI);
        } else {
            pDAI = PooledCDAI(pSAI2pDAI[pSAIAddress]);
        }

        // Mint `amount` pDAI for `msg.sender`
        dai.safeApprove(address(pDAI), amount);
        pDAI.mint(msg.sender, amount);
    }

    function setDev(address newDev) external onlyOwner {
        dev = newDev;
    }
}