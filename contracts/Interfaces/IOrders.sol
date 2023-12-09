// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOrders {

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

	event OrderCreated(uint256 orderId, address indexed buyer, address indexed seller);
	event OrderUpdated(uint256 orderId, OrderStatus status);

	function updateProductsContract(address _newContract) external;

	function setManagerAddress(address manager) external;

	function addBuyer(address _buyer) external;

	function addSeller(address _seller) external;

	function createOrder(address buyer, address seller, uint256[2][] memory products, uint256 uniqueItemCount, string memory deliveryTerms)
	external returns (uint256);

	function getOrderBuyerSeller(uint256 orderId) external view returns (address, address);

	function getOrderStatus(uint256 orderId) external view returns (uint256[2][] memory products, OrderStatus status);

	function getQuote(uint256 uniqueItemCount, uint256[2][] memory products) external view returns (uint256 quote);

	function updateProductQuantity(uint256 orderId, uint256 productId, uint256 quantity) external returns (bool updated);
	
	function confirmOrder(uint256 orderId) external returns (OrderStatus);
	
	function shipOrder(uint256 orderId) external returns (OrderStatus, uint256);

	function disputeOrder(uint256 orderId) external returns(address buyer, address seller);

	function completeOrder(uint256 orderId) external returns (uint);
}
