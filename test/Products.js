const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');

const chai = require('chai');
const { expect } = chai;
// Enables very handy solidity matchers for chai: https://ethereum-waffle.readthedocs.io/en/latest/matchers.html#
const { solidity } = require('ethereum-waffle');
chai.use(solidity);

const fixtures = require("./fixtures");


describe('Products', function() {

  let testProductName = "product1"
  let testCost = 10;
  let productsInstance

  it('should deploy properly', async () => {
    const { products } = await loadFixture(fixtures.deployProductsFixture);
    productsInstance = products;
    expect(products.address).to.be.properAddress;
  });

  it('should create a product', async () => {

    await productsInstance.createProduct(testProductName, testCost);
    let productCounter = await productsInstance.productCounter();
    expect(productCounter).to.equal(1);
  });

  it('should retrieve a product name and cost by id', async () => {

    let [name, cost] = await productsInstance.getProductById(1);
    expect(name).to.equal(testProductName);
    expect(cost).to.equal(testCost);
  })

  it('should update a product name', async() => {

    let newName = "renamed";
    await productsInstance.updateProduct(1, newName, 10);
    let [name, cost] = await productsInstance.getProductById(1);
    expect(name).to.equal(newName);
  })

  it('should update a product cost', async() => {
    let newCost = 20;
    await productsInstance.updateProduct(1, "renamed", newCost);
    let [name, cost] = await productsInstance.getProductById(1);
    expect(cost).to.equal(newCost);
  })

  it('should get a product quote', async () => {
    let quote = await productsInstance.getProductQuote(1, 10); //id,quantity
    expect(quote).to.equal(200);
  })

  it('should create two more products', async() => {
    await productsInstance.createProduct("product2", 30);
    await productsInstance.createProduct("product3", 50);
    let productCounter = await productsInstance.productCounter();
    expect(productCounter).to.equal(3);
  })

  it("Should get a quote for a known product", async function () {
    let quantity = 10;
    let quote = await productsInstance.getProductQuote(1, quantity);
    await expect(quote).to.equal((20 * quantity)); //newCost
  })

})
