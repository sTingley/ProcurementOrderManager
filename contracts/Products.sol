// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IProducts} from "./Interfaces/IProducts.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

contract Products is
Initializable,
OwnableUpgradeable,
UUPSUpgradeable,
ERC165Upgradeable
{

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Interface ID - IManager
    bytes4 public constant INTERFACE_ID_IPRODUCTS = type(IProducts).interfaceId;

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
    * @dev This function accepts bytes4 argument, meant to represent the ID for the interface we want to check against.
    * @return `bool` returns a bool that specifies whether the Interface is supported by the contract
    */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable) returns (bool) {
        return interfaceId == INTERFACE_ID_IPRODUCTS || super.supportsInterface(interfaceId);
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


