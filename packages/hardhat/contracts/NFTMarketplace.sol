// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721Holder, Ownable {
    uint256 private feePercentage; // Fee percentage charged by the marketplace owner (in basis points)
    address private marketplaceOwner; // Address of the marketplace owner
    uint256 private totalListings; // Total number of listings created on the marketplace
    uint256 private totalSales; // Total number of NFTs sold on the marketplace

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(address => mapping(uint256 => Listing)) private listings; // Mapping to store the listing information for each NFT

    event Listed(address indexed seller, address indexed nftContract, uint256 indexed tokenId, uint256 price);
    event PriceChanged(address indexed seller, address indexed nftContract, uint256 indexed tokenId, uint256 newPrice);
    event Unlisted(address indexed seller, address indexed nftContract, uint256 indexed tokenId);
    event Purchased(address indexed buyer, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);

    // Modifier to check if the caller is the NFT owner
    modifier onlyNFTOwner(address nftContract, uint256 tokenId) {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not the owner of the NFT");
        _;
    }

    constructor() {
        feePercentage = 1; // Default fee percentage set to 1% (100 basis points)
        marketplaceOwner = msg.sender; // Set the marketplace owner as the contract deployer
    }

    /**
     * @dev List an NFT for sale on the marketplace.
     * @param nftContract Address of the ERC721 NFT contract.
     * @param tokenId ID of the NFT being listed.
     * @param price Price at which the NFT is listed.
     */
    function listNFT(address nftContract, uint256 tokenId, uint256 price) external onlyNFTOwner(nftContract, tokenId) {
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId); // Transfer the NFT to the marketplace contract
        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });

        totalListings++;

        emit Listed(msg.sender, nftContract, tokenId, price);
    }

    /**
     * @dev Change the price of a listed NFT.
     * @param nftContract Address of the ERC721 NFT contract.
     * @param tokenId ID of the listed NFT.
     * @param newPrice New price for the listed NFT.
     */
    function changePrice(address nftContract, uint256 tokenId, uint256 newPrice) external onlyNFTOwner(nftContract, tokenId) {
        require(listings[nftContract][tokenId].active, "NFT not listed");
        listings[nftContract][tokenId].price = newPrice;

        emit PriceChanged(msg.sender, nftContract, tokenId, newPrice);
    }

    /**
     * @dev Unlist a listed NFT from the marketplace.
     * @param nftContract Address of the ERC721 NFT contract.
     * @param tokenId ID of the listed NFT.
     */
    function unlistNFT(address nftContract, uint256 tokenId) external onlyNFTOwner(nftContract, tokenId) {
        require(listings[nftContract][tokenId].active, "NFT not listed");
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId); // Transfer the NFT back to the NFT owner
        delete listings[nftContract][tokenId];

        totalListings--;

        emit Unlisted(msg.sender, nftContract, tokenId);
    }

    /**
     * @dev Purchase a listed NFT from the marketplace.
     * @param nftContract Address of the ERC721 NFT contract.
     * @param tokenId ID of the listed NFT.
     */
    function purchaseNFT(address nftContract, uint256 tokenId) external payable {
        require(listings[nftContract][tokenId].active, "NFT not listed");

        Listing memory listing = listings[nftContract][tokenId];
        
        uint256 fee = (listing.price * feePercentage) / 10000; // Calculate the fee amount
        uint256 totalPrice = listing.price + fee; // Calculate the total price including the fee

        require(msg.value >= totalPrice, "Insufficient payment");

        address payable seller = payable(listing.seller);
        seller.transfer(listing.price); // Transfer the listing price to the seller
        marketplaceOwner.transfer(fee); // Transfer the fee amount to the marketplace owner

        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId); // Transfer the NFT to the buyer
        delete listings[nftContract][tokenId];

        totalListings--;
        totalSales++;

        emit Purchased(msg.sender, listing.seller, nftContract, tokenId, listing.price);
    }

    /**
     * @dev Get the current fee percentage set by the marketplace owner.
     */
    function getFeePercentage() external view returns (uint256) {
        return feePercentage;
    }

    /**
     * @dev Set the fee percentage for the marketplace owner.
     * @param newFeePercentage New fee percentage to be set (in basis points).
     */
    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 10000, "Invalid fee percentage"); // Fee percentage should be less than or equal to 100%
        feePercentage = newFeePercentage;
    }

    /**
     * @dev Get the total number of listings created on the marketplace.
     */
    function getTotalListings() external view returns (uint256) {
        return totalListings;
    }

    /**
     * @dev Get the total number of NFTs sold on the marketplace.
     */
    function getTotalSales() external view returns (uint256) {
        return totalSales;
    }
}