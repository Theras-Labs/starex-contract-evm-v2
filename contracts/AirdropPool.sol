// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTAirdropPool is Ownable, IERC721Receiver, IERC1155Receiver {
    enum TypeNFT {
        ERC721,
        ERC1155
    }

    struct NFTDetail {
        address tokenAddress;
        uint256 tokenId;
        uint256 amount; // For ERC1155. For ERC721, this will always be 1.
        TypeNFT typeNFT;
    }

    mapping(uint256 => NFTDetail) public nftsInPool;
    uint256 public _nextPoolId;
    // _poolConsumption

    // Events for logging NFT operations
    event NFTReceived(address indexed tokenAddress, uint256 indexed tokenId, uint256 amount, TypeNFT typeNFT);
    event NFTSent(address indexed tokenAddress, uint256 indexed tokenId, uint256 amount, TypeNFT typeNFT);


     constructor(address initialOwner)
        Ownable(initialOwner)
    {}


    function recordNFT(address nftContract, uint256 tokenId, uint256 amount, TypeNFT typeNFT) private {
        uint256 poolId = _nextPoolId++;
        nftsInPool[poolId] = NFTDetail(nftContract, tokenId, amount, typeNFT);
        emit NFTReceived(nftContract, tokenId, amount, typeNFT);
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata) external override returns (bytes4) {
        recordNFT(msg.sender, tokenId, 1, TypeNFT.ERC721);
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256 id, uint256 value, bytes calldata) external override returns (bytes4) {
        recordNFT(msg.sender, id, value, TypeNFT.ERC1155);
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata ids, uint256[] calldata values, bytes calldata) external override returns (bytes4) {
        for (uint i = 0; i < ids.length; i++) {
            recordNFT(msg.sender, ids[i], values[i], TypeNFT.ERC1155);
        }
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId 
            || interfaceId == type(IERC1155Receiver).interfaceId;
    }

    // Implement functionality to send NFTs and record via NFTSent event as needed
    // using claim to the players
}
