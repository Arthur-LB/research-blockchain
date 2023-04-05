// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./Citation.sol";
import "./zeppelin/math/SafeMath.sol";

contract Article {
    using SafeMath for uint256;

    string public title;
    string public author;
    address public authorAddress;
    string[] public citations;
    uint256 public price;
    uint256 public halfPrice;
    address[] public citedAuthors;
    mapping(address => uint256) public authorToCitedWeight;
    address public storageAddress;

    constructor(
        string memory _title,
        string memory _author,
        address _authorAddress,
        string[] memory _citations,
        uint256 _price,
        address _storageAddress
    ) {
        title = _title;
        author = _author;
        authorAddress = _authorAddress;
        citations = _citations;
        price = _price;
        storageAddress = _storageAddress;

        // Normalize weights and remove self citations
        uint256 totalWeight;
        uint256[] memory weights = new uint256[](_citations.length);
        address[] memory authors = new address[](_citations.length);
        for (uint256 i = 0; i < _citations.length; i++) {
            Citation citationContract = Citation(_citations[i]);
            address citedAuthor = citationContract.authorAddress();
            if (citedAuthor != authorAddress) {
                uint256 weight = citationContract.weight();
                weights[i] = weight;
                authors[i] = citedAuthor;
                totalWeight = totalWeight.add(weight);
            }
        }

        uint256 halfPriceAmount = price.div(2);
        halfPrice = halfPriceAmount;

        // Distribute half the fee based on normalized weights
        if (totalWeight > 0) {
            for (uint256 i = 0; i < _citations.length; i++) {
                if (authors[i] != address(0x0)) {
                    uint256 weight = weights[i];
                    address citedAuthor = authors[i];
                    uint256 citedWeight = weight.mul(halfPriceAmount).div(
                        totalWeight
                    );
                    authorToCitedWeight[citedAuthor] = citedWeight;
                    citedAuthors.push(citedAuthor);
                }
            }
        }
    }

    function downloadArticle() public view returns (string memory) {
        // TODO: Implement FileCoin storage download
    }

    function pay() public payable {
        require(msg.value >= price, "Not enough funds sent");
        uint256 change = msg.value.sub(price);
        uint256 authorShare = price.sub(halfPrice);
        payable(authorAddress).transfer(authorShare);
        for (uint256 i = 0; i < citedAuthors.length; i++) {
            address citedAuthor = citedAuthors[i];
            uint256 citedWeight = authorToCitedWeight[citedAuthor];
            uint256 amount = citedWeight;
            payable(citedAuthor).transfer(amount);
        }
        if (change > 0) {
            payable(msg.sender).transfer(change);
        }
    }
}
