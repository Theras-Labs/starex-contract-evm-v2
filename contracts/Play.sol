// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 0x558A682636988925F48eF58d3975293665b69C86
contract Play {
  struct MatchRoom {
    uint256 roomId;
    string name;
    address streamer;
    uint256 totalMinefields;
    uint256 totalDonations;
    bool isActive;
  }

  uint256 public nextRoomId;
  mapping(uint256 => MatchRoom) public matchRooms;
  mapping(uint256 => mapping(address => uint256)) public roomDonations;
  mapping(uint256 => mapping(address => uint256)) public roomMinefields;

  event RoomCreated(uint256 indexed roomId, string name, address streamer);
  event MinefieldDeployed(
    uint256 indexed roomId,
    address indexed viewer,
    uint256 amount,
    string paymentType
  );

  event DonationReceived(
    uint256 indexed roomId,
    address indexed viewer,
    uint256 amount
  );
  event RoomClosed(
    uint256 indexed roomId,
    address streamer,
    uint256 totalDonations
  );

  // _name here actually playroom ID ->
  function createRoom(string memory _name) external {
    matchRooms[nextRoomId] = MatchRoom({
      roomId: nextRoomId,
      name: _name,
      streamer: msg.sender,
      totalMinefields: 0,
      totalDonations: 0,
      isActive: true
    });

    emit RoomCreated(nextRoomId, _name, msg.sender);
    nextRoomId++;
  }

  function deployMinefield(
    uint256 _roomId,
    uint256 _amount,
    address _tokenAddress
  ) external payable {
    MatchRoom storage room = matchRooms[_roomId];
    require(room.isActive, "Room is not active");

    if (msg.value > 0) {
      //   roomMinefields[_roomId][msg.sender] += msg.value;
      //
      room.totalMinefields += 1;
      emit MinefieldDeployed(_roomId, msg.sender, msg.value, "Native");
    } else {
      // approval?
      IERC20 token = IERC20(_tokenAddress);
      require(
        token.transferFrom(msg.sender, address(this), _amount),
        "Token transfer failed"
      );

      //   roomMinefields[_roomId][msg.sender] += _amount;
      // decide more later
      room.totalMinefields += 1;
      emit MinefieldDeployed(_roomId, msg.sender, _amount, "ERC20");
    }
  }

  function donateToRoom(
    uint256 _roomId,
    uint256 _amount,
    address _tokenAddress
  ) external {
    IERC20 token = IERC20(_tokenAddress);
    require(
      token.transferFrom(msg.sender, address(this), _amount),
      "Token transfer failed"
    );

    // this will get mixed up if sending other erc20
    roomDonations[_roomId][msg.sender] += _amount;
    matchRooms[_roomId].totalDonations += _amount;

    emit DonationReceived(_roomId, msg.sender, _amount);
  }

  function getRoomStatus(uint256 _roomId)
    external
    view
    returns (
      string memory,
      address,
      uint256,
      uint256,
      bool
    )
  {
    MatchRoom storage room = matchRooms[_roomId];
    return (
      room.name,
      room.streamer,
      room.totalMinefields,
      room.totalDonations,
      room.isActive
    );
  }

  function closeRoom(uint256 _roomId) external {
    MatchRoom storage room = matchRooms[_roomId];
    require(
      msg.sender == room.streamer,
      "Only the streamer can close the room"
    );
    require(room.isActive, "Room is already closed");

    room.isActive = false;

    if (room.totalDonations > 0) {
      payable(room.streamer).transfer(room.totalDonations);
    }

    emit RoomClosed(_roomId, room.streamer, room.totalDonations);
  }
}
