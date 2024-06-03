// SPDX-License-Identifier: MIT
// An example of a consumer contract that directly pays for each request.
pragma solidity ^0.8.7;

import { ConfirmedOwner } from "@chainlink/contracts@1.1.1/src/v0.8/shared/access/ConfirmedOwner.sol";
import { VRFV2WrapperConsumerBase } from "@chainlink/contracts@1.1.1/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import { LinkTokenInterface } from "@chainlink/contracts@1.1.1/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract VRFv2DirectFundingConsumer is
  VRFV2WrapperConsumerBase,
  ConfirmedOwner
{
  event RequestSent(uint256 requestId, uint32 numWords);
  event RequestFulfilled(
    uint256 requestId,
    uint256[] randomWords,
    uint256 payment
  );

  struct RequestStatus {
    uint256 paid; // amount paid in link
    bool fulfilled; // whether the request has been successfully fulfilled
    uint256[] randomWords;
  }
  mapping(uint256 => RequestStatus) public s_requests; // requestId --> requestStatus

  struct ZoneData {
    uint256 lastId; // Last requestId for the zone
    uint256 randomNumbers; // Random numbers for the zone
  }
  mapping(uint256 => ZoneData) public zoneData; // Zone index -> ZoneData mapping
  uint256 public zoneIndex;

  // Depends on the number of requested values that you want sent to the
  // fulfillRandomWords() function. Test and adjust
  // this limit based on the network that you select, the size of the request,
  // and the processing of the callback request in the fulfillRandomWords()
  // function.
  uint32 callbackGasLimit = 100000;

  // The default is 3, but you can set this higher.
  uint16 requestConfirmations = 3;

  // For this example, retrieve 2 random values in one request.
  // Cannot exceed VRFV2Wrapper.getConfig().maxNumWords.
  //   uint32 numWords = 2;

  constructor(address linkAddress, address wrapperAddress)
    ConfirmedOwner(msg.sender)
    VRFV2WrapperConsumerBase(linkAddress, wrapperAddress)
  {}

  function requestRandomWords() external onlyOwner returns (uint256 requestId) {
    requestId = requestRandomness(
      callbackGasLimit,
      requestConfirmations,
      zoneIndex //
    );
    s_requests[requestId] = RequestStatus({
      paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
      randomWords: new uint256[](zoneIndex),
      fulfilled: false
    });
    emit RequestSent(requestId, zoneIndex);
    return requestId;
  }

  function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords)
    internal
    override
  {
    require(s_requests[_requestId].paid > 0, "request not found");
    s_requests[_requestId].fulfilled = true;
    s_requests[_requestId].randomWords = _randomWords;
    emit RequestFulfilled(
      _requestId,
      _randomWords,
      s_requests[_requestId].paid
    );

    // Iterate over zoneData and update each zone
    for (uint256 i = 1; i <= zoneIndex; i++) {
      zoneData[i].lastId = _requestId;
      zoneData[i].randomNumber = _randomWords[i]; // Assign each random word to corresponding zone
    }
  }

  function addZoneData() external onlyOwner returns (uint256) {
    zoneIndex++;
    return zoneIndex;
  }

  function removeZoneData(uint256 _zoneIndex) external onlyOwner {
    require(_zoneIndex > 0 && _zoneIndex <= zoneIndex, "Invalid zone index");
    delete zoneData[_zoneIndex];
  }

  function getRequestStatus(uint256 _requestId)
    external
    view
    returns (
      uint256 paid,
      bool fulfilled,
      uint256[] memory randomWords
    )
  {
    require(s_requests[_requestId].paid > 0, "request not found");
    RequestStatus memory request = s_requests[_requestId];
    return (request.paid, request.fulfilled, request.randomWords);
  }

  /**
   * Allow withdraw of Link tokens from the contract
   */
  function withdrawLink() public onlyOwner {
    LinkTokenInterface link = LinkTokenInterface(linkAddress);
    require(
      link.transfer(msg.sender, link.balanceOf(address(this))),
      "Unable to transfer"
    );
  }
}
