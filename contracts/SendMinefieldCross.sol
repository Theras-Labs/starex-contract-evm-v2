// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { AggregatorV3Interface } from "@chainlink/contracts@1.1.1/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { IRouterClient } from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { OwnerIsCreator } from "@chainlink/contracts-ccip@1.4.0/src/v0.8/shared/access/OwnerIsCreator.sol";
import { Client } from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/libraries/Client.sol";
import { LinkTokenInterface } from "@chainlink/contracts@1.1.1/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract Sender is OwnerIsCreator {
  error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);

  event MessageSent(
    bytes32 indexed messageId,
    uint64 indexed destinationChainSelector,
    address receiver,
    string text,
    address feeToken,
    uint256 fees
  );

  IRouterClient private s_router;
  LinkTokenInterface private s_linkToken;
  AggregatorV3Interface internal dataFeed;
  address private usdt;

  constructor(
    address _router,
    address _link,
    address _usdt,
    address _aggregator
  ) {
    s_router = IRouterClient(_router);
    s_linkToken = LinkTokenInterface(_link);
    usdt = _usdt;

    dataFeed = AggregatorV3Interface(_aggregator);
  }

  function sendMineField(
    uint64 destinationChainSelector,
    uint256 gameMatchID,
    address receiver,
    string calldata mineFieldAmount,
    address erc20Token,
    AggregatorV3Interface aggregator
  ) external payable onlyOwner returns (bytes32 messageId) {
    // use aggreagtor for more flexible payment amount later

    Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
      receiver: abi.encode(receiver),
      data: abi.encode(gameMatchID, mineFieldAmount, erc20Token),
      tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
      extraArgs: Client._argsToBytes(
        Client.EVMExtraArgsV1({ gasLimit: 200_000 })
      ),
      feeToken: address(s_linkToken) // using LINK as the fee token
    });

    // Send the message through the router
    messageId = s_router.ccipSend(destinationChainSelector, evm2AnyMessage);

    emit MessageSent(
      messageId,
      destinationChainSelector,
      receiver,
      mineFieldAmount,
      address(s_linkToken), // using LINK as the fee token
      msg.value // fees paid in native token
    );

    return messageId;
  }
}
