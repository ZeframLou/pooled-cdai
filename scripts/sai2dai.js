const env = require("@nomiclabs/buidler");
const BigNumber = require("bignumber.js");

async function main() {
    await env.run("compile");
    const accounts = await env.web3.eth.getAccounts();

    const PooledCDAI = env.artifacts.require("PooledCDAI");
    const Sai2Dai = env.artifacts.require("Sai2Dai");
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

    // Deploy Sai2Dai
    const migration = await Sai2Dai.new(factory.address);
    console.log(`Deployed Sai2Dai at ${migration.address}`);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });