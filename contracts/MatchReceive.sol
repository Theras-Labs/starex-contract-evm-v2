// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Client } from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/libraries/Client.sol";
import { CCIPReceiver } from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract GameContract is CCIPReceiver {
  event RoomCreated(
    bytes32 indexed roomId,
    address indexed creator,
    string name,
    string streamer,
    uint256 minefieldPrice
  );

  event MinefieldPurchased(
    bytes32 indexed roomId,
    address indexed purchaser,
    uint256 amount
  );

  struct Room {
    string name;
    string streamer;
    uint256 minefieldPrice;
    mapping(address => uint256) minefields; // player's minefields balance
  }
  mapping(bytes32 => Room) public rooms;

  constructor(address router) CCIPReceiver(router) {}

  function createRoom(
    string memory _name,
    string memory _streamer,
    uint256 _minefieldPrice
  ) external {
    bytes32 roomId = keccak256(
      abi.encodePacked(_name, _streamer, _minefieldPrice, block.timestamp)
    );
    rooms[roomId] = Room(_name, _streamer, _minefieldPrice);
    emit RoomCreated(roomId, msg.sender, _name, _streamer, _minefieldPrice);
  }

  function _ccipReceive(Client.Any2EVMMessage memory _message)
    internal
    override
  {
    bytes32 roomId = abi.decode(_message.data, (bytes32));
    uint256 minefieldsAmount = abi.decode(_message.data, (uint256));
    rooms[roomId].minefields[_message.sender] += minefieldsAmount;
    emit MinefieldPurchased(roomId, _message.sender, minefieldsAmount); /// events will be used in the game
  }

  function getLastReceivedMessageDetails()
    external
    view
    returns (bytes32, string memory)
  {
    return (s_lastReceivedMessageId, s_lastReceivedText);
  }
}
