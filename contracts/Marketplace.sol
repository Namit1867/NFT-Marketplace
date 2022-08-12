// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// only for debugging
// import "hardhat/console.sol";

/**
 * @title Marketplace contract for the NFT
 * @author Kartik Jain
 * @notice User can trade NFT as well as put it on auction
 */
interface IMarketplace {
    enum ErcStandard {
        ERC721,
        ERC1155
    }
    enum SaleType {
        Trade,
        Swap,
        Auction
    }

    struct Sell {
        uint256 listId; // ID for the marketplace listing
        uint256 tokenId; // ID for the ERC721 token
        address tokenContract; // Address for the ERC721 contract
        uint256 price; // The price of the token
        address tokenOwner; // The address that put the NFT on marketplace. It also receives the funds once the NFT is sold.
        ErcStandard erc;
        bool usdt; // The bool value to check the currency matic/usdt
    }

    struct ListedToken {
        uint256 saleId; // ID of the swap or trade
        SaleType saleType; // enum to define if it is trade or swap
    }

    struct Auction {
        uint256 listId; // ID for the marketplace listing
        uint256 tokenId; // ID for the ERC721 token
        address tokenContract; // Address for the ERC721 contract
        uint256 startTime; // The time at which the auction is started
        uint256 endTime; // The time at which the auction will end
        uint256 basePrice; // The minimum price of the NFT in the auction
        uint256 reservePrice; // The reserve price of the NFT in the auction
        address tokenOwner; // The address that should receive the funds once the NFT is sold
        uint256 incrementalBid; // The minimum amount of increment in amount for every successive bid
        address highestBidder; // The address of highest bidder for a particular auction
        uint256 bidAmount; // The amount that the bidder is willing to pay
        uint256 buyPrice;
        ErcStandard erc;
    }

    event SaleCreated(
        uint256 indexed saleId,
        uint256 indexed listId,
        uint256 amount,
        bool currency
    );

    event ListCreated(uint256 indexed listId, SaleType _type);

    event CancelTrade(uint256 indexed orderId);

    event Unlist(uint256 indexed listId);

    event TradePriceUpdated(
        uint256 indexed saleId,
        uint256 price,
        uint256 oldPrice
    );

    event BuyOrder(
        uint256 indexed orderId,
        uint256 price,
        address indexed buyer
    );

    event AuctionCreated(
        uint256 indexed auctionId,
        uint256 indexed endTime,
        uint256 basePrice,
        uint256 reservePrice
    );

    event WhiteListed(
        address indexed whitelistedAddress,
        address indexed whiteLister
    );

    event TreasuryUpdated(
        address indexed oldAddress,
        address indexed newAddress
    );

    event AuctionFeeUpdated(uint256 indexed oldValue, uint256 indexed newValue);

    event TradeFeeUpdated(uint256 indexed oldValue, uint256 indexed newValue);

    event CancelAuction(uint256 indexed auctionId);

    event Bidding(
        uint256 indexed auctionId,
        uint256 indexed biddingId,
        address bidder,
        uint256 amount
    );

    event AuctionSuccessful(
        uint256 indexed auctionId,
        uint256 indexed biddingId,
        address indexed bidder,
        uint256 amount
    );

    event EscrowUpdated(
        address indexed oldAddress,
        address indexed updatedAddress
    );

    event TimeExtended(
        uint256 indexed auctionId,
        uint256 indexed biddingId,
        uint256 indexed newTime
    );
    
    event TimeBufferUpdated(
        uint256 indexed oldTime,
        uint256 indexed newTime
    );

    event TokenUpdated(
        address indexed oldAddress,
        address indexed updatedAddress
    );


    /// @notice updates the address of treasury
    /// @dev onlyOwner function
    function updateTreasury(address _treasury) external;

    /// @notice updates the address of escrow
    /// @dev onlyOwner function
    function updateEscrow(address _escrow) external;

    /// @notice updates the address of USDT
    /// @dev onlyOwner function
    function updateTokenAddress(address _usdt) external;

    /// @notice updates treasury fees
    /// @dev onlyOwner function
    function updateTradeFee(uint16 _value) external;

    /// @notice updates time buffer
    /// @dev onlyOwner function
    function updateTimeBuffer(uint32 _value) external;

    /// @notice updates auction fees
    /// @dev onlyOwner function
    function updateAuctionFee(uint16 _value) external;

    /**
     * @notice whitelist the contracts that will be available on the marketplace for trade and auction
     * @param _contractAddresses contract Address that is to be whitelisted
     * @param _value true or false to whitelist/blacklist contracts
     *
     * @dev onlyOwner function
     *
     * @custom:note only contract address can be whitelisted and not the wallet addresses
     */
    function updateWhitelistStatus(
        address[] memory _contractAddresses,
        bool _value
    ) external;

    /**
     * @notice Create a Sale order i.e putting the for TRADE on marketplace
     * @param tokenId Id of the NFT that user wants to trade
     * @param tokenContract address of the contract of the NFT
     * @param price price of the NFT for which user wants to sell
     * @param usdt true if the user wants payment in usdt else false for matic
     * 
     * @notice This is a nonReentrant function
     * @notice Provided `tokenContract` is a whitelisted NFT contract address
     * 
     * @return saleId Id of the order created
     * @return listId Id of the list created on the marketplace
     */
    function createSaleOrder(
        uint256 tokenId,
        address tokenContract,
        uint256 price,
        bool usdt
    )
    external
    returns (uint256 saleId, uint256 listId);

    /**
     * @notice updates the price of the NFT that is put for trading
     * @param saleId Id of the trade for which the price will be updated
     * @param price The new price that will be set for the trade.
     * @notice trade must exist with this `saleId`
     */
    function updateSaleOrderPrice(uint256 saleId, uint256 price)
    external;

    /**
     * @notice External function to list the NFT on marketplace
     * @param orderId Id for swap/trade/auction
     * @param _type enum if it is trade/swap/auction
     *
     * @return listId listId for the marketplace
     */
    function listNftToMarketplace(uint256 orderId, SaleType _type)
    external
    returns (uint256 listId);

    /**
     * @notice External function to unlist the NFT on marketplace
     *
     * @return success If the unlisting is successful or not
     */
    function unlistNftFromMarketplace(uint256 listId)
    external
    returns (bool success);

    /**
     * @notice Creates an auction.
     * @param tokenId Id of the NFT that user wants to auction
     * @param tokenContract address of the contract of the NFT
     * @param duration time in seconds until which the auction will run
     * @param basePrice minimum price from where the auction will start
     * @param reservePrice The upper threshold after which the owner will complete the auction on owner's behalf.
     *                     in other word, the platform will swap the nft with the highest bid without the owner involvement.
     * @param incrementalBid the minimum price that must be greater than the previous bid
     *
     * @dev Store the auction details in the auctions mapping and emit an AuctionCreated event.
     *
     * @return auctionId Id of the auction
     * @return listId Id of the list created on the marketplace
     */
    function createAuction(
        uint256 tokenId,
        address tokenContract,
        uint256 duration,
        uint256 basePrice,
        uint256 reservePrice,
        uint256 buyPrice,
        uint256 incrementalBid
    ) 
    external
    returns (uint256 auctionId, uint256 listId);

    /**
     * @notice NFT owner can claim their NFT back in case no one has bid on the nft,
     * or auction has ended and no one crosses the reserve price, resulting in cancelling the auction
     * @param auctionId Id of the auction for which the user wants to claim their NFT
     * @notice auction must exist with this `auctionId`
     * 
     * @custom:note Auction can't be cancelled if the bidAmount reaches the reservePrice
     */
    function cancelAuction(uint256 auctionId) 
    external;

    /**
     * @notice user can successfully do the bidding after the nft is listed in the marketplace for the auction
     * @param auctionId Id of the auction for which the user wants to bid
     * @param amount the amount of usdt that the user wishes to bid
     * @notice auction must exist with this `auctionId`
     * 
     * @custom:note The user must contain the amount in their wallet before bidding
     * @custom:note The user must approved this contract for the amount that they wish to bid
     */
    function doBiding(
        uint256 auctionId,
        uint256 amount,
        uint256 time
    ) external;

    /**
     * @notice The auction owner can counter offer to the offers that they get during the bidding
     * @param biddingId Offer Id against which counter offer is given
     * @param amount The amount that the owner wish for their NFT
     * @param time Unix timestamp until which the offer will be valid
     * 
     * @notice An auction must exist for auction id with given
     * `biddingId` to give counter offer to bidder
     *
     * @return counterId returns the counterOffer Id
     */
    function auctionCounter(
        uint256 biddingId,
        uint256 amount,
        uint256 time
    )
    external
    returns (uint256 counterId);

    /**
     * @notice when the auction is completed and the the bidding amount does not cross the reserve price,
     * then its the auction's owner choice to transfer the NFT to any bidder else they can cancel Auction
     *
     * Even the user who have bid in the auction can finish the auction by accepting the counter Offer
     * given to them by the auction owner
     * 
     * @notice auction must exist with this `auctionId`
     *
     * @param auctionId Id of the auction for which bidding offer is made
     * @param biddingId Id of the bid for which user wants to the trade
     *
     * @custom:note if the bidding amount crosses reservePrice then the platform can transfer the NFT to the
     * highest bidder.
     */
    function finishAuction(uint256 auctionId, uint256 biddingId)
    external;

    /**
     * @notice when the auction is in progress and someone is willing to pay preset buy price for that auction
     *
     * 
     * @notice auction must exist with this `auctionId`
     *
     * @param auctionId Id of the auction for which user wants to buy at buyPrice
     *
     * @custom:note if the bidding amount currently greater than zero return the highest bidder money
     * to his/her wallet address.
     */
    function buyFromAuction(uint256 auctionId) 
    external;

    /**
     * @notice cancels the trade and send NFT back to the owner
     * @param orderId Id of the trade that the owner wants to cancel
     *
     * @notice sale order must exist with this `orderId`
     * @notice only escrow contract and owner of this contract can cancel the order
     * 
     * @custom:note orderId is different from listId
     */
    function cancelSell(uint256 orderId) 
    external;

    /**
     * @notice buy order that owner has put to trade.
     * @param orderId orderId against which user wants to buy the nft
     * 
     * @notice sale order must exist with this `orderId`
     *
     * @dev user needs to approve usdt to this contract before trading
     */
    function buyOrder(uint256 orderId)
    external
    payable;

    /**
     * @dev Returns the array of ID's of the NFT which are listed on the marketplace
     */
    function listTokens() external view returns (uint256[] memory);

    /**
     * @dev Returns the array of trading ID's of the NFT which are listed on the
     * marketplace for trading only
     */
    function tradedTokens() external view returns (uint256[] memory);

    /**
     * @dev Returns the array of whitelisted NFT contracts
     */
    function getWhitelistedContracts()
    external
    view
    returns (address[] memory);

    /**
     * @dev Returns the address of escrow contract
     */
    function getEscrow() external view returns (address);

    /**
     * @dev Returns the address of treasury wallet
     */
    function getTreasury() external view returns (address);

    /**
     * @dev Returns whether given address is whitelisted NFT address or not
     */
    function isWhitelisted(address _address) external view returns (bool);
    
    /**
     * @dev Returns the array bid IDs for given auctionId
     */
    function getAuctionBiddings(uint256 auctionId)
    external
    view
    returns (uint256[] memory);
    

}

interface IWithdraw {
    function claimNFTback(
        uint256 id,
        address tokenOwner,
        address tokenContract,
        uint256 tokenId,
        bool ercStandard
    ) external returns (bool);

    function storeNFT(
        uint256 id,
        address tokenOwner,
        address tokenContract,
        uint256 tokenId,
        bool ercStandard,
        uint8 saleType
    ) external returns (bool);

    function transferCurrency(
        address sender,
        address recepient,
        uint256 _amount,
        bool usdt,
        bool outgoing
    ) external payable;

    function getAuthorised(address _add) external view returns (bool);
}

contract Marketplace is ReentrancyGuard, IMarketplace, Ownable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    /// @notice structure to store the bidding Info
    struct BiddingInfo {
        uint256 id; // Id against which the bidding is made (for auction/offers)
        address bidder; // Address of the bidder
        uint256 amount; // Amount that bidder is willing to pay
        uint256 time; // Unix time until which the offer is valid
        address whitelist; // Address of the user for which this bidding is done
        bool counterOffer; // To check if this is an offer for auction OR counterOffer for an offer
    }

    /// @notice Owner's fees percentage
    /// Ex: If fee is 2.5% then tradeFeePercentage should be 250
    /// and if it's 10% then tradeFeePercentage should be 1000
    uint16 public tradeFeePercentage; // for trading
    uint16 public auctionFeePercentage; // for auction

    /// @notice stores all the ID's of the NFT which are listed on the marketplace
    uint256[] private listedTokens;
    mapping(uint256 => uint256) private listedTokensIndex; // stores the index of listedTokens ID's

    /// @notice stores all the trading ID's of the NFT which are listed on the marketplace for trading only
    uint256[] private tradeTokens;
    mapping(uint256 => uint256) private tradeTokensIndex; // stores the index of the tradeTokens ID's

    /// mapping for whitelisted contract addresses, no one can trade personal artwork on the marketplace
    mapping(address => bool) private isContractWhitelisted;

    /// for fetching the whitelisted contracts
    address[] private whitelistedContracts;
    mapping(address => uint256) private whitelistedContractsIndexMapping;

    /// @notice mapping of the auctionId to the array of bidId i.e. Id of the bid for a particular auction
    mapping(uint256 => uint256[]) public bidId; // auctionId => bidIds[]
    mapping(uint256 => BiddingInfo) public bidIdDetails; // bidId => BiddingInfo
    mapping(uint256 => uint256) public offerToCounter; // bidId => counterOfferId
    mapping(uint256 => BiddingInfo) public counterOfferDetails; // counterOfferId => BiddingInfo

    /// A mapping of all of the order currently running.
    mapping(uint256 => ListedToken) public listedNFTDetails;
    mapping(uint256 => Sell) public sellOrderDetails;
    mapping(uint256 => Auction) public auctionOrderDetails;

    // TODO: Needs to be changed for mainnet deployment
    // address public USDT = 0x8DC0fAF4778076A8a6700078A500C59960880F0F; // Only for Testing on frontend

    /// @notice USDT address on polygon mainnet
    // USDT can be constant, but decided not to, if in case USDT address gets changed.
    address public USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    bytes4 private constant INTERFACE_ID721 = 0x80ac58cd; // 721 interface id
    bytes4 private constant INTERFACE_ID1155 = 0xd9b67a26; // 1155 interface id

    /// @dev keeps tracks of Id's
    Counters.Counter private _listOrderTracker;
    Counters.Counter private _saleOrderTracker;
    Counters.Counter private _auctionIdTracker;
    Counters.Counter private _bidIdTracker;

    /// @notice address of the treasurer where the platform
    /// fees will be stored after trading/auction of NFT
    address private treasury;

    /// @notice address of the escrow contract
    address private escrow;

    uint32 private constant ONE_DAY = 24 * 60 * 60; // 01 day
    uint32 private constant THIRTY_DAYS = 30 * ONE_DAY; // 30 days
    
    uint32 private timeBuffer = 10 * 60; // 10 minutes

    /**
     * @notice Require that the specified ID exists
     */
    modifier tradeExists(uint256 tradeId) {
        require(_exists(tradeId, 0), "Trade doesn't exist");
        _;
    }

    /**
     * @notice Require that the specified ID exists
     */
    modifier auctionExist(uint256 auctionId) {
        require(_exists(auctionId, 2), "Auction doesn't exist");
        _;
    }

    /**
     * @notice Contract must be whitelisted before the NFTs are traded on the marketplace
     */
    modifier contractWhitelisted(address _contractAddress) {
        require(isContractWhitelisted[_contractAddress], "not Whitelisted");
        _;
    }

    /**
     * @param _treasury address of the treasurer
     * @param _tradeFeePercentage percentage of price that will goes to treasury (Trade)
     * @param _auctionFeePercentage percentage of price that will goes to treasury (Auction)
     */
    constructor(
        address _treasury,
        address _escrow,
        uint16 _tradeFeePercentage,
        uint16 _auctionFeePercentage
    ) {
        require(_treasury != address(0), "Invalid address");
        require(_escrow != address(0), "Zero Address");

        treasury = _treasury;
        escrow = _escrow;
        tradeFeePercentage = _tradeFeePercentage;
        auctionFeePercentage = _auctionFeePercentage;
    }

    /// Fallback functions to accept matic
    receive() external payable {}

    fallback() external payable {}

    /// @notice updates the address of treasury
    /// @dev onlyOwner function
    function updateTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Zero Address");
        address oldAddress = treasury;
        treasury = _treasury;

        emit TreasuryUpdated(oldAddress, _treasury);
    }

    /// @notice updates the address of escrow
    /// @dev onlyOwner function
    function updateEscrow(address _escrow) external onlyOwner {
        require(_escrow != address(0), "Zero Address");
        address oldAddress = escrow;
        escrow = _escrow;

        emit EscrowUpdated(oldAddress, _escrow);
    }

    /// @notice updates the address of USDT
    /// @dev onlyOwner function
    function updateTokenAddress(address _usdt) external onlyOwner {
        require(_usdt != address(0), "Zero Address");
        address oldAddress = USDT;
        USDT = _usdt;

        emit TokenUpdated(oldAddress, _usdt);
    }

    /// @notice updates treasury fees
    /// @dev onlyOwner function
    function updateTradeFee(uint16 _value) external onlyOwner {
        require(_value > 0, "Fee can't be 0");
        uint256 _oldValue = tradeFeePercentage;
        tradeFeePercentage = _value;

        emit TradeFeeUpdated(_oldValue, tradeFeePercentage);
    }

    function updateTimeBuffer(uint32 _value) external onlyOwner {
        require(_value > 0, "time can't be 0");

        if (timeBuffer != _value) {
            uint256 _oldValue = timeBuffer;
            timeBuffer = _value;
            emit TimeBufferUpdated(_oldValue, timeBuffer);
        }
    }

    /// @notice updates auction fees
    /// @dev onlyOwner function
    function updateAuctionFee(uint16 _value) external onlyOwner {
        require(_value > 0, "Fee can't be 0");
        uint256 oldValue = auctionFeePercentage;
        auctionFeePercentage = _value;

        emit AuctionFeeUpdated(oldValue, _value);
    }

    /**
     * @notice whitelist the contracts that will be available on the marketplace for trade and auction
     * @param _contractAddresses contract Address that is to be whitelisted
     * @param _value true or false to whitelist/blacklist contracts
     *
     * @dev onlyOwner function
     *
     * @custom:note only contract address can be whitelisted and not the wallet addresses
     */
    function updateWhitelistStatus(
        address[] memory _contractAddresses,
        bool _value
    ) external onlyOwner {
        for (uint256 i = 0; i < _contractAddresses.length; i++) {
            address _contractAddress = _contractAddresses[i];

            if (_contractAddress == address(0)) continue;

            uint256 size;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                size := extcodesize(_contractAddress)
            }
            require(size > 0, "Only Contracts are whitelisted");

            // only whitelist contracts if they are not already whitelisted
            if (isContractWhitelisted[_contractAddress] == !_value) {
                isContractWhitelisted[_contractAddress] = _value;

                if (_value) {
                    whitelistedContracts.push(_contractAddress);
                    whitelistedContractsIndexMapping[
                        _contractAddress
                    ] = whitelistedContracts.length;
                } else {
                    uint256 listIndex = whitelistedContractsIndexMapping[
                        _contractAddress
                    ];
                    uint256 lastIndex = whitelistedContracts.length - 1;

                    if (listIndex > 0) {
                        whitelistedContracts[
                            listIndex - 1
                        ] = whitelistedContracts[lastIndex];
                        whitelistedContractsIndexMapping[
                            whitelistedContracts[lastIndex]
                        ] = listIndex;
                        whitelistedContractsIndexMapping[_contractAddress] = 0;
                        whitelistedContracts.pop();
                    }
                }

                emit WhiteListed(_contractAddress, msg.sender);
            }
        }
    }

    /**
     * @notice Create a Sale order i.e putting the for TRADE on marketplace
     * @param tokenId Id of the NFT that user wants to trade
     * @param tokenContract address of the contract of the NFT
     * @param price price of the NFT for which user wants to sell
     * @param usdt true if the user wants payment in usdt else false for matic
     *
     * @return saleId Id of the order created
     * @return listId Id of the list created on the marketplace
     */
    function createSaleOrder(
        uint256 tokenId,
        address tokenContract,
        uint256 price,
        bool usdt
    )
        external
        nonReentrant
        contractWhitelisted(tokenContract)
        returns (uint256 saleId, uint256 listId)
    {
        require(tokenContract != address(0), "Zero Address");
        require(tokenId >= 0, "Invalid Id");
        require(price > 0, "Invalid Price");
        require(
            IERC165(tokenContract).supportsInterface(INTERFACE_ID721) ||
                IERC165(tokenContract).supportsInterface(INTERFACE_ID1155),
            "Interface not supported"
        );

        bool standard721;
        address tokenOwner;

        if (IERC165(tokenContract).supportsInterface(INTERFACE_ID721)) {
            tokenOwner = IERC721(tokenContract).ownerOf(tokenId);
            standard721 = true;
        } else {
            uint256 tokenBalance = IERC1155(tokenContract).balanceOf(
                msg.sender,
                tokenId
            );
            standard721 = false;
            require(tokenBalance > 0, "Insufficient NFT");
            tokenOwner = msg.sender;
        }

        require(msg.sender == tokenOwner, "Not owner");

        // creating saleId
        _saleOrderTracker.increment();
        saleId = _saleOrderTracker.current();

        // listing the NFT on marketplace
        listId = _listing(saleId, SaleType.Trade);

        sellOrderDetails[saleId] = Sell({
            listId: listId,
            tokenId: tokenId,
            tokenContract: tokenContract,
            price: price,
            tokenOwner: tokenOwner,
            erc: standard721 ? ErcStandard.ERC721 : ErcStandard.ERC1155,
            usdt: usdt
        });

        tradeTokens.push(saleId);
        tradeTokensIndex[saleId] = tradeTokens.length;

        // transferring the NFT from user to the escrow
        IWithdraw(escrow).storeNFT(
            saleId,
            tokenOwner,
            tokenContract,
            tokenId,
            standard721,
            0
        );

        emit SaleCreated(saleId, listId, price, usdt);
    }

    /**
     * @notice updates the price of the NFT that is put for trading
     * @param saleId Id of the trade for which the price will be updated
     * @param price The new price that will be set for the trade.
     */
    function updateSaleOrderPrice(uint256 saleId, uint256 price)
        external
        tradeExists(saleId)
    {
        Sell storage sell = sellOrderDetails[saleId];

        require(sell.tokenOwner == msg.sender, "Invalid User");

        uint256 oldPrice = sell.price;

        sell.price = price;

        emit TradePriceUpdated(saleId, price, oldPrice);
    }

    /**
     * @notice External function to list the NFT on marketplace
     * @param orderId Id for swap/trade/auction
     * @param _type enum if it is trade/swap/auction
     *
     * @return listId listId for the marketplace
     */
    function listNftToMarketplace(uint256 orderId, SaleType _type)
        external
        returns (uint256 listId)
    {
        require(IWithdraw(escrow).getAuthorised(msg.sender), "Invalid sender");
        listId = _listing(orderId, _type);
    }

    /**
     * @notice External function to unlist the NFT on marketplace
     *
     * @return success If the unlisting is successful or not
     */
    function unlistNftFromMarketplace(uint256 listId)
        external
        returns (bool success)
    {
        require(IWithdraw(escrow).getAuthorised(msg.sender), "Invalid sender");
        success = _unlisting(listId);
    }

    /**
     * @notice Creates an auction.
     * @param tokenId Id of the NFT that user wants to auction
     * @param tokenContract address of the contract of the NFT
     * @param duration time in seconds until which the auction will run
     * @param basePrice minimum price from where the auction will start
     * @param reservePrice The upper threshold after which the owner will complete the auction on owner's behalf.
     *                     in other word, the platform will swap the nft with the highest bid without the owner involvement.
     * @param incrementalBid the minimum price that must be greater than the previous bid
     *
     * @dev Store the auction details in the auctions mapping and emit an AuctionCreated event.
     *
     * @return auctionId Id of the auction
     * @return listId Id of the list created on the marketplace
     */
    function createAuction(
        uint256 tokenId,
        address tokenContract,
        uint256 duration,
        uint256 basePrice,
        uint256 reservePrice,
        uint256 buyPrice,
        uint256 incrementalBid
    ) external nonReentrant returns (uint256 auctionId, uint256 listId) {
        require(duration >= ONE_DAY && duration <= THIRTY_DAYS, "Invalid Time");
        require(basePrice > 0, "base price too less");
        require(
            reservePrice == 0 || reservePrice > basePrice,
            "Invalid reservePrice"
        );
        require(buyPrice >= reservePrice, "Buy price must be greater");
        require(
            IERC165(tokenContract).supportsInterface(INTERFACE_ID721) ||
                IERC165(tokenContract).supportsInterface(INTERFACE_ID1155),
            "Not supported Interface"
        );

        bool standard721;
        address tokenOwner;

        if (IERC165(tokenContract).supportsInterface(INTERFACE_ID721)) {
            tokenOwner = IERC721(tokenContract).ownerOf(tokenId);
            standard721 = true;
        } else {
            uint256 tokenBalance = IERC1155(tokenContract).balanceOf(
                msg.sender,
                tokenId
            );
            standard721 = false;
            require(tokenBalance > 0, "Insufficient NFT");
            tokenOwner = msg.sender;
        }

        require(msg.sender == tokenOwner, "Invalid token Owner");

        _auctionIdTracker.increment();
        auctionId = _auctionIdTracker.current();

        listId = _listing(auctionId, SaleType.Auction);

        auctionOrderDetails[auctionId] = Auction({
            listId: listId,
            tokenId: tokenId,
            tokenContract: tokenContract,
            basePrice: basePrice,
            endTime: block.timestamp + duration,
            startTime: block.timestamp,
            reservePrice: reservePrice,
            tokenOwner: tokenOwner,
            incrementalBid: incrementalBid,
            highestBidder: address(0),
            buyPrice: buyPrice,
            erc: standard721 ? ErcStandard.ERC721 : ErcStandard.ERC1155,
            bidAmount: 0
        });

        // transferring the NFT from user to the escrow
        IWithdraw(escrow).storeNFT(
            auctionId,
            tokenOwner,
            tokenContract,
            tokenId,
            standard721,
            2
        );

        emit AuctionCreated(auctionId, duration, basePrice, reservePrice);
    }

    /**
     * @notice NFT owner can claim their NFT back in case no one has bid on the nft,
     * or auction has ended and no one crosses the reserve price, resulting in cancelling the auction
     * @param auctionId Id of the auction for which the user wants to claim their NFT
     *
     * @custom:note Auction can't be cancelled if the bidAmount reaches the reservePrice
     */
    function cancelAuction(uint256 auctionId) external auctionExist(auctionId) {
        Auction storage auc = auctionOrderDetails[auctionId];

        if (msg.sender != escrow) {
            require(msg.sender == auc.tokenOwner, "Invalid Owner");
            require(
                bidId[auctionId].length == 0 ||
                    block.timestamp > auctionOrderDetails[auctionId].endTime,
                "Auction is running"
            );
            if (auc.bidAmount >= auc.reservePrice && auc.reservePrice != 0) {
                revert("Finish the bidding");
            }
        }

        _deleteAuction(
            auctionId,
            auc.tokenOwner,
            auctionOrderDetails[auctionId].tokenContract,
            auctionOrderDetails[auctionId].tokenId
        );

        emit CancelAuction(auctionId);
    }

    /**
     * @notice user can successfully do the bidding after the nft is listed in the marketplace for the auction
     * @param auctionId Id of the auction for which the user wants to bid
     * @param amount the amount of usdt that the user wishes to bid
     *
     * @custom:note The user must contain the amount in their wallet before bidding
     * @custom:note The user must approved this contract for the amount that they wish to bid
     */
    function doBiding(
        uint256 auctionId,
        uint256 amount,
        uint256 time
    ) external auctionExist(auctionId) {
        Auction storage auc = auctionOrderDetails[auctionId];

        // address curr = auc.usdt ? USDT : WMATIC;

        require(msg.sender != auc.tokenOwner, "You are Owner");
        require(
            amount <= IERC20(USDT).balanceOf(msg.sender),
            "Insufficient Amount"
        );
        require(
            amount <= IERC20(USDT).allowance(msg.sender, escrow),
            "Not Approved"
        );

        require(amount >= auc.basePrice, "less than base price"); // can't bid less than base price
        require(block.timestamp <= auc.endTime, "Auction Ended"); // can't bid after auction time is ended
        require(time >= ONE_DAY && time <= THIRTY_DAYS, "Max 30 days"); // min 1 day, max 30 days

        /// user can never bid less than lastBidAmount + incrementalBid
        require(amount >= auc.bidAmount + auc.incrementalBid, "Under Min Cap");

        /// if the bidding amount is greater than reserve price and last bid, then the tokens of the new bid will be transferred
        /// here and the tokens of the previous bidder will get transferred to the previous bidder.
        if (amount >= auc.reservePrice && auc.reservePrice != 0) {
            // IERC20(USDT).safeTransferFrom(msg.sender, escrow, amount);
            IWithdraw(escrow).transferCurrency(msg.sender, msg.sender, amount, true, false);

            if (
                auc.highestBidder != address(0) &&
                auc.bidAmount >= auc.reservePrice &&
                auc.reservePrice != 0
            ) {
                IWithdraw(escrow).transferCurrency(
                    auc.highestBidder,
                    auc.highestBidder,
                    auc.bidAmount,
                    true,
                    true
                );
            }
        }

        // updating the new bidder and amount for that auction
        auc.highestBidder = msg.sender;
        auc.bidAmount = amount;

        _bidIdTracker.increment();
        uint256 biddingId = _bidIdTracker.current();

        bidId[auctionId].push(biddingId);

        bidIdDetails[biddingId] = BiddingInfo({
            id: auctionId,
            bidder: msg.sender,
            time: block.timestamp + time,
            amount: amount,
            whitelist: auc.tokenOwner,
            counterOffer: false
        });

        /// If the last 10 minutes are left for the auction, and bidders bid in the auction,
        /// then the auction duration will extend for another 10 mins
        if (auc.endTime - block.timestamp <= timeBuffer) {
            auc.endTime = block.timestamp + timeBuffer;
            emit TimeExtended(auctionId, biddingId, auc.endTime);
        }

        emit Bidding(auctionId, biddingId, msg.sender, amount);
    }

    /**
     * @notice The auction owner can counter offer to the offers that they get during the bidding
     * @param biddingId Offer Id against which counter offer is given
     * @param amount The amount that the owner wish for their NFT
     * @param time Unix timestamp until which the offer will be valid
     *
     * @return counterId returns the counterOffer Id
     */
    function auctionCounter(
        uint256 biddingId,
        uint256 amount,
        uint256 time
    )
        external
        auctionExist(bidIdDetails[biddingId].id)
        returns (uint256 counterId)
    {
        BiddingInfo storage bid = bidIdDetails[biddingId];

        require(bid.time >= block.timestamp, "Offer Expired");
        require(bid.whitelist == msg.sender, "Invalid sender");
        require(time >= ONE_DAY && time <= THIRTY_DAYS, "Max 30 days");

        counterId = uint256(keccak256(abi.encodePacked(msg.sender, biddingId)));

        counterOfferDetails[counterId] = BiddingInfo({
            id: biddingId,
            bidder: msg.sender,
            time: block.timestamp + time,
            amount: amount,
            whitelist: bid.bidder,
            counterOffer: true
        });
    }

    /**
     * @notice when the auction is completed and the the bidding amount does not cross the reserve price,
     * then its the auction's owner choice to transfer the NFT to any bidder else they can cancel Auction
     *
     * Even the user who have bid in the auction can finish the auction by accepting the counter Offer
     * given to them by the auction owner
     *
     * @param auctionId Id of the auction for which bidding offer is made
     * @param biddingId Id of the bid for which user wants to the trade
     *
     * @custom:note if the bidding amount crosses reservePrice then the platform can transfer the NFT to the
     * highest bidder.
     */
    function finishAuction(uint256 auctionId, uint256 biddingId)
        external
        auctionExist(auctionId)
    {
        Auction storage auc = auctionOrderDetails[auctionId];
        BiddingInfo memory bid;
        address sender;

        if (msg.sender == owner() || msg.sender == auc.tokenOwner) {
            // This if condition implies that biddingId will be offerId
            bid = bidIdDetails[biddingId];

            bool canExec;

            require(bid.id == auctionId, "Invalid Bid");
            require(bid.counterOffer == false, "No counter Offer");

            if (
                msg.sender == owner() &&
                bid.amount >= auc.reservePrice &&
                auc.reservePrice != 0
            ) {
                require(auc.bidAmount == bid.amount, "Select highest Bid");
                sender = auc.highestBidder;
                canExec = true;
            }
            else if (auc.tokenOwner == msg.sender) {
                if (auc.bidAmount >= auc.reservePrice && auc.reservePrice != 0) {
                    // If the bidAmount reaches the reserve price then the highest bid must be selected,
                    // else the auction owner can choose lower bid also
                    require(auc.bidAmount == bid.amount, "Select highest Bid");
                    sender = auc.highestBidder;
                }
                canExec = true;
            }

            require(canExec, "Invalid Caller");

            /// transfering ERC20 from user to escrow address
            if (bid.amount < auc.reservePrice || auc.reservePrice == 0) {
                IWithdraw(escrow).transferCurrency(
                    bid.bidder,
                    bid.bidder,
                    bid.amount,
                    true,
                    false
                );
                sender = bid.bidder;
            }
        } else {
            // else condition implies that biddingId will be counterOfferId
            bid = counterOfferDetails[biddingId];

            require(bid.counterOffer, "Not CounterOffer");
            require(bid.time >= block.timestamp, "Offer Expired");
            require(bid.whitelist == msg.sender, "Invalid sender");
            require(
                bid.amount <= IERC20(USDT).balanceOf(bid.whitelist),
                "Insufficient Amount"
            );
            require(
                IERC20(USDT).allowance(bid.whitelist, escrow) >= bid.amount,
                "Insufficient Approval"
            );

            if (
                auc.highestBidder != address(0) &&
                auc.bidAmount >= auc.reservePrice &&
                auc.reservePrice != 0
            ) {
                IWithdraw(escrow).transferCurrency(
                    auc.highestBidder,
                    auc.highestBidder,
                    auc.bidAmount,
                    true,
                    true
                );
            }

            IWithdraw(escrow).transferCurrency(
                msg.sender,
                msg.sender,
                bid.amount,
                true,
                false
            );
            sender = msg.sender;
        }

        _unlisting(auc.listId);

        /// caculating platform fees
        uint256 treasuryCut = (bid.amount * auctionFeePercentage) / 10000;

        IWithdraw(escrow).transferCurrency(sender, treasury, treasuryCut, true, true);
        uint256 buyersAmount = bid.amount - treasuryCut;
        IWithdraw(escrow).transferCurrency(
            sender,
            auc.tokenOwner,
            buyersAmount,
            true,
            true
        );

        bool ercStandard = (auc.erc == ErcStandard.ERC721) ? true : false;

        IWithdraw(escrow).claimNFTback(
            auctionId,
            bid.bidder,
            auc.tokenContract,
            auc.tokenId,
            ercStandard
        );

        delete auctionOrderDetails[auctionId];

        emit AuctionSuccessful(auctionId, biddingId, bid.bidder, bid.amount);
    }

    function buyFromAuction(uint256 auctionId) external auctionExist(auctionId) {
        Auction storage auc = auctionOrderDetails[auctionId];

        require(msg.sender != auc.tokenOwner, "You are Owner");
        require(block.timestamp <= auc.endTime, "Auction Ended");
        require(
                auc.buyPrice <= IERC20(USDT).balanceOf(msg.sender),
                "Insufficient Amount"
            );
        require(
            IERC20(USDT).allowance(msg.sender, escrow) >= auc.buyPrice,
            "Insufficient Approval"
        );

        if (
                auc.highestBidder != address(0) &&
                auc.bidAmount >= auc.reservePrice &&
                auc.reservePrice != 0
            ) {
                IWithdraw(escrow).transferCurrency(
                    auc.highestBidder,
                    auc.highestBidder,
                    auc.bidAmount,
                    true,
                    true
                );
            }
        
        IWithdraw(escrow).transferCurrency(
                msg.sender,
                msg.sender,
                auc.buyPrice,
                true,
                false
            );

        _unlisting(auc.listId);

        /// caculating platform fees
        uint256 treasuryCut = (auc.buyPrice * auctionFeePercentage) / 10000;

        IWithdraw(escrow).transferCurrency(msg.sender, treasury, treasuryCut, true, true);
        uint256 buyersAmount = auc.buyPrice - treasuryCut;
        IWithdraw(escrow).transferCurrency(
            msg.sender,
            auc.tokenOwner,
            buyersAmount,
            true,
            true
        );

        bool ercStandard = (auc.erc == ErcStandard.ERC721) ? true : false;

        IWithdraw(escrow).claimNFTback(
            auctionId,
            msg.sender,
            auc.tokenContract,
            auc.tokenId,
            ercStandard
        );

        if (bidId[auctionId].length > 0) {
            delete bidId[auctionId];
        }

        delete auctionOrderDetails[auctionId];
    }

    /**
     * @notice cancels the trade and send NFT back to the owner
     * @param orderId Id of the trade that the owner wants to cancel
     *
     * @custom:note orderId is different from listId
     */
    function cancelSell(uint256 orderId) external tradeExists(orderId) {
        Sell storage sell = sellOrderDetails[orderId];
        address owner = sell.tokenOwner;

        if (msg.sender != escrow) {
            require(msg.sender == owner, "Invalid sender");
        }

        // unlisting nft from marketplace
        _unlisting(sell.listId);

        bool ercStandard = (sell.erc == ErcStandard.ERC721) ? true : false;

        if (msg.sender != escrow) {
            // transferring nft back to token Owner
            IWithdraw(escrow).claimNFTback(
                orderId,
                owner,
                sell.tokenContract,
                sell.tokenId,
                ercStandard
            );
        }

        uint256 listIndex = tradeTokensIndex[orderId];
        uint256 lastIndex = tradeTokens.length - 1;

        if (listIndex > 0) {
            tradeTokens[listIndex - 1] = tradeTokens[lastIndex];
            tradeTokensIndex[tradeTokens[lastIndex]] = listIndex;
            tradeTokensIndex[orderId] = 0;
            tradeTokens.pop();

            delete sellOrderDetails[orderId];
        }

        emit CancelTrade(orderId);
    }

    /**
     * @notice buy order that owner has put to trade.
     * @param orderId orderId against which user wants to buy the nft
     *
     * @dev user needs to approve usdt to this contract before trading
     */
    function buyOrder(uint256 orderId)
        external
        payable
        tradeExists(orderId)
        nonReentrant
    {
        require(treasury != address(0), "Invalid Treasury");

        Sell storage sell = sellOrderDetails[orderId];

        require(msg.sender != sell.tokenOwner, "You are Owner");

        uint256 price = sell.price;
        uint256 treasuryCut = (price * tradeFeePercentage) / 10000;

        // updates the balance of treasury and seller to be claimed later
        if (sell.usdt) {
            // TODO:
            // transfers the matic/usdt into the escrow contract
            IWithdraw(escrow).transferCurrency(
                msg.sender,
                msg.sender,
                price,
                sell.usdt,
                false
            );

            IWithdraw(escrow).transferCurrency(
                msg.sender,
                treasury,
                treasuryCut,
                true,
                true
            );
            uint256 buyersAmount = price - treasuryCut;
            IWithdraw(escrow).transferCurrency(
                msg.sender,
                sell.tokenOwner,
                buyersAmount,
                true,
                true
            );
        } else {
            IWithdraw(escrow).transferCurrency{value: price}(
                msg.sender,
                msg.sender,
                price,
                sell.usdt,
                false
            );

            IWithdraw(escrow).transferCurrency(
                msg.sender,
                treasury,
                treasuryCut,
                false,
                true
            );
            uint256 buyersAmount = price - treasuryCut;
            IWithdraw(escrow).transferCurrency(
                msg.sender,
                sell.tokenOwner,
                buyersAmount,
                false,
                true
            );
        }

        bool ercStandard = (sell.erc == ErcStandard.ERC721) ? true : false;

        // transfers the nft to the msg.sender
        IWithdraw(escrow).claimNFTback(
            orderId,
            msg.sender,
            sell.tokenContract,
            sell.tokenId,
            ercStandard
        );

        // unlist the nft from marketplace
        _unlisting(sell.listId);

        uint256 listIndex = tradeTokensIndex[orderId];
        uint256 lastIndex = tradeTokens.length - 1;

        if (listIndex > 0) {
            tradeTokens[listIndex - 1] = tradeTokens[lastIndex];
            tradeTokensIndex[tradeTokens[lastIndex]] = listIndex;
            tradeTokensIndex[orderId] = 0;
            tradeTokens.pop();
        }

        // If the buyer sends more amount than the price,
        // the extra amount is transferred back to the buyer
        if (!sell.usdt && (msg.value - price) > 0) {
            uint256 bal = address(this).balance;
            uint256 amount = msg.value - price;
            require(bal >= amount, "Insufficient Fund");

            payable(msg.sender).transfer(amount);

            require(address(this).balance == bal - amount, "Err");
        }

        delete sellOrderDetails[orderId];

        emit BuyOrder(orderId, price, msg.sender);
    }

    /// used in the modifier to check if the Id's are valid
    function _exists(uint256 id, uint8 saleType) internal view returns (bool) {
        if (saleType == 0) {
            return sellOrderDetails[id].tokenOwner != address(0);
        } else if (saleType == 2) {
            return auctionOrderDetails[id].tokenOwner != address(0);
        }
        return false;
    }

    /**
     * @notice list nfts on the marketplace
     * @param orderId Id for swap, trade or auction
     * @param _type type of the order if it is swap, trade or auction
     *
     * @return listId Id of the listed NFT
     *
     * @dev internal function, will be called when user put NFT for trade, auction and swap
     * used to list NFT on marketplace
     */
    function _listing(uint256 orderId, SaleType _type)
        internal
        returns (uint256 listId)
    {
        _listOrderTracker.increment();
        listId = _listOrderTracker.current();

        listedNFTDetails[listId] = ListedToken({
            saleId: orderId,
            saleType: _type
        });

        listedTokens.push(listId);
        listedTokensIndex[listId] = listedTokens.length;

        emit ListCreated(listId, _type);
    }

    /**
     * @notice unlist the nfts on the marketplace
     *
     * @param listId Id of the listed NFT
     *
     * @return bool true if NFT got unlisted from marketplace
     *
     * @dev internal function, will be called when user cancel trade or swap,
     * used to unlist NFT on marketplace
     */
    function _unlisting(uint256 listId) internal returns (bool) {
        uint256 listIndex = listedTokensIndex[listId];
        uint256 lastIndex = listedTokens.length - 1;

        if (listIndex > 0) {
            listedTokens[listIndex - 1] = listedTokens[lastIndex];
            listedTokensIndex[listedTokens[lastIndex]] = listIndex;
            listedTokensIndex[listId] = 0;
            listedTokens.pop();

            delete listedNFTDetails[listId];
        }

        emit Unlist(listId);
        return true;
    }

    /// @dev internal function to delete Auction from the marketplace
    function _deleteAuction(
        uint256 auctionId,
        address _to,
        address _contract,
        uint256 _tokenId
    ) internal {
        /// unlist the auction from the marketplace
        _unlisting(auctionOrderDetails[auctionId].listId);

        if (bidId[auctionId].length > 0) {
            delete bidId[auctionId];
        }

        bool ercStandard = (auctionOrderDetails[auctionId].erc ==
            ErcStandard.ERC721)
            ? true
            : false;

        /// transfer back the nft to the user
        if (msg.sender != escrow) {
            IWithdraw(escrow).claimNFTback(auctionId, _to, _contract, _tokenId, ercStandard);
        }

        delete auctionOrderDetails[auctionId];
    }

    function listTokens() external view returns (uint256[] memory) {
        return listedTokens;
    }

    function tradedTokens() external view returns (uint256[] memory) {
        return tradeTokens;
    }

    function getWhitelistedContracts()
        external
        view
        returns (address[] memory)
    {
        return whitelistedContracts;
    }

    function getEscrow() external view returns (address) {
        return escrow;
    }

    function getTreasury() external view returns (address) {
        return treasury;
    }

    function isWhitelisted(address _address) external view returns (bool) {
        return isContractWhitelisted[_address];
    }

    function getAuctionBiddings(uint256 auctionId)
        external
        view
        returns (uint256[] memory)
    {
        return bidId[auctionId];
    }
}
