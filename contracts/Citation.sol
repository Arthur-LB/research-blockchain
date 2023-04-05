// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./DB.sol";

/**
 * The Citation contract manages the citations of an article and distributes payments
 */
contract Citation is Destructible {
    address public dbAddress;
    uint public fee;

    constructor(address _dbAddress, uint _fee) {
        require(_dbAddress != address(0x0));
        require(_fee > 0, "Fee must be greater than zero");
        dbAddress = _dbAddress;
        fee = _fee;
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
        require(
            msg.value >= fee,
            "Deposit amount must be greater than or equal to fee"
        );

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
        require(
            articles[_title].citations.length > 0,
            "No citations added to the article"
        );
        // Calculate the total weight of the citations
        uint totalWeight = 0;
        for (uint i = 0; i < articles[_title].citations.length; i++) {
            totalWeight += articles[_title].citations[i].weight;
        }

        // Normalize the weights of the citations
        for (uint i = 0; i < articles[_title].citations.length; i++) {
            articles[_title].citations[i].weight =
                (articles[_title].citations[i].weight * 1 ether) /
                totalWeight;
        }

        // Distribute payments to the cited authors
        for (uint i = 0; i < articles[_title].citations.length; i++) {
            address citedAuthorAddress = articles[_title]
                .citations[i]
                .authorAddress;
            uint amount = (msg.value * articles[_title].citations[i].weight) /
                1 ether;
            citedAuthorAddress.transfer(amount);

            emit PaymentSent(
                _title,
                articles[_title].author,
                articles[_title].authorAddress,
                citedAuthorAddress,
                amount
            );
        }

        emit CitationsNormalized(
            _title,
            articles[_title].author,
            articles[_title].authorAddress
        );
    }

    /**

    Returns the metadata of an article
    */
    function getArticle(
        string calldata _title
    )
        external
        view
        returns (
            string memory title,
            string memory author,
            address authorAddress,
            string[] memory citations,
            string memory filecoinLink,
            bool deposited
        )
    {
        Article memory article = articles[_title];
        return (
            article.title,
            article.author,
            article.authorAddress,
            article.citations,
            article.filecoinLink,
            article.deposited
        );
    }
}
