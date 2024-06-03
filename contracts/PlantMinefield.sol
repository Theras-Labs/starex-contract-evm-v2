// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.17;

import "./polygonZKEVMContracts/interfaces/IBridgeMessageReceiver.sol";
import "./polygonZKEVMContracts/interfaces/IPolygonZkEVMBridge.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * ZkEVMNFTBridge is an example contract to use the message layer of the PolygonZkEVMBridge to bridge  message
 */
contract MineFieldPlanter is Ownable {
  // Global Exit Root address
  IPolygonZkEVMBridge public immutable polygonZkEVMBridge;

  // Address in the other network that will receive the message
  address public mineFieldReceiver;

  /**
   * @param _polygonZkEVMBridge Polygon zkevm bridge address
   */
  constructor(IPolygonZkEVMBridge _polygonZkEVMBridge) {
    polygonZkEVMBridge = _polygonZkEVMBridge;
  }

  /**
   * @dev Emitted when send a message to another network
   */
  event MineFieldPlanted(uint256 mineFieldAmount);

  /**
   * @dev Emitted when change the receiver
   */
  event SetReceiver(address newMineFieldReceiver);

  /**
   * @notice Plant minefield across the chain
   * @param destinationNetwork Network destination
   * @param forceUpdateGlobalExitRoot Indicates if the global exit root is updated or not
   * @param mineFieldAmount Amount of minefield to be sent
   * @param tokenAddress Address of the ERC20 token used for payment
   */
  function plantMineField(
    uint32 destinationNetwork,
    bool forceUpdateGlobalExitRoot,
    uint256 mineFieldAmount,
    address tokenAddress
  ) external {
    // Transfer minefield tokens from owner to this contract
    // require(
    //   IERC20(tokenAddress).transferFrom(
    //     msg.sender,
    //     address(this),
    //     mineFieldAmount
    //   ),
    //   "Failed to transfer minefield tokens"
    // );
    // todo: instead check price with dataFeed

    // Encode minefield message
    bytes memory minefieldMessage = abi.encode(mineFieldAmount);

    // Bridge minefield message
    polygonZkEVMBridge.bridgeMessage(
      destinationNetwork,
      mineFieldReceiver,
      forceUpdateGlobalExitRoot,
      minefieldMessage
    );

    emit MineFieldPlanted(mineFieldAmount);
  }

  /**
   * @notice Set the receiver of the minefield
   * @param newMineFieldReceiver Address of the minefield receiver in the other network
   */
  function setReceiver(address newMineFieldReceiver) external onlyOwner {
    mineFieldReceiver = newMineFieldReceiver;
    emit SetReceiver(newMineFieldReceiver);
  }
}
