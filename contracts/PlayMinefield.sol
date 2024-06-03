// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "./polygonZKEVMContracts/interfaces/IBridgeMessageReceiver.sol";
import "./polygonZKEVMContracts/interfaces/IPolygonZkEVMBridge.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameReceiver is IBridgeMessageReceiver, Ownable {
  IPolygonZkEVMBridge public immutable polygonZkEVMBridge;
  uint32 public immutable networkID;

  address public gameMatchSender;
  uint256 public gameMatchId;
  uint256 public minefields;

  constructor(IPolygonZkEVMBridge _polygonZkEVMBridge) {
    polygonZkEVMBridge = _polygonZkEVMBridge;
    networkID = polygonZkEVMBridge.networkID();
  }

  event GameMatchReceived(uint256 gameMatchId, uint256 minefields);

  event SetGameMatchSender(address newGameMatchSender);

  function setGameMatchSender(address newGameMatchSender) external onlyOwner {
    gameMatchSender = newGameMatchSender;
    emit SetGameMatchSender(newGameMatchSender);
  }

  function onMessageReceived(
    address originAddress,
    uint32 originNetwork,
    bytes memory data
  ) external payable override {
    require(
      msg.sender == address(polygonZkEVMBridge),
      "GameReceiver::onMessageReceived: Not PolygonZkEVMBridge"
    );

    require(
      gameMatchSender == originAddress,
      "GameReceiver::onMessageReceived: Not Game Match Sender"
    );

    (gameMatchId, minefields) = abi.decode(data, (uint256, uint256));

    emit GameMatchReceived(gameMatchId, minefields);
  }
}
