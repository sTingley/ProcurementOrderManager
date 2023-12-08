const { ethers, upgrades } = require('hardhat');

//Deploy Products.sol (Products.js)
const deployProductsFixture = async () => {
	const [owner, addr1, addr2, unauthorized] = await ethers.getSigners();

	const ProductFactory = await ethers.getContractFactory('Products');

	const products = await upgrades.deployProxy(ProductFactory, [], {
		initializer: 'initialize',
		kind: 'uups'
	});

	await products.deployed();

	return { owner, addr1, addr2, products };

};

//Deploy Orders.sol with a Products.sol address passed (Orders.js)
const deployOrdersFixture = async () => {

	const [owner, addr1, addr2, unauthorized] = await ethers.getSigners();

	  // Get the contract factories
		const ProductsFactory = await ethers.getContractFactory('Products');
		const OrdersFactory = await ethers.getContractFactory('Orders');

		// Deploy Products.sol
		const products = await upgrades.deployProxy(ProductsFactory, [], {
			initializer: 'initialize',
			kind: 'uups'
		})

		await products.deployed();

		// Deploy Orders.sol
		const orders = await upgrades.deployProxy(OrdersFactory, [products.address], {
			initializer: 'initialize',
			kind: 'uups'
		})
		await orders.deployed();		

		// Create 3 initial products inside Products.sol (name, cost)
		await products.createProduct("product1", 30);
		await products.createProduct("product2", 10);
		await products.createProduct("product3", 20);

		return { owner, addr1, addr2, products, orders }
}


//Deploy Manager.sol
const deployManagerFixture = async () => {

	const [owner, buyer, seller, auditor1, auditor2, unauthorized] = await ethers.getSigners();

	  // Get the contract factories
		const ManagerFactory = await ethers.getContractFactory('Manager')

		// Deploy Products.sol
		const manager = await upgrades.deployProxy(ManagerFactory, [], {
			initializer: 'initialize',
			kind: 'uups'
		})

		await manager.deployed();



		return { owner, buyer, seller, auditor1, auditor2, unauthorized, manager }
}


module.exports = { deployProductsFixture, deployOrdersFixture, deployManagerFixture };
