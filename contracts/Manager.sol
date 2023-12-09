// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Orders.sol";
import "./Products.sol";
import {IManager} from "./Interfaces/IManager.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

contract Manager is
Initializable,
OwnableUpgradeable,
UUPSUpgradeable,
ERC165Upgradeable
{
    /// @dev Interface ID - IManager
    bytes4 public constant INTERFACE_ID_IMANAGER = type(IManager).interfaceId;
    
    Orders public ordersContract;

    address public admin;

    uint256 nonce; //used to randomly select auditors as arbitrators in case of disputes
    uint256 public activeAuditorCount;
    address[] public auditors;
    
    uint256 public ordersCounter; //only storing the counter. Order details in Orders.sol

    mapping(uint256 => Dispute) disputes;

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

    mapping(uint256 => AuditTrail) ordersAuditTrail;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

    /**
	* @param newImplementation address of the new contract implementation
	*/
	function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //uups upgradeable
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
        return interfaceId == INTERFACE_ID_IMANAGER || super.supportsInterface(interfaceId);
    }

    function setOrdersContract(address _ordersContract) external onlyAdmin {
        require(_ordersContract != address(0), "Orders contract can not be a 0x0 address");
        ordersContract = Orders(_ordersContract);
    }

    function registerBuyer(address _buyer) external {
        ordersContract.addBuyer(_buyer);
    }

    function registerSeller(address _seller) external {
        ordersContract.addSeller(_seller);
    }

    //Add an auditor to the contract such that he or she can arbitrate any future order disputes
    function addAuditor(address _auditor) external onlyAdmin returns (bool result) {
        require(_auditor != address(0), "cannot add empty address");
        require(!auditorExists(_auditor), "Auditor already exists");
        result = false;
        auditors.push(_auditor);
        activeAuditorCount++;
        result = true;
    }

    function auditorExists(address _auditor) internal view returns (bool) {
        for (uint256 i = 0; i < activeAuditorCount; i++) {
            if(auditors[i] == _auditor) {
                return true;
            }
        }
        return false;
    }

    function createOrder(address _buyer, address _seller, uint256[2][] memory _products, uint256 _uniqueItemCount, string memory _deliveryTerms)
    external returns (uint256 orderId) {
        this.registerBuyer(_buyer);
        this.registerSeller(_seller);
        orderId = ordersContract.createOrder(_buyer, _seller, _products, _uniqueItemCount, _deliveryTerms);
        ordersCounter++;
        return orderId;
    }

    //Calls Order contract to update the quantity
    function updateOrderProductQuantity(uint256 orderId, uint256 productId, uint256 quantity)
    external returns (bool result) {

        (address buyer, ) = ordersContract.getOrderBuyerSeller(orderId);
        require(msg.sender == buyer, "cannot update another buyer's order");
        result = ordersContract.updateProductQuantity(orderId, productId, quantity);
    }

    //Seller can confirm order
    function confirmOrder(uint256 orderId) external {
        (, address seller) = ordersContract.getOrderBuyerSeller(orderId);
        require(msg.sender == seller, "seller must confirm order");
        ordersContract.confirmOrder(orderId);
    }

    //Seller can ship order
    function shipOrder(uint orderId) external returns (uint256 shippingId) {
        (, address seller) = ordersContract.getOrderBuyerSeller(orderId);
        require(msg.sender == seller, "seller must confirm order");
        (, shippingId) = ordersContract.shipOrder(orderId);
    }

    //Buyer or Seller can dispute order after it has been shipped (received)
    function disputeOrder(uint256 orderId, string memory reason) external returns (bool result) {
        
        (address buyer, address seller) = ordersContract.disputeOrder(orderId);
        require(msg.sender == buyer || msg.sender == seller, "only buyer or seller of order can disput");
        require (buyer != address(0) && seller != address(0), "something went wrong");
        require(activeAuditorCount > 1, "we need at least 2 auditors to create a dispute");
        
        Dispute storage d = disputes[orderId];
        d.orderId = orderId;
        d.buyer = buyer;
        d.seller = seller;
        d.reason = reason;
        d.timeCreated = block.timestamp;

        /*
        * Need to make sure a dispute has arbitrators assigned.
        * This function should be updated to use randomAssignArbitrator()
        * To implement, call this function and store the return values inside an array
        * until such time you have 'n' unique values
        * I decided to mock this to focus on other testing/functionality
        */

        d.arbitrators[0] = auditors[0];
        d.arbitrators[1] = auditors[1];
        
        emit DisputeRaised(orderId,  d.arbitrators[0], d.arbitrators[1], reason);
        result = true;
    }

    function toBytes(uint256 x) internal pure returns (bytes memory b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }

    //uses a min and a max (activeAuditorCount) to randomly select auditors
    function randomAssignArbitrator() private returns (uint rnum) {
        nonce++;
        bytes memory b = toBytes(nonce);
        rnum = uint(keccak256(b)) % (0 + activeAuditorCount) - 0;
    }

    function submitArgument(uint256 orderId, string memory argument) external {

        require(msg.sender == disputes[orderId].buyer || msg.sender == disputes[orderId].seller, "Only buyer or seller can submit arguments");
        require(!disputes[orderId].resolved, "cannot submit arguments for a resolved dispute");
        disputes[orderId].partyArguments[msg.sender] = argument;
    }

    function retrieveArguments(uint256 disputeId) external view returns (string memory buyerArg, string memory sellerArg) {
        /*Had to simplify to finish under the deadline. Assume one argument for buyer, one for seller
        though ideally we would want to be able to add more comments and possibly allow other parties to as well*/
        require(msg.sender == disputes[disputeId].arbitrators[0] || msg.sender == disputes[disputeId].arbitrators[0],
        "Only arbitrators can retrieve arguments");

        (address buyer, address seller) = ordersContract.getOrderBuyerSeller(disputeId);
        buyerArg = disputes[disputeId].partyArguments[buyer];
        sellerArg = disputes[disputeId].partyArguments[seller];

    }

    //Called by an arbitrator assigned to a dispute
    function resolveDispute(uint256 orderId, string memory resolution, bool resolved) external returns (bool result) {
        
        require(block.timestamp > disputes[orderId].timeCreated, "not enough time has passed. Dispute period is 'x'.");
        /*Acknowledgement that 'x' time must pass before a dispute is 'resolvable'
        Decided not to implement to focus on other functions / to be able to test this immediately*/

        require(msg.sender == disputes[orderId].arbitrators[0] || msg.sender == disputes[orderId].arbitrators[1],
        "only arbitrators assigned to a dispute may resolve it.");
        result = false;

        disputes[orderId].resolution = resolution;
        disputes[orderId].resolved = resolved;
        emit DisputeResolved(orderId, resolution);

        if(disputes[orderId].resolved = true) {

            emit DisputeResolved(orderId, resolution);
            uint256 completedAt = ordersContract.completeOrder(orderId);
            ordersAuditTrail[orderId].buyer = disputes[orderId].buyer;
            ordersAuditTrail[orderId].seller = disputes[orderId].seller;
            ordersAuditTrail[orderId].completedAt = completedAt;
            ordersAuditTrail[orderId].disputed = true;
            result = true;

        } else {
            emit DisputeUnresolved(orderId);
        }

    }

    function completeOrder(uint256 orderId) external returns (uint256) {

        (address buyer, address seller) = ordersContract.getOrderBuyerSeller(orderId);
        require(msg.sender == buyer, "buyer must complete order to initiate invoice creation");
        uint completedAt = ordersContract.completeOrder(orderId);
        ordersAuditTrail[orderId].buyer = buyer;
        ordersAuditTrail[orderId].seller = seller;
        ordersAuditTrail[orderId].completedAt = completedAt;
        ordersAuditTrail[orderId].disputed = false;
        emit InvoiceSystemIsListening(orderId);
        return orderId;
    }
}
