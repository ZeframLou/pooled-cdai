# Pooled cDAI (pcDAI)
Pools DAI, converts it into Compound DAI (cDAI), and sends interests to a beneficiary. Users putting DAI into the pool receives Pooled cDAI (pcDAI), an ERC20 token which is 1-for-1 redeemable for DAI at any time.

## How it works
Compound accrues interest to cDAI by increasing `exchangeRate`, the amount of DAI you can redeem per cDAI. Therefore, you can calculate the current DAI value of the pool's cDAI using `exchangeRate * poolCDAIBalance`. To calculate the interest, simply subtract the total DAI deposited from that value: `exchangeRate * poolCDAIBalance - totalDAIDeposited`. pcDAI records the total deposit using `totalSupply`, since pcDAI is 1-for-1 redeemable for DAI.

Since DAI deposits & withdrawals add/subtract the same amount from both sides of the minus sign, they don't affect the interest calculation, so there's no need for lock periods.

## How to compile
```
npm install
truffle compile
```

## Technical details

### Roles
- Beneficiary: the account that receives the interest
- Owner: the account that can change the beneficiary, default is the creator of the pcDAI smart contract
- User: accounts that can deposit into/withdraw from the pool (all accounts)

### Creation
Call this function in `PooledCDAIFactory`

`function createPCDAI(string memory name, string memory symbol, address _beneficiary, bool renounceOwnership) public returns (PooledCDAI)`

### Usage

#### User actions

- `function mint(address to, uint256 amount) public returns (bool)`

Deposit `amount` DAI into pool, send minted pcDAI to `to`

- `function burn(address to, uint256 amount) public returns (bool)`

Burn `amount` pcDAI, send redeemed DAI to `to`

- `function withdrawInterestInDAI() public returns (bool)`

Withdraw accrued interest to beneficiary in DAI

- `function withdrawInterestInCDAI() public returns (bool)`

Withdraw accrued interest to beneficiary in cDAI

#### Owner actions

- `function setBeneficiary(address newBeneficiary) public onlyOwner returns (bool)`

Change the beneficiary to `newBeneficiary`

#### Helpers

- `function accruedInterestCurrent() public returns (uint256)`

Calculates the current accrued interest. It's not a `view` function, since it updates the `exchangeRate` of cDAI.

- `function accruedInterestStored() public view returns (uint256)`

Calculates the current accrued interest. It's a `view` function, but it uses the cDAI exchange rate at the last call to the cDAI smart contract, so it might not be up to date.
