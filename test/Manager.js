
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const chai = require('chai');
const { expect } = chai;
// Enables very handy solidity matchers for chai: https://ethereum-waffle.readthedocs.io/en/latest/matchers.html#
const { solidity } = require('ethereum-waffle');
chai.use(solidity);

const fixtures = require("./fixtures");

let testOrder = [ [1, 1], [2, 2], [3, 4]]; // [ [#productId, #productCost], [], [] ... ]
let deliveryTerms = "standard";
let testNewQuantity = 20;

let managerInstance;
let ordersInstance;

let _admin, _buyer, _seller, _auditor1, _auditor2, _rando;

describe('Manager - Order Complete', function() {

	it('should deploy properly and set Orders contract inside Manager', async () => {

		const { owner, buyer, seller, auditor1, auditor2, unauthorized, manager } =
		await loadFixture(fixtures.deployManagerFixture);

		//deployOrdersFixture creates the first 3 products
		const { products, orders } = await fixtures.deployOrdersFixture();
		await expect(manager.address).to.be.properAddress;
		await expect(orders.address).to.be.properAddress;

		await orders.setManagerAddress(manager.address);
		
		managerInstance = manager;
		ordersInstance = orders;
		_admin = owner;
		_buyer = buyer;
		_seller = seller;
		_auditor1 = auditor1;
		_auditor2 = auditor2;
		_rando = unauthorized;
	})

	it('should set the Orders contract inside Manager', async () => {
		await managerInstance.setOrdersContract(ordersInstance.address);
		let ordersAddress = await managerInstance.ordersContract();
		await expect(ordersAddress).to.be.properAddress;
		await expect(ordersAddress).to.equal(ordersInstance.address);
	})

	it('should register 2 auditors', async ()=> {
		await managerInstance.addAuditor(await _auditor1.getAddress());
		await managerInstance.addAuditor(await _auditor2.getAddress());
	})

	it('should return an active auditor count of 2', async () => {
		let count = await managerInstance.activeAuditorCount();
		await expect(count).to.equal(2);
	})

	it('should create a new order', async () => {
		await managerInstance.createOrder(_buyer.getAddress(), _seller.getAddress(), testOrder,  testOrder.length, deliveryTerms)
		let orderCount = await managerInstance.ordersCounter();
		await expect(orderCount).to.equal(1);
	
	})

	it('will fail to update order product quantity if not buyer', async () => {
		await expect(managerInstance.updateOrderProductQuantity(1, 2, 20)).to.be.reverted;
	})

	it('will update order product quantity', async () => {
		await managerInstance.connect(_buyer).updateOrderProductQuantity(1, 2, testNewQuantity);
	})

	it('Order will return updated quantity', async () => {

		let { products, status } = await ordersInstance.getOrderStatus(1);
		expect(products[1][0]).to.equal(2); //we didnt change this
		expect(products[1][1]).to.equal(20); //testNewQuantity
		expect(status).to.equal(0); //OrderStatus.Created

	})

	it('will fail to confirm order if not seller', async () => {
		await expect(managerInstance.confirmOrder(1)).to.be.reverted;
	})

	it('will confirm the order', async () => {

		await managerInstance.connect(_seller).confirmOrder(1);

		let { products, status } = await ordersInstance.getOrderStatus(1);
		expect(status).to.equal(1); //OrderStatus.Confirmed

	})

	it('fail to update product(s) quantity after order is confirmed', async () => {
		await expect(managerInstance.connect(_buyer).updateOrderProductQuantity(1, 2, 10))
		.to.be.reverted;
	})

	it('will fail to ship the order if not seller', async () => {
		await expect(managerInstance.shipOrder(1)).to.be.reverted;
	})

	it('will ship the order', async () => {
		await managerInstance.connect(_seller).shipOrder(1);
		let { products, status } = await ordersInstance.getOrderStatus(1);
		expect(status).to.equal(2); //OrderStatus.Shipped
	})

	it('will fail to mark the order complete if not buyer', async () => {

		await expect(managerInstance.completeOrder(1)).to.be.reverted;
	})

	it('will mark order complete', async () => {
		await expect(managerInstance.connect(_buyer).completeOrder(1))
		.to.emit(managerInstance, 'InvoiceSystemIsListening')
		.withArgs(1) //orderId
		
		let { products, status } = await ordersInstance.getOrderStatus(1);
		expect(status).to.equal(3); //OrderStatus.Completed

	})


})


let testOrder2 = [ [1, 5], [2, 6] ];
//Create a second order with the same contracts

describe('Manager - Order Disputed', function() {

	it('will create a new order', async () => {
		await managerInstance.createOrder(_buyer.getAddress(), _seller.getAddress(), testOrder2,  testOrder2.length, deliveryTerms)
		let orderCount = await managerInstance.ordersCounter();
		await expect(orderCount).to.equal(2);
	})

	it('will confirm the order', async () => {

		let vals = await managerInstance.connect(_seller).confirmOrder(2);
		let { products, status } = await ordersInstance.getOrderStatus(2);
		expect(status).to.equal(1); //OrderStatus.Confirmed
	})

	it('will ship the order', async () => {
		await managerInstance.connect(_seller).shipOrder(2);
		let { products, status } = await ordersInstance.getOrderStatus(2);
		expect(status).to.equal(2); //OrderStatus.Shipped
	})

	it('will raise a dispute against the order and emit DisputeRaised event', async () => {
		let reasonForDispute = 'brokenItems';
		const _auditor1Addr = await _auditor1.getAddress();
		const _auditor2Addr = await _auditor2.getAddress();

		await expect(managerInstance.connect(_buyer).disputeOrder(2, reasonForDispute))
		.to.emit(managerInstance, "DisputeRaised")
		.withArgs(2, _auditor1Addr, _auditor2Addr, reasonForDispute)
	})

	it('unauth user cannot add comments to the dispute', async () => {
		await expect(managerInstance.submitArgument(2, "garbage")).to.be.reverted;
	})

	it('buyer will add comments (arguments) to the dispute (buyer)', async () => {
		await managerInstance.connect(_buyer).submitArgument(2, "brokenProductPictureURI");
	})

	it('seller will add comments (arguments) to the dispute', async () => {
		await managerInstance.connect(_seller).submitArgument(2, "oh");
	})

	it('random user cannot retrieve dispute info', async () => {
		await expect(managerInstance.connect(_rando).retrieveArguments(2)).to.be.reverted;
	})

	it('arbitrator of a dispute can resolve it after \'x\' period of time', async () => {
		let resolution = "buyerWins"
		await expect(managerInstance.connect(_auditor1).resolveDispute(2, resolution, true))
		.to.emit(managerInstance, "DisputeResolved")
		.withArgs(2, resolution);
	})



})
