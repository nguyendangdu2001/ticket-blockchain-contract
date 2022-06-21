// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// import "hardhat/console.sol";

contract NFTTicketMarketplace is ERC721, Ownable {
    string private baseURI = "http://localhost:5001/api/event-ticket/data/";

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory uri) public onlyOwner {
        baseURI = uri;
    }

    struct Event {
        address owner;
        uint256 createdTime;
        uint256 startTime;
        uint256 endTime;
        string id;
        bool exist;
    }
    event EventCreated(
        address owner,
        uint256 createdTime,
        uint256 startTime,
        uint256 endTime,
        string id,
        uint256 onChainId
    );
    event EventUpdated(uint256 id, uint256 startTime, uint256 endTime);
    event EventDeleted(uint256 id);
    struct TicketType {
        uint256 eventId;
        uint256 createdTime;
        string id;
        uint256 price;
        uint256 startSellingTime;
        uint256 endSellingTime;
        int256 totalLimit;
        int256 currentLimit;
        bool exist;
    }
    event TicketTypeCreated(
        uint256 eventOnChainId,
        uint256 createdTime,
        string id,
        uint256 price,
        uint256 startSellingTime,
        uint256 endSellingTime,
        int256 totalLimit,
        int256 currentLimit,
        string eventId,
        uint256 onChainId
    );
    event TicketSold(
        uint256 tokenId,
        uint256 ticketTypeOnChainId,
        address ownerAddress,
        string ticketTypeId,
        int256 limitCurrent
    );
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _eventIds;
    Counters.Counter private _typeTicketIds;
    Counters.Counter private _itemsSold;
    Counters.Counter private _marketIds;

    uint256 listingPrice = 0.025 ether;

    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => Event) private idToEvent;
    mapping(uint256 => TicketType) private idToTicketType;
    mapping(uint256 => uint256) private idTokenToIdTicketType;

    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    event MarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold,
        uint256 onChainId
    );

    event MarketItemSold(uint256 onChainId);

    constructor() ERC721("Ticket Tokens", "TCKT") {
        // owner = payable(msg.sender);
    }

    /* Updates the listing price of the contract */
    function updateListingPrice(uint256 _listingPrice)
        public
        payable
        onlyOwner
    {
        listingPrice = _listingPrice;
    }

    /* Returns the listing price of the contract */
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function payForTicket(uint256 ticketTypeId)
        public
        payable
        returns (uint256)
    {
        TicketType storage ticketType = idToTicketType[ticketTypeId];
        require(ticketType.price > 0, "Ticket type not exsit");
        require(ticketType.price == msg.value, "Not correct amount of money");
        require(
            ticketType.startSellingTime > block.timestamp &&
                block.timestamp < idToTicketType[ticketTypeId].endSellingTime,
            "Not in selling time"
        );
        require(
            ticketType.totalLimit == -1 || ticketType.totalLimit > 0,
            "No ticket left"
        );
        if (ticketType.totalLimit != -1) ticketType.currentLimit--;
        uint256 tokenId = createToken();
        setTokenTicketTypeId(tokenId, ticketTypeId);
        emit TicketSold(
            tokenId,
            ticketTypeId,
            msg.sender,
            ticketType.id,
            ticketType.currentLimit
        );
        return tokenId;
    }

    function createEvent(
        uint256 startTime,
        uint256 endTime,
        string memory id
    ) public {
        _eventIds.increment();
        uint256 newEventId = _eventIds.current();
        idToEvent[newEventId] = Event(
            msg.sender,
            block.timestamp,
            startTime,
            endTime,
            id,
            true
        );
        emit EventCreated(
            msg.sender,
            block.timestamp,
            startTime,
            endTime,
            id,
            newEventId
        );
    }

    function updateEvent(
        uint256 eventId,
        uint256 startTime,
        uint256 endTime
    ) public {
        require(idToEvent[eventId].exist == true, "Not exists");
        idToEvent[eventId].startTime = startTime;
        idToEvent[eventId].startTime = endTime;

        emit EventUpdated(eventId, startTime, endTime);
    }

    function createTicketType(
        uint256 eventId,
        string memory id,
        uint256 price,
        uint256 startSellingTime,
        uint256 endSellingTime,
        int256 limit
    ) public {
        require(price > 0, "Price must be at least 1 wei");
        _typeTicketIds.increment();
        uint256 newEventId = _typeTicketIds.current();
        idToTicketType[newEventId] = TicketType(
            eventId,
            block.timestamp,
            id,
            price,
            startSellingTime,
            endSellingTime,
            limit,
            limit,
            true
        );
        Event storage eventItem = idToEvent[eventId];
        emit TicketTypeCreated(
            eventId,
            block.timestamp,
            id,
            price,
            startSellingTime,
            endSellingTime,
            limit,
            limit,
            eventItem.id,
            newEventId
        );
    }

    /* Mints a token and lists it in the marketplace */
    function createToken() public returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, newTokenId);

        // createMarketItem(newTokenId, price);
        return newTokenId;
    }

    function setTokenTicketTypeId(uint256 tokenId, uint256 ticketTypeId)
        internal
    {
        require(msg.sender == ownerOf(tokenId), "Have to be onwer of token");
        idTokenToIdTicketType[tokenId] = ticketTypeId;
    }

    function createMarketItem(uint256 tokenId, uint256 price) private {
        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        idToMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            price,
            false
        );

        _transfer(msg.sender, address(this), tokenId);
    }

    /* allows someone to resell a token they have purchased */
    function resellToken(uint256 tokenId, uint256 price) public payable {
        require(
            ownerOf(tokenId) == msg.sender,
            "Only item owner can perform this operation"
        );
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );
        _marketIds.increment();
        uint256 key = _marketIds.current();
        idToMarketItem[key] = MarketItem(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            price,
            false
        );

        _transfer(msg.sender, address(this), tokenId);
        emit MarketItemCreated(
            tokenId,
            msg.sender,
            address(this),
            price,
            false,
            key
        );
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function createMarketSale(uint256 marketId) public payable {
        uint256 price = idToMarketItem[marketId].price;
        address seller = idToMarketItem[marketId].seller;
        bool isSold = idToMarketItem[marketId].sold;
        uint256 tokenId = idToMarketItem[marketId].tokenId;
        require(
            msg.value == price,
            "Please submit the asking price in orsder to complete the purchase"
        );
        require(!isSold, "Item has sold");
        idToMarketItem[marketId].owner = payable(msg.sender);
        idToMarketItem[marketId].sold = true;
        idToMarketItem[marketId].seller = payable(address(0));
        _itemsSold.increment();
        _transfer(address(this), msg.sender, tokenId);
        payable(owner()).transfer(listingPrice);
        payable(seller).transfer(msg.value);
        emit MarketItemSold(marketId);
    }

    /* Returns all unsold market items */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _marketIds.current();
        uint256 unsoldItemCount = _marketIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(this)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items that a user has purchased */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items a user has listed */
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
