const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');

const { ethers } = require("hardhat");
const { expect } = require("chai");

const fixtures = require("./fixtures");

describe('Orders', function() {
	let ordersInstance;
	let productsInstance;
	let buyer;
	let seller;
	let rando;

  it('should deploy properly', async () => {
    
		const { owner, addr1, addr2, products, orders } = await loadFixture(fixtures.deployOrdersFixture);
		ordersInstance = orders;
		productsInstance = products;
		buyer = owner;
		seller = addr1;
		rando = addr2;
    await expect(orders.address).to.be.properAddress;
  });

	it('should retrieve the current Products address and use it to add products', async () => {
		
		let productsRef = await ordersInstance.productsContract();
		expect(productsRef).to.be.properAddress;
		await productsInstance.createProduct("p1", 10);
		await productsInstance.createProduct("p2", 5);
		await productsInstance.createProduct("p3", 20);
	})

	it('should add the user as a buyer', async () => {

		await ordersInstance.addBuyer(buyer.address);
		await expect(buyer.address).to.be.properAddress;		
	})

	it('Create an Order of products and emit OrderCreated event', async () => {

		let fauxSeller = seller.address;
		let products = [
			[1, 5],[2, 1],[3, 2] // [ [productId, quantity] ]
		]
		let _uniqueItemCount = products.length;
		let _deliveryTerms = "today";

		await ordersInstance.createOrder(buyer.address, fauxSeller, products, _uniqueItemCount, _deliveryTerms);
		let orderCount = await ordersInstance.orderCounter()
		await expect(orderCount).to.equal(1); //first order

		await expect(ordersInstance.connect(buyer)
		.createOrder(buyer.address, fauxSeller, products, _uniqueItemCount, _deliveryTerms))
		.to.emit(ordersInstance, 'OrderCreated')
		.withArgs(2, buyer.address, fauxSeller); //second order
	})

	it('Should retrieve the correct order count of 2', async () => {
		let orderCount = await ordersInstance.orderCounter()
		await expect(orderCount).to.equal(2);
	})

	it('Should retrieve (via orderId) order status and products', async () => {
		//order id 1 contains the elements in _products array
		let order = await ordersInstance.getOrderStatus(1);
		expect(order.products[0][0]).to.equal(1);
		expect(order.products[0][1]).to.equal(5);
		expect(order.status).to.equal(0); //status: CREATED
	})

	it('should update the quantity of a product in the order and emit OrderUpdated event', async () => {
		
		let newQuantity = 10;
		await expect (ordersInstance.updateProductQuantity(1, 1, newQuantity))
		.to.emit(ordersInstance, 'OrderUpdated')
		.withArgs(1, 0) //OrderStatus.
		let order = await ordersInstance.getOrderStatus(1);
		expect(order.products[0][0]).to.equal(1);
		expect(order.products[0][1]).to.equal(newQuantity);

	})

	//enum OrderStatus { Created, Confirmed, Shipped, Completed, Disputed, Cancelled }
	it('should confirm order as the seller and emit OrderUpdated event', async () => {

		await expect (ordersInstance.connect(seller).confirmOrder(1))
		.to.emit(ordersInstance, 'OrderUpdated')
		.withArgs(1, 1) //OrderStatus.Confirmed

	})

	it('should ship an order as a seller and emit OrderUpdated event', async () => {
		
		await expect (ordersInstance.connect(seller).shipOrder(1))
		.to.emit(ordersInstance, 'OrderUpdated')
		.withArgs(1, 2) //OrderStatus.Shipped

	})

	it('should complete the order and emit OrderUpdated event', async () => {
		await expect (ordersInstance.completeOrder(1))
		.to.emit(ordersInstance, 'OrderUpdated')
		.withArgs(1, 3) //OrderStatus.Completed
	})

	it('should let the admin deploy a new Products contract', async () => {

		const { products } = await loadFixture(fixtures.deployProductsFixture);
		ordersInstance.updateProductsContract(products.address);
		let productsAddress = await ordersInstance.productsContract();
		expect(productsAddress).to.equal(products.address);
	})

})

