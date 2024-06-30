// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniversalClaim {
  function mintToken(address to, uint256 amount) external;

  function mint(address to) external;

  function safeMint(address to) external;

  function safeMintBatch(address to, uint256 quantity) external;

  function mintCollectible(address to) external;

  function mintCollectibleId(
    address to,
    uint256 tokenId,
    uint256 amount
  ) external;
}

/// @author 0xdellwatson
/// @title CrossCrafting
/// @dev Contract for cross-chain crafting functionality
contract CrossCrafting is Ownable, ERC1155Holder {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  enum LockStatus {
    NONE,
    LOCKED,
    BURNED
  }

  struct Ticket {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  enum TokenType {
    ERC20,
    ERC721,
    ERC1155,
    ERC721_SAFE_MINT,
    ERC721_MINT,
    ERC721_SAFE_MINT_BATCH,
    ERC721_SAFE_MINT_BATCH_SHOP
  }

  address private offchainSigner;
  uint256 public therasFee; // Therashop fee as a fraction of 1000 (e.g., 100 for 10%)

  struct ComponentDetail {
    address tokenAddress;
    uint256 tokenId;
    uint256 amount;
    LockStatus lockStatus;
  }

  struct ERC20Detail {
    address tokenAddress;
    uint256 amount;
  }

  struct CraftingResult {
    bool success;
    address generatedTokenAddress;
    uint256 timestamp;
    ComponentDetail[] components;
    ERC20Detail[] erc20Tokens;
  }

  mapping(uint256 => CraftingResult) public craftingResults;
  mapping(uint256 => ComponentDetail[]) public lockedComponents;

  event LockNFTEvent(
    uint256 indexed queueId,
    address indexed user,
    ComponentDetail[] components
  );
  event CraftingResultEvent(
    uint256 indexed queueId,
    bool success,
    address generatedTokenAddress
  );

  /// @notice Constructor to initialize the contract
  /// @param initialOwner The initial owner of the contract
  /// @param _fee The initial fee for the crafting process
  /// @param _offchainSigner The address of the offchain signer for verification
  constructor(
    address initialOwner,
    uint256 _fee,
    address _offchainSigner
  ) Ownable(initialOwner) {
    therasFee = _fee;
    offchainSigner = _offchainSigner;
  }

  receive() external payable {}

  /// @notice Sets up the fee for the crafting process
  /// @param _fee The new fee to be set
  function setupTherasFee(uint256 _fee) public onlyOwner {
    therasFee = _fee;
  }

  /// @notice Sets up the offchain signer address
  /// @param _offchainSigner The new offchain signer address
  function setupOffchain(address _offchainSigner) public onlyOwner {
    offchainSigner = _offchainSigner;
  }

  /// @notice Withdraw Ether from the contract
  /// @param amount The amount of Ether to withdraw
  function withdrawEther(uint256 amount) external onlyOwner {
    require(amount <= address(this).balance, "Insufficient Ether balance");
    payable(msg.sender).transfer(amount);
  }

  /// @notice Withdraw ERC20 tokens from the contract
  /// @param tokenAddress The address of the ERC20 token
  /// @param amount The amount of ERC20 tokens to withdraw
  function withdrawToken(address tokenAddress, uint256 amount)
    external
    onlyOwner
  {
    IERC20 token = IERC20(tokenAddress);
    require(
      amount <= token.balanceOf(address(this)),
      "Insufficient token balance"
    );
    token.transfer(msg.sender, amount);
  }

  /// @notice Submit materials for crafting
  /// @param queueId The ID of the crafting queue
  /// @param tokenAddresses Array of token addresses
  /// @param tokenIds Array of token IDs
  /// @param amounts Array of token amounts
  function submitMaterial(
    uint256 queueId,
    address[] calldata tokenAddresses,
    uint256[] calldata tokenIds,
    uint256[] calldata amounts
  ) external {
    require(
      tokenAddresses.length == tokenIds.length &&
        tokenIds.length == amounts.length,
      "Lengths of arrays must match"
    );

    for (uint256 i = 0; i < tokenAddresses.length; i++) {
      _lockNFT(tokenAddresses[i], tokenIds[i], amounts[i]);
      lockedComponents[queueId].push(
        ComponentDetail({
          tokenAddress: tokenAddresses[i],
          tokenId: tokenIds[i],
          amount: amounts[i],
          lockStatus: LockStatus.LOCKED
        })
      );
    }

    emit LockNFTEvent(queueId, msg.sender, lockedComponents[queueId]);
  }

  /// @notice Craft an item using the provided materials and ERC20 tokens
  /// @param queueId The ID of the crafting queue
  /// @param erc20Tokens Array of ERC20 details
  /// @param successProbability Probability of crafting success
  /// @param outputTokenAddress Address of the output token
  /// @param outputTokenId ID of the output token
  /// @param outputTokenQuantity Quantity of the output token
  /// @param outputTokenType Type of the output token
  /// @param _ticket Ticket for offchain verification
  function craft(
    uint256 queueId,
    ERC20Detail[] calldata erc20Tokens,
    uint256 successProbability,
    address outputTokenAddress,
    uint256 outputTokenId,
    uint256 outputTokenQuantity,
    TokenType outputTokenType,
    Ticket memory _ticket
  ) external {
    bytes32 digest = keccak256(
      abi.encode(
        msg.sender,
        queueId,
        erc20Tokens,
        successProbability,
        outputTokenAddress,
        outputTokenId,
        outputTokenQuantity,
        outputTokenType
      )
    );

    require(isVerifiedTicket(digest, _ticket), "Invalid ticket");

    for (uint256 i = 0; i < erc20Tokens.length; i++) {
      if (erc20Tokens[i].tokenAddress != address(0)) {
        IERC20(erc20Tokens[i].tokenAddress).transferFrom(
          msg.sender,
          address(this),
          erc20Tokens[i].amount
        );
      }
    }

    bool success = _random() < successProbability;

    if (success) {
      __mintable(
        outputTokenType,
        outputTokenAddress,
        outputTokenId,
        outputTokenQuantity
      );
    }

    craftingResults[queueId].success = success;
    craftingResults[queueId].generatedTokenAddress = outputTokenAddress;
    craftingResults[queueId].timestamp = block.timestamp;

    for (uint256 i = 0; i < erc20Tokens.length; i++) {
      craftingResults[queueId].erc20Tokens.push(erc20Tokens[i]);
    }

    emit CraftingResultEvent(queueId, success, outputTokenAddress);
  }

  /// @notice Burns an NFT
  /// @param tokenAddress Address of the token contract
  /// @param tokenId ID of the token
  /// @param amount Amount of the token
  function _burnNFT(
    address tokenAddress,
    uint256 tokenId,
    uint256 amount
  ) internal {
    if (IERC165(tokenAddress).supportsInterface(type(IERC1155).interfaceId)) {
      IERC1155(tokenAddress).safeTransferFrom(
        msg.sender,
        address(0),
        tokenId,
        amount,
        ""
      );
    } else if (
      IERC165(tokenAddress).supportsInterface(type(IERC721).interfaceId)
    ) {
      IERC721(tokenAddress).transferFrom(msg.sender, address(0), tokenId);
    }
  }

  /// @notice Locks an NFT
  /// @param tokenAddress Address of the token contract
  /// @param tokenId ID of the token
  /// @param amount Amount of the token
  function _lockNFT(
    address tokenAddress,
    uint256 tokenId,
    uint256 amount
  ) internal {
    if (IERC165(tokenAddress).supportsInterface(type(IERC1155).interfaceId)) {
      IERC1155(tokenAddress).safeTransferFrom(
        msg.sender,
        address(this),
        tokenId,
        amount,
        ""
      );
    } else if (
      IERC165(tokenAddress).supportsInterface(type(IERC721).interfaceId)
    ) {
      IERC721(tokenAddress).transferFrom(msg.sender, address(this), tokenId);
    }
  }

  /// @notice Mints tokens based on the specified type
  /// @param tokenType Type of the token to mint
  /// @param productAddress Address of the product contract
  /// @param productId ID of the product
  /// @param quantity Quantity of tokens to mint
  function __mintable(
    TokenType tokenType,
    address productAddress,
    uint256 productId,
    uint256 quantity
  ) internal {
    if (tokenType == TokenType.ERC20) {
      // ERC20 minting logic
    } else if (tokenType == TokenType.ERC721) {
      // ERC721 minting logic
    } else if (tokenType == TokenType.ERC1155) {
      IERC1155(productAddress).safeTransferFrom(
        address(this),
        msg.sender,
        productId,
        quantity,
        ""
      );
    } else if (tokenType == TokenType.ERC721_SAFE_MINT) {
      IUniversalClaim(productAddress).safeMint(msg.sender);
    } else if (tokenType == TokenType.ERC721_MINT) {
      IUniversalClaim(productAddress).mint(msg.sender);
    } else if (tokenType == TokenType.ERC721_SAFE_MINT_BATCH) {
      IUniversalClaim(productAddress).safeMintBatch(msg.sender, quantity);
    } else if (tokenType == TokenType.ERC721_SAFE_MINT_BATCH_SHOP) {
      IUniversalClaim(productAddress).mintCollectibleId(
        msg.sender,
        productId,
        quantity
      );
    }
  }

  /// @notice Verifies the ticket for offchain verification
  /// @param digest The digest of the data
  /// @param ticket The ticket containing the signature
  /// @return True if the ticket is valid, false otherwise
  function isVerifiedTicket(bytes32 digest, Ticket memory ticket)
    internal
    view
    returns (bool)
  {
    address signer = ecrecover(digest, ticket.v, ticket.r, ticket.s);
    return signer == offchainSigner;
  }

  /// @notice Generates a random number
  /// @return A random number
  function _random() internal view returns (uint256) {
    return
      uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) %
      100;
  }
}
