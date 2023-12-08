// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Products is
Initializable,
OwnableUpgradeable,
UUPSUpgradeable
{

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    address public admin;
    
    struct Product {
        string name;
        uint256 cost;
    }

    //uint256 productId mapped to each Product
    mapping(uint256 => Product) public products;
    uint256 public productCounter;

    event ProductCreated(uint256 productId, string name, uint256 cost);
    event ProductUpdated(uint256 productId, string name, uint256 cost);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    function initialize() external initializer {
        admin = msg.sender;
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /**
     * @param newImplementation address of the new contract implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function createProduct(string memory _name, uint256 _cost) external onlyAdmin returns (uint256) {
        require(_cost > 0, "Product cost must be greater than 0");
        require(_cost % 1 == 0, "Product cost must be a whole number");
        productCounter++;
        Product storage newProduct = products[productCounter];
        newProduct.name = _name;
        newProduct.cost = _cost;

        emit ProductCreated(productCounter, _name, _cost);
        return productCounter;
    }

    function updateProduct(uint256 productId, string memory _name, uint256 _cost)
    external onlyAdmin {

        require(_cost > 0, "cost must be greater than 0");
        Product storage updatedProduct = products[productId];
        updatedProduct.name = _name;
        updatedProduct.cost = _cost;
        products[productId] = updatedProduct;

        emit ProductUpdated(productId, _name, _cost);
    }

    /**
     * @param productId id of the product
     * @return _name name of the product
     * @return _cost cost of the product
     */
    function getProductById(uint256 productId) external view returns (string memory _name, uint256 _cost) {
        require(products[productId].cost != 0, "something went wrong");
        _name = products[productId].name;
        _cost = products[productId].cost;
    }


    function getProductQuote(uint256 productId, uint256 quantity) external view returns (uint256 quote) {
        require(products[productId].cost != 0, "something went wrong");
        //need to add overflow protection here
        quote = products[productId].cost * quantity;
        return quote;
    }

}


