// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Products.sol";
import {IProducts} from "./Interfaces/IProducts.sol";
import {IOrders} from "./Interfaces/IOrders.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

//ERC165Upgradeable.sol
contract Orders is
Initializable,
OwnableUpgradeable,
UUPSUpgradeable,
ERC165Upgradeable
{

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	//uups upgradeable
	function initialize(address _productsContract) external initializer {
		require(_productsContract != address(0), "Products contract can not be a 0x0 address");
		admin = msg.sender;
		productsContract = Products(_productsContract);
		__Ownable_init(msg.sender);
		__UUPSUpgradeable_init();
	}
	
	/// @dev Interface ID - IOrders
	bytes4 public constant INTERFACE_ID_IORDERS = type(IOrders).interfaceId;

	/**
	* @dev This function accepts bytes4 argument, meant to represent the ID for the interface we want to check against.
	* @return `bool` returns a bool that specifies whether the Interface is supported by the contract
	*/
	function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable) returns (bool) {
		return interfaceId == INTERFACE_ID_IORDERS || super.supportsInterface(interfaceId);
	}
	
	/**
	* @param newImplementation address of the new contract implementation
	*/
	function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

	address public admin;

	//address private supplyChainServiceAcct; //Represent external supply chain system

	mapping(address => bool) public isBuyer;
	mapping(address => bool) public isSeller;

	enum OrderStatus { Created, Confirmed, Shipped, Completed, PaymentDue, Disputed }

	struct Order {
			address buyer;
			address seller;
			uint256[2][] products; //Store product IDs and their quantities instead of the entire product details
			uint256 uniqueItemCount;
			uint256 quoteTotal;
			string deliveryTerms;
			uint256 shippingId;
			uint256 timeCreated;
			uint256 lastUpdated;
			bool disputed; //will only be set in the case disputeOrder is called
			OrderStatus status;
	}

	mapping(uint256 => Order) public orders; //uint256 orderId is used to get an Order
	uint256 public orderCounter;

	Products public productsContract; //contains valid products
	address public managerContract;

	event OrderCreated(uint256 orderId, address indexed buyer, address indexed seller);
	event OrderUpdated(uint256 orderId, OrderStatus status);

	modifier onlyAdmin() {
			require(msg.sender == admin, "Not authorized");
			_;
	}

	modifier onlyManager() {
		require(msg.sender == managerContract);
		_;
	}
	
	modifier orderStatusIs(uint256 orderId, OrderStatus expectedStatus) {
		require(orders[orderId].status == expectedStatus, "Invalid order status");
		_;
	}

	function updateProductsContract(address _newContract) external onlyAdmin {
		productsContract = Products(_newContract);
	}

	function setManagerAddress(address manager) external onlyAdmin() {
		managerContract = manager;
	}

	/*In a complete implementation, we could use 'service accounts' or DIDs/keys tied
	to other external systems and expect them to send signed messages when for ex.,
		- loading new products
		- pulling out 'Completed' orders such that payments can be processed
	*/
	// function updateSupplyChainServiceAcct(address _newAddress) external onlyAdmin {
	// 	supplyChainServiceAcct = _newAddress;
	// }

	function addBuyer(address _buyer) external {
		isBuyer[_buyer] = true;
	}
	
	function addSeller(address _seller) external {
		isSeller[_seller] = true;
	}

	/** @notice Create a new Order as defined in the struct
	 * @dev This method will be called by the Manager which will assign the buyer
	 * @param buyer the buyer of the order
	 * @param seller the seller of the order 
	 * @param products a 2D array of the productId and quantity: [ [#id][#quantity], [#][#] ]
	 * @param uniqueItemCount the total count of the items since products array is dynamic
	 * @param deliveryTerms the terms of the delivery
	 * @return uint256 the return variables is the orderId which in this system == orderCounter
	 */
	function createOrder(address buyer, address seller, uint256[2][] memory products, uint256 uniqueItemCount, string memory deliveryTerms)
	external returns (uint256) {

		orderCounter++; //the first orderId will be 1
		Order storage newOrder = orders[orderCounter];
		newOrder.buyer = buyer;
		newOrder.seller = seller;
		newOrder.products = products;
		newOrder.uniqueItemCount = uniqueItemCount;
		newOrder.quoteTotal = this.getQuote(uniqueItemCount, products);
		newOrder.deliveryTerms = deliveryTerms;
		newOrder.timeCreated = block.timestamp;
		newOrder.lastUpdated = block.timestamp;
		newOrder.status = OrderStatus.Created;
		emit OrderCreated(orderCounter, msg.sender, seller);
		return orderCounter;
	}

	function getOrderBuyerSeller(uint256 orderId) external view returns (address, address) {
		Order storage o = orders[orderId]; 
		return (o.buyer, o.seller);
	}

	function getOrderStatus(uint256 orderId) external view returns (uint256[2][] memory products, OrderStatus status) {
		Order storage o = orders[orderId];
		products = o.products;
		status = o.status;
	}

	function getQuote(uint256 uniqueItemCount, uint256[2][] memory products) external view returns (uint256 quote) {
		//products stored as [ [id, quantity] , [id, quantity], [id, quantity] ]
		quote = 0;
		for(uint i = 0; i < uniqueItemCount; i++) {
			uint256 itemQuote = productsContract.getProductQuote(products[i][0], products[i][1]);
			quote += itemQuote;
		}
		return quote;
	}

	//Function can also be used to delete an item (set the quantity to 0)
	function updateProductQuantity(uint256 orderId, uint256 productId, uint256 quantity)
	external orderStatusIs(orderId, OrderStatus.Created) returns (bool updated) {
		
		updated = false;
		Order storage o = orders[orderId];
		for (uint i = 0; i< o.uniqueItemCount; i++) {
			if (o.products[i][0] == productId) {
				updated = true;
				o.products[i][1] = quantity;
				o.lastUpdated = block.timestamp;
			}
		}

		o.quoteTotal = this.getQuote(o.uniqueItemCount, o.products);

		emit OrderUpdated(orderId, o.status);

	}

	function confirmOrder(uint256 orderId) orderStatusIs(orderId, OrderStatus.Created) external returns (OrderStatus) {
		Order storage o = orders[orderId];
		o.status = OrderStatus.Confirmed;
		o.lastUpdated = block.timestamp;
		emit OrderUpdated(orderId, o.status);
		return o.status;
	
	}

	function shipOrder(uint256 orderId)
		external orderStatusIs(orderId, OrderStatus.Confirmed) returns (OrderStatus, uint256) {

			Order storage o = orders[orderId];
			o.shippingId = block.timestamp;
			o.status = OrderStatus.Shipped;
			o.lastUpdated = block.timestamp;
			emit OrderUpdated(orderId, o.status);

			return (o.status, o.shippingId);
			
		}

	function disputeOrder(uint256 orderId) orderStatusIs(orderId, OrderStatus.Shipped)
	external returns(address buyer, address seller) {

		Order storage disputedOrder = orders[orderId];
		disputedOrder.disputed = true;
		disputedOrder.lastUpdated = block.timestamp;
		emit OrderUpdated(orderId, disputedOrder.status);
		return (disputedOrder.buyer, disputedOrder.seller);

	}

	function completeOrder(uint256 orderId) orderStatusIs(orderId, OrderStatus.Shipped)  external returns (uint) {

		Order storage o = orders[orderId];
		require(o.buyer != address(0), "could not find order");
		o.status = OrderStatus.Completed;
		o.lastUpdated = block.timestamp;
		emit OrderUpdated(orderId, o.status);
		return block.timestamp;
	}
}
