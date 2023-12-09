// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IManager {

	event DisputeRaised(uint256 indexed orderId, address indexed auditor1, address indexed auditor2, string reason);
	event DisputeUnresolved(uint orderId);
	event DisputeResolved(uint256 orderId, string resolution);
	event InvoiceSystemIsListening(uint256 orderId);

	struct Dispute {
		uint256 orderId;
		address buyer;
		address seller;
		address[2] arbitrators;
		string reason;
		mapping(address => string) partyArguments;
		string resolution;
		bool resolved;
		uint timeCreated;
}

struct AuditTrail {
		address buyer;
		address seller;
		uint256 completedAt;
		bool disputed;
}

	function setOrdersContract(address _ordersContract) external;

	function registerBuyer(address _buyer) external;

	function registerSeller(address _seller) external;

	function addAuditor(address _auditor) external returns (bool result);

	function auditorExists(address _auditor) external returns (bool);

	function createOrder(address _buyer, address _seller, uint256[2][] memory _products, uint256 _uniqueItemCount, string memory _deliveryTerms) external returns (uint256 orderId);

	function updateOrderProductQuantity(uint256 orderId, uint256 productId, uint256 quantity) external returns (bool result);

	function confirmOrder(uint256 orderId) external;

	function shipOrder(uint orderId) external returns (uint256 shippingId);

	function disputeOrder(uint256 orderId, string memory reason) external returns (bool result);

	function toBytes(uint256 x) external returns (bytes memory b);

	function randomAssignArbitrator() external returns (uint rnum);

	function submitArgument(uint256 orderId, string memory argument) external;

	function retrieveArguments(uint256 disputeId) external view returns (string memory buyerArg, string memory sellerArg);

	function resolveDispute(uint256 orderId, string memory resolution, bool resolved) external returns (bool result);

	function completeOrder(uint256 orderId) external returns (uint256);
}
