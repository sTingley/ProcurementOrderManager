// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProducts {

	struct Product {
		string name;
		uint256 cost;
	}

	event ProductCreated(uint256 productId, string name, uint256 cost);
	event ProductUpdated(uint256 productId, string name, uint256 cost);

	function createProduct(string memory _name, uint256 _cost) external returns (uint256);

	function updateProduct(uint256 productId, string memory _name, uint256 _cost) external;

	function getProductById(uint256 productId) external returns (string memory _name, uint256 _cost);

	function getProductQuote(uint256 productId, uint256 quantity) external view returns (uint256 quote);
}
