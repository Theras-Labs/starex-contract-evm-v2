// array of nfts... lock down here, --> will be allowed to mint a single NFTs ?
// array nfts (from other chains?? proof of tx?) or accept id of BE  --> acc

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC1155 {
    function mintCollectible(uint256 _id, address _to, uint256 _quantity, bytes memory _data) external;
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);
    function burn(address _owner, uint256 _id, uint256 _amount) external;
}

contract CraftingSystem {
    address public nftAssetAddress;

    event Crafted(uint256 indexed id, uint256 amount, address indexed to);

    constructor(address _nftAssetAddress) {
        nftAssetAddress = _nftAssetAddress;
    }


    // same network
    function craftNFT(uint256[] memory ids, address[] memory addresses, uint256[] memory amounts, bytes memory data) external {
        require(ids.length == addresses.length && ids.length == amounts.length, "Arrays length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            // Transfer or burn NFTs depending on the use case
            IERC1155(nftAssetAddress).burn(addresses[i], ids[i], amounts[i]);
        }

        // Based on predetermined data, mint new NFT
        // Assuming craft result is determined off-chain
        // uint256 craftedId; // Your predetermined crafted NFT id
        // uint256 craftedAmount; // The amount of crafted NFTs
        (uint256 craftedId, uint256 craftedAmount, address nftAddress) = abi.decode(data, (uint256, uint256, address));

        // Mint the crafted NFTs
        IERC1155(nftAssetAddress).mintCollectible(craftedId, msg.sender, craftedAmount, data);

        emit Crafted(craftedId, craftedAmount, msg.sender);
    }

    //
}
