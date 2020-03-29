const env = require("@nomiclabs/buidler");
const BigNumber = require("bignumber.js");

async function main() {
    const accounts = await env.web3.eth.getAccounts();

    const PooledCDAI = env.artifacts.require("PooledCDAI");
    const MetadataPooledCDAIFactory = env.artifacts.require("MetadataPooledCDAIFactory");

    // Deploy PooledCDAI template
    const template = await PooledCDAI.new();
    console.log(`Deployed PooledCDAI at ${template.address}`);
    await template.init("", "", [{
        dest: accounts[0],
        weight: 100
    }]);
    console.log('Initialized PooledCDAI template');

    // Deploy factory
    const factory = await MetadataPooledCDAIFactory.new(template.address);
    console.log(`Deployed MetadataPooledCDAIFactory at ${factory.address}`);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });