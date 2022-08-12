// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IComposable {
    function unbundleAndBurn(uint256 _tokenId, address _to) external;
}

interface IMarketplace {
    function cancelAuction(uint256 auctionId) external;
    function cancelSell(uint256 orderId) external;
}

contract Withdrawer is ERC721Holder, ERC1155Holder, ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    struct NFTDescription {
        uint256 id;
        uint256 saleId;
        uint256 tokenId;
        address tokenContract;
        address owner;
        bool erc721;
        uint8 saleType;
    }

    // TODO: Needs to be changed for mainnet deployment
    // address public USDT = 0x8DC0fAF4778076A8a6700078A500C59960880F0F; // Only for Testing

    address public marketplace;

    /// @notice USDT address on polygon mainnet
    address public USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    /// @notice address of the composable contract
    address private composable;

    mapping(address => bool) public authorized;
    mapping(address => uint[]) private nftForTrade;
    mapping(uint256 => uint256) private nftIndex;
    mapping(uint => NFTDescription) public nftDescription;
    mapping(address => uint) public usdtBalance;

    event AddressAuthorised(address indexed authorisedAddress, bool value);
    event Claim(
        address indexed recepient,
        uint256 maticAmount,
        uint256 usdtAmount
    );
    event ComposableUpdated(
        address indexed oldAddress,
        address indexed updatedAddress
    );
    event TokenUpdated(
        address indexed oldAddress,
        address indexed updatedAddress
    );
    event MarketplaceUpdated(
        address indexed oldAddress,
        address indexed updatedAddress
    );

    /**
     * @notice Require that the caller must be marketplace contract only
     */
    modifier onlyWhitelisted() {
        require(authorized[msg.sender], "Only Marketplace");
        _;
    }

    constructor(address _composable) {
        require(_composable != address(0), "Zero Address");

        composable = _composable;
    }

    /// Fallback functions to accept matic
    receive() external payable {
        _handleIncomingBid(msg.sender, msg.value, false);
    }

    fallback() external payable {
        _handleIncomingBid(msg.sender, msg.value, false);
    }

    function updateTokenAddress(address _usdt) external onlyOwner whenNotPaused {
        require(_usdt != address(0), "Zero Address");
        address oldAddress = USDT;
        USDT = _usdt;

        emit TokenUpdated(oldAddress, USDT);
    }

    function updateMarketplace(address _add) external onlyOwner whenNotPaused {
        require(_add != address(0), "Zero Address");

        address oldAddress = marketplace;
        marketplace = _add;

        emit MarketplaceUpdated(oldAddress, _add);
    }

    function updateComposableAddress(address _composable) external onlyOwner whenNotPaused {
        require(_composable != address(0), "Zero Address");
        address oldAddress = composable;
        composable = _composable;

        emit ComposableUpdated(oldAddress, composable);
    }

    /// @notice only Authorised address can call the functions of this contract
    function setAuthorized(address _address, bool _value) external onlyOwner whenNotPaused {
        require(_address != address(0), "Invalid Address");
        authorized[_address] = _value;

        emit AddressAuthorised(_address, _value);
    }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unpauseContract() external onlyOwner {
        _unpause();
    }

    /**
    * @notice Transfers the NFT from the Escrow contract to the rightful owner
    * @param tokenOwner address where the NFT will get transferred 
    * @param tokenContract address of the NFT contract
    * @param tokenId Id of the NFT which will be transferred
    * @param ercStandard Standard of the NFT token
    *
    * @custom:note Only whitelisted addresses can call this functionality
    */
    function claimNFTback(
        uint256 id,
        address tokenOwner,
        address tokenContract,
        uint256 tokenId,
        bool ercStandard
    ) external whenNotPaused onlyWhitelisted returns (bool success) {
        // address tokenOwner = tokenOwner;

        withdrawNFTs(id, tokenOwner, tokenContract, tokenId, ercStandard);

        success = true;
    }

    function withdrawNFTs(
        uint256 _id,
        address tokenOwner,
        address tokenContract,
        uint256 tokenId,
        bool ercStandard) internal {
        if (tokenContract == composable) {
        
            IComposable(composable).unbundleAndBurn(tokenId, tokenOwner);
        }

        else if (ercStandard) {
        
            require(
                address(this) == IERC721(tokenContract).ownerOf(tokenId),
                "Invalid Owner"
            );

            IERC721(tokenContract).safeTransferFrom(
                address(this),
                tokenOwner,
                tokenId
            );

            require(
                tokenOwner == IERC721(tokenContract).ownerOf(tokenId),
                "Invalid Owner"
            );
        } else {
            uint256 tokenBalance = IERC1155(tokenContract).balanceOf(
                address(this),
                tokenId
            );
            IERC1155(tokenContract).safeTransferFrom(
                address(this),
                tokenOwner,
                tokenId,
                1,
                "0x"
            );
            require(
                (tokenBalance - 1) ==
                    IERC1155(tokenContract).balanceOf(address(this), tokenId),
                "Invalid Owner"
            );
        }

        uint256 id = uint256(keccak256(abi.encodePacked(tokenContract, tokenId, _id)));
        address originalOwner = nftDescription[id].owner;

        uint index = nftIndex[id];
        uint lastElement = nftForTrade[originalOwner][nftForTrade[originalOwner].length - 1];

        nftForTrade[originalOwner][index - 1] = lastElement;
        nftIndex[lastElement] = index;
        nftIndex[id] = 0;
        nftForTrade[originalOwner].pop();

        delete nftDescription[id];
    }

    function emergencyWithdrawNFT(uint256 id) external whenPaused {
        NFTDescription memory nft = nftDescription[id];
        
        require(nft.owner == msg.sender, "Invalid Sender");

        withdrawNFTs(nft.saleId, nft.owner, nft.tokenContract, nft.tokenId, nft.erc721);
        if (nft.saleType == 0) {
            IMarketplace(marketplace).cancelSell(nft.saleId);
        } else if (nft.saleType == 2) {
            IMarketplace(marketplace).cancelAuction(nft.saleId);
        }
    }

    function emergencyWithdrawToken() external whenPaused {
        require(usdtBalance[msg.sender] > 0, "Insufficient Balance");

        IERC20(USDT).safeTransfer(msg.sender, usdtBalance[msg.sender]);

        usdtBalance[msg.sender] = 0;
    }

    /**
    * @notice Transfers the NFT from the owner to the Escrow Contract
    * @param tokenOwner address from where the NFT will get transferred 
    * @param tokenContract address of the NFT contract
    * @param tokenId Id of the NFT which will be transferred
    * @param ercStandard Standard of the NFT token
    *
    * @custom:note Only whitelisted addresses can call this functionality
    */
    function storeNFT(
        uint256 _id,
        address tokenOwner,
        address tokenContract,
        uint256 tokenId,
        bool ercStandard,
        uint8 saleType
    ) external whenNotPaused onlyWhitelisted returns (bool success) {
        // address tokenOwner = tokenOwner;
        if (ercStandard) {
            require(
                tokenOwner == IERC721(tokenContract).ownerOf(tokenId),
                "Invalid Owner"
            );
            
            IERC721(tokenContract).safeTransferFrom(
                tokenOwner,
                address(this),
                tokenId
            );

            require(
                address(this) == IERC721(tokenContract).ownerOf(tokenId),
                "Invalid Owner"
            );
        } else {
            uint256 tokenBalance = IERC1155(tokenContract).balanceOf(
                address(this),
                tokenId
            );
            IERC1155(tokenContract).safeTransferFrom(
                tokenOwner,
                address(this),
                tokenId,
                1,
                "0x"
            );
            require(
                (tokenBalance + 1) ==
                    IERC1155(tokenContract).balanceOf(address(this), tokenId),
                "Invalid Owner"
            );
        }
        
        uint256 id = uint256(keccak256(abi.encodePacked(tokenContract, tokenId, _id)));
        nftDescription[id] = NFTDescription({
            id: id,
            saleId: _id,
            tokenId: tokenId,
            tokenContract: tokenContract,
            owner: tokenOwner,
            erc721: ercStandard,
            saleType: saleType
        });
        nftForTrade[tokenOwner].push(id);
        nftIndex[id] = nftForTrade[tokenOwner].length;

        success = true;
    }

    /**
    * @notice handles the outgoing and incoming tokens/matics
    * @param recepient address wher the amount will be transferred
    * @param _amount Amount of tokens that are going to be transferred
    * @param usdt true if currency is ERC-20 token
    * @param outgoing defines if the currency is incoming or outgoing from the contract
    */
    function transferCurrency(
        address sender,
        address recepient,
        uint256 _amount,
        bool usdt,
        bool outgoing
    ) external payable whenNotPaused onlyWhitelisted {
        if (outgoing) {
            _handleOutgoingBid(recepient, _amount, usdt);
            if (usdt) {
                usdtBalance[sender] -= _amount;
            }
        } else {
            _handleIncomingBid(recepient, _amount, usdt);
            if (usdt) {
                usdtBalance[recepient] += _amount;
            }
        }
    }

    /**
     * @dev Given an amount and a currency, transfer the currency to this contract.
     */
    function _handleIncomingBid(
        address recepient,
        uint256 amount,
        bool currency
    ) internal returns (bool) {
        require(amount > 0, "Invalid Amount");
        if (!currency) {
            require(msg.value >= amount, "not enough amount");
            return true;
        } else {
            // We must check the balance that was actually transferred to the trade,
            // as some tokens impose a transfer fee and would not actually transfer the
            // full amount to the market, resulting in potentally locked funds
            IERC20 token = IERC20(USDT);
            uint256 beforeBalance = token.balanceOf(address(this));

            token.safeTransferFrom(recepient, address(this), amount);

            uint256 afterBalance = token.balanceOf(address(this));
            require(
                (beforeBalance + amount) >= afterBalance,
                "unexpected amount Transferred"
            );
            return true;
        }
    }

    /// @dev internal function to handle outgoing amount
    function _handleOutgoingBid(
        address to,
        uint256 amount,
        bool currency
    ) internal returns (bool) {
        if (!currency) {
            uint256 bal = address(this).balance;

            require(bal >= amount, "Insufficient Fund");
            // (bool status, ) = to.call{value: amount}("");
            payable(to).transfer(amount);
            // require(status, "Failed to send Ether");
            return (address(this).balance == bal - amount);
        } else {
            IERC20(USDT).safeTransfer(to, amount);
            return true;
        }
    }

    function getAuthorised(address _add) external view returns (bool) {
        return authorized[_add];
    }

    function getNFTs(address _add) public view returns(uint[] memory) {
        return nftForTrade[_add];
    }
}
