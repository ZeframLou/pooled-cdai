pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "./lib/CloneFactory.sol";
import "./PooledCDAI.sol";


contract PooledCDAIFactory is CloneFactory {
    address public libraryAddress;

    event CreatePool(
        address sender,
        address pool,
        bool indexed renounceOwnership
    );

    constructor(address _libraryAddress) public {
        libraryAddress = _libraryAddress;
    }

    function createPCDAI(
        string calldata name,
        string calldata symbol,
        PooledCDAI.Beneficiary[] calldata beneficiaries,
        bool renounceOwnership
    ) external returns (PooledCDAI) {
        PooledCDAI pcDAI = _createPCDAI(
            name,
            symbol,
            beneficiaries,
            renounceOwnership
        );
        emit CreatePool(msg.sender, address(pcDAI), renounceOwnership);
        return pcDAI;
    }

    function _createPCDAI(
        string memory name,
        string memory symbol,
        PooledCDAI.Beneficiary[] memory beneficiaries,
        bool renounceOwnership
    ) internal returns (PooledCDAI) {
        address payable clone = _toPayableAddr(createClone(libraryAddress));
        PooledCDAI pcDAI = PooledCDAI(clone);
        pcDAI.init(name, symbol, beneficiaries);
        if (renounceOwnership) {
            pcDAI.renounceOwnership();
        } else {
            pcDAI.transferOwnership(msg.sender);
        }
        return pcDAI;
    }

    function _toPayableAddr(address _addr)
        internal
        pure
        returns (address payable)
    {
        return address(uint160(_addr));
    }
}
