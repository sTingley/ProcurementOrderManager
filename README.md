# Env variables setup

Create .env file in root folder and set variables `ALCHEMY_URL` and `PRIVATE_KEY`. If this code was to be deployed across (cloud) environments we would set an `ENV` value but this is not required at this time. For hardhat and mumbai networks set `ALCHEMY_URL = ""`. `PRIVATE_KEY` must be set to execute scripts.

# Deploy locally or on Polygon Mumbai testnet

local
```shell
npx hardhat node
npx hardhat deploy-contracts --network localhost
```
Mumbai
```shell
npx hardhat deploy-contracts --network PolygonMumbai
```
Of course make sure to fund any test MATIC account if deploying to Mumbai

## Run tests

```shell
npx hardhat test
```

## Run coverage

```shell
npx hardhat coverage
```

