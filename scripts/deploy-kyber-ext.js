const env = require("@nomiclabs/buidler");
const BigNumber = require("bignumber.js");

async function main() {
    const PooledCDAIKyberExtension = env.artifacts.require("PooledCDAIKyberExtension");
    const ext = await PooledCDAIKyberExtension.new();
    console.log(`Deployed PooledCDAIKyberExtension at ${ext.address}`);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });