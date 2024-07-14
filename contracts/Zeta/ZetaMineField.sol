// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@zetachain/protocol-contracts/contracts/evm/tools/ZetaInteractor.sol";
import "@zetachain/protocol-contracts/contracts/evm/interfaces/ZetaInterfaces.sol";

contract CrossChainGame is ZetaInteractor, ZetaReceiver {
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

  event CrossChainMessageEvent(string message);
  event CrossChainMessageRevertedEvent(string message);

  ZetaTokenConsumer private immutable _zetaConsumer;
  IERC20 internal immutable _zetaToken;

  struct Room {
    string name;
    string streamer;
    uint256 minefieldPrice;
    mapping(address => uint256) minefields;
  }

  mapping(bytes32 => Room) public rooms;

  constructor(
    address connectorAddress,
    address zetaTokenAddress,
    address zetaConsumerAddress
  ) ZetaInteractor(connectorAddress) {
    _zetaToken = IERC20(zetaTokenAddress);
    _zetaConsumer = ZetaTokenConsumer(zetaConsumerAddress);
  }

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

  function sendMessage(uint256 destinationChainId, string memory message)
    external
    payable
  {
    require(
      _isValidChainId(destinationChainId),
      "Invalid destination chain ID"
    );

    uint256 crossChainGas = 2 * (10**18);
    uint256 zetaValueAndGas = _zetaConsumer.getZetaFromEth{ value: msg.value }(
      address(this),
      crossChainGas
    );
    _zetaToken.approve(address(connector), zetaValueAndGas);

    connector.send(
      ZetaInterfaces.SendInput({
        destinationChainId: destinationChainId,
        destinationAddress: interactorsByChainId[destinationChainId],
        destinationGasLimit: 300000,
        message: abi.encode(message),
        zetaValueAndGas: zetaValueAndGas,
        zetaParams: abi.encode("")
      })
    );
  }

  function onZetaMessage(ZetaInterfaces.ZetaMessage calldata zetaMessage)
    external
    override
    isValidMessageCall(zetaMessage)
  {
    string memory message = abi.decode(zetaMessage.message, (string));
    emit CrossChainMessageEvent(message);
  }

  function onZetaRevert(ZetaInterfaces.ZetaRevert calldata zetaRevert)
    external
    override
    isValidRevertCall(zetaRevert)
  {
    string memory message = abi.decode(zetaRevert.message, (string));
    emit CrossChainMessageRevertedEvent(message);
  }

  function purchaseMinefield(bytes32 roomId, uint256 amount) external {
    Room storage room = rooms[roomId];
    require(room.minefieldPrice > 0, "Room does not exist");
    require(amount > 0, "Amount must be greater than 0");

    uint256 totalPrice = room.minefieldPrice * amount;
    require(
      _zetaToken.transferFrom(msg.sender, address(this), totalPrice),
      "Payment failed"
    );

    room.minefields[msg.sender] += amount;
    emit MinefieldPurchased(roomId, msg.sender, amount);
  }
}
