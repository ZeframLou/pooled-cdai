pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "./PooledCDAIFactory.sol";


contract MetadataPooledCDAIFactory is PooledCDAIFactory {
    event CreatePoolWithMetadata(
        address sender,
        address pool,
        bool indexed renounceOwnership,
        bytes metadata
    );

    constructor(address _libraryAddress)
        public
        PooledCDAIFactory(_libraryAddress)
    {}

    function createPCDAIWithMetadata(
        string calldata name,
        string calldata symbol,
        PooledCDAI.Beneficiary[] calldata beneficiaries,
        bool renounceOwnership,
        bytes calldata metadata
    ) external returns (PooledCDAI) {
        PooledCDAI pcDAI = _createPCDAI(
            name,
            symbol,
            beneficiaries,
            renounceOwnership
        );
        emit CreatePoolWithMetadata(
            msg.sender,
            address(pcDAI),
            renounceOwnership,
            metadata
        );
    }
}
