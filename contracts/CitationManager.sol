// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./DB.sol";

/**
 * The CitationManager contract manages the citations of an article
 */
contract CitationManager is Destructible {
    address public dbAddress;

    constructor(address _dbAddress) {
        require(_dbAddress != address(0x0));
        dbAddress = _dbAddress;
    }

    struct Citation {
        string author;
        address authorAddress;
        uint weight;
    }

    struct Article {
        string title;
        string author;
        address authorAddress;
        string[] citations;
        string filecoinLink;
        bool deposited;
    }

    mapping(string => Article) private articles;

    event ArticleDeposited(
        string indexed _title,
        string _author,
        address _authorAddress,
        string _filecoinLink
    );
    event CitationAdded(
        string indexed _title,
        string _author,
        address _authorAddress,
        string _citedAuthor,
        address _citedAuthorAddress,
        uint _weight
    );
    event CitationsNormalized(
        string indexed _title,
        string _author,
        address _authorAddress
    );
    event PaymentSent(
        string indexed _title,
        string _author,
        address _authorAddress,
        address _citedAuthorAddress,
        uint _amount
    );

    /**
     * Deposits an article and its metadata
     */
    function depositArticle(
        string calldata _title,
        string calldata _author,
        string calldata _filecoinLink
    ) external payable {
        require(!articles[_title].deposited, "Article already deposited");
        require(msg.value > 0, "Deposit amount must be greater than zero");

        // Store the article metadata
        Article memory article = Article({
            title: _title,
            author: _author,
            authorAddress: msg.sender,
            citations: new string[](0),
            filecoinLink: _filecoinLink,
            deposited: true
        });

        articles[_title] = article;

        emit ArticleDeposited(_title, _author, msg.sender, _filecoinLink);
    }

    /**
     * Adds a citation to an article
     */
    function addCitation(
        string calldata _title,
        string calldata _citedAuthor,
        address _citedAuthorAddress,
        uint _weight
    ) external {
        require(articles[_title].deposited, "Article not deposited");
        require(
            _weight >= 0.1 ether && _weight <= 10 ether,
            "Invalid citation weight"
        );

        // Add the citation to the article
        Citation memory citation = Citation({
            author: _citedAuthor,
            authorAddress: _citedAuthorAddress,
            weight: _weight
        });

        articles[_title].citations.push(_citedAuthor);

        emit CitationAdded(
            _title,
            articles[_title].author,
            articles[_title].authorAddress,
            _citedAuthor,
            _citedAuthorAddress,
            _weight
        );
    }

    /**
     * Normalizes the weights of the citations and distributes payments to the cited authors
     */
    function normalizeCitations(string calldata _title) external payable {
        require(articles[_title].deposited, "Article not deposited");
        require(
            msg.sender == articles[_title].authorAddress,
            "Only the article author can normalize citations"
        );

        // Calculate the total weight of the citations
        uint totalWeight = 0;
        for (uint i = 0; i < articles[_title].citations.length; i++) {
            totalWeight += articles[_title].citations[i].weight;
        }

        // Calculate the normalized weight of each citation
        uint[] memory weightsNormalized = new uint[](
            articles[_title].citations.length
        );
        // Remove self-citations
        (
            string[] memory uniqueCitations,
            uint[] memory uniqueCitationWeights
        ) = removeSelfCitations(articles[_title].citations, weightsNormalized);

        // Calculate the amount to distribute to each cited author
        uint amountToDistribute = msg.value / 2;
        uint[] memory amountsToDistribute = new uint[](uniqueCitations.length);
        for (uint i = 0; i < uniqueCitations.length; i++) {
            amountsToDistribute[i] =
                (amountToDistribute * uniqueCitationWeights[i]) /
                totalWeightNormalized;
        }

        // Distribute the payments to the cited authors
        for (uint i = 0; i < uniqueCitations.length; i++) {
            address citedAuthorAddress = articles[uniqueCitations[i]]
                .authorAddress;
            (bool success, ) = citedAuthorAddress.call{
                value: amountsToDistribute[i]
            }("");
            require(success, "Payment to cited author failed");

            emit PaymentSent(
                _title,
                articles[_title].author,
                articles[_title].authorAddress,
                citedAuthorAddress,
                amountsToDistribute[i]
            );
        }

        // Update the article's deposited flag
        articles[_title].deposited = false;

        emit CitationsNormalized(
            _title,
            articles[_title].author,
            articles[_title].authorAddress
        );
    }

    /**
    Removes self-citations from a list of citations
    */
    function removeSelfCitations(
        string[] memory _citations,
        uint[] memory _weights
    )
        private
        pure
        returns (
            string[] memory uniqueCitations,
            uint[] memory uniqueCitationWeights
        )
    {
        uniqueCitations = new string;
        uniqueCitationWeights = new uint;
        uint count = 0;
        for (uint i = 0; i < _citations.length; i++) {
            if (
                keccak256(bytes(_citations[i])) !=
                keccak256(bytes(articles[_citations[i]].author))
            ) {
                uniqueCitations[count] = _citations[i];
                uniqueCitationWeights[count] = _weights[i];
                count++;
            }
        }

        assembly {
            mstore(uniqueCitations, count)
            mstore(uniqueCitationWeights, count)
        }
    }
}
