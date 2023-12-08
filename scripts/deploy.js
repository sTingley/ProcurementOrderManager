const { ethers, upgrades, run, network } = require('hardhat');

let signers;

const deployContracts = async function () {
	await run('compile');

	signers = await ethers.getSigners();
	console.log("we will use the first signer " + await signers[0].getAddress())

	let sender = await signers[0].getAddress();


	//***********************************
	//       			Products       				*
	//***********************************
	let productsAddress;

	// Get the contract factory
	const ProductsFactory = await ethers.getContractFactory('Products');
	// Deploy
	const products = await upgrades.deployProxy(ProductsFactory, [], {
		initializer: 'initialize',
		kind: 'uups'
	})

	await products.deployed();

	productsAddress = await products.address;
	console.log("Products address: " + productsAddress);

	//***********************************
	//       			 Orders       				*
	//***********************************
	let ordersAddress;

	const OrdersFactory = await ethers.getContractFactory('Orders');
	// Deploy
	const orders = await upgrades.deployProxy(OrdersFactory, [products.address], {
		initializer: 'initialize',
		kind: 'uups'
	})
	await orders.deployed();

	ordersAddress = await orders.address
	console.log("Orders address: " + ordersAddress);

	//***********************************
	//       			 Manager       				*
	//***********************************
	let managerAddress;

	const ManagerFactory = await ethers.getContractFactory('Manager');
	// Deploy
	const manager = await upgrades.deployProxy(ManagerFactory, [], {
		initializer: 'initialize',
		kind: 'uups'
	})
	await manager.deployed();

	managerAddress = await manager.address
	console.log("Manager address: " + managerAddress);

	const result = {
		contractAddresses: {
			products: productsAddress,
			orders: ordersAddress,
			manager: managerAddress
		},
		provider: network.provider
	};

	// If we needed to deploy across multiple environments we would expect an ENV variable and would store addresses appropriately
	// if (ENV) {
	// 	fs.writeFileSync(path.join('abi', `${ENV}-addresses.json`), JSON.stringify(result.contractAddresses));
	// }

	return result;
};

module.exports = { deployContracts };
