// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LinkTokenInterface } from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import { AutomationCompatible } from "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import { ConfirmedOwner } from "@chainlink/contracts@1.1.1/src/v0.8/shared/access/ConfirmedOwner.sol";
import { VRFV2WrapperConsumerBase } from "@chainlink/contracts@1.1.1/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";

error LessThanMinimumAmount(uint256 required);
error UpkeepIsAlreadyInPausedState();
error UpkeepIsAlreadyInUnpausedOrActiveState();
error UpkeepIsNotRegisteredYet();
error UpkeepIsAlreadyCancelled();
error UpkeepNeedsToBeCancelledFirst();

struct RegistrationParams {
  string name;
  bytes encryptedEmail;
  address upkeepContract;
  uint32 gasLimit;
  address adminAddress;
  uint8 triggerType;
  bytes checkData;
  bytes triggerConfig;
  bytes offchainConfig;
  uint96 amount;
}

/**
 * string name = "test upkeep";
 * bytes encryptedEmail = 0x;
 * address upkeepContract = 0x...;
 * uint32 gasLimit = 500000;
 * address adminAddress = 0x....;
 * uint8 triggerType = 0;
 * bytes checkData = 0x;
 * bytes triggerConfig = 0x;
 * bytes offchainConfig = 0x;
 * uint96 amount = 1000000000000000000;
 */

interface AutomationRegistrarInterface {
  function registerUpkeep(RegistrationParams calldata requestParams)
    external
    returns (uint256);
}

interface KeeperRegistryInterface {
  function addFunds(uint256 id, uint96 amount) external;

  function pauseUpkeep(uint256 id) external;

  function unpauseUpkeep(uint256 id) external;

  function cancelUpkeep(uint256 id) external;

  function setUpkeepGasLimit(uint256 id, uint32 gasLimit) external;

  function withdrawFunds(uint256 id, address to) external;
}

contract PlayAutomateVRFSolo is
  AutomationCompatible,
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
    // sender
  }
  mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */

  // past requests Id.
  uint256[] public requestIds;
  uint256 public lastRequestId;

  uint256 public s_numberOfPerformUpkeepCallsForLatestUpkeep;
  uint256 constant endDate = 1715781439;
  uint256 public s_latestUpkeepId;
  bool public s_isLatestUpkeepPaused;
  bool public s_isLatestUpkeepCancelled;

  // eth-sepolia
  // 0x779877A7B0D9E8603169DdbD7836e478b4624789
  // 0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976
  // 0x86EFBD0b6736Bed994962f9797049422A3A8E8Ad

  //   LinkTokenInterface public LINK;
  //   AutomationRegistrarInterface public REGISTRAR;
  //   KeeperRegistryInterface public KEEPER_REGISTRY;

  // Hardcoded for Eth-Sepolia network
  // LinkTokenInterface public constant LINK =
  //     LinkTokenInterface(0x779877A7B0D9E8603169DdbD7836e478b4624789);

  // AutomationRegistrarInterface public constant REGISTRAR =
  //   AutomationRegistrarInterface(0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976);
  // KeeperRegistryInterface public constant KEEPER_REGISTRY =
  //   KeeperRegistryInterface(0x86EFBD0b6736Bed994962f9797049422A3A8E8Ad);
  AutomationRegistrarInterface public REGISTRAR;
  KeeperRegistryInterface public KEEPER_REGISTRY;

  uint32 callbackGasLimit = 100000;

  // The default is 3, but you can set this higher.
  uint16 requestConfirmations = 3;

  // For this example, retrieve 2 random values in one request.
  // Cannot exceed VRFV2Wrapper.getConfig().maxNumWords.
  uint32 numWords = 1;

  // Address LINK - hardcoded for Sepolia
  // address linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

  // address WRAPPER - hardcoded for Sepolia
  //   address wrapperAddress = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;

  constructor(
    address wrapperAddress,
    address linkAddress,
    address registrarAddress,
    address keeperRegistryAddress
  )
    // address linkAddress,
    // address registrarAddress,
    // address keeperRegistryAddress
    ConfirmedOwner(msg.sender)
    VRFV2WrapperConsumerBase(linkAddress, wrapperAddress)
  {
    // LINK = LinkTokenInterface(linkAddress);
    // REGISTRAR = AutomationRegistrarInterface(registrarAddress);
    // KEEPER_REGISTRY = KeeperRegistryInterface(keeperRegistryAddress);
  }

  // --> LINK amount from
  // Note: The upkeep that will be registered here won't be visible in the Automation UI (https://automation.chain.link/) because the adminAddress is being set to the address of this contract (not to any wallet).
  function registerUpkeep(
    string memory upkeepName,
    uint96 initialAmount,
    uint32 gasLimit
  ) external {
    // get FUND FIRST

    s_numberOfPerformUpkeepCallsForLatestUpkeep = 0;
    s_isLatestUpkeepPaused = false;
    s_isLatestUpkeepCancelled = false;

    bytes memory encryptedEmail = "";
    address upkeepContract = address(this);
    address adminAddress = address(this); // Note: Setting adminAddress as address of this contract, so as to have the authorization to call the management functions like pause, unpause, cancel, etc. as they can be called only by the admin.
    uint8 triggerType = 0;
    bytes memory checkData = ""; //
    bytes memory triggerConfig = "";
    bytes memory offchainConfig = "";

    RegistrationParams memory params = RegistrationParams(
      upkeepName,
      encryptedEmail,
      upkeepContract,
      gasLimit,
      adminAddress,
      triggerType,
      checkData,
      triggerConfig,
      offchainConfig,
      initialAmount
    );

    // LINK must be approved for transfer - this can be done every time or once
    // with an infinite approval
    if (params.amount < 1e18) {
      revert LessThanMinimumAmount(1e18);
    }
    LINK.approve(address(REGISTRAR), params.amount);

    uint256 upkeepID = REGISTRAR.registerUpkeep(params);
    //
    if (upkeepID != 0) {
      // DEV - Use the upkeepID however you see fit
      // store it into
      s_latestUpkeepId = upkeepID;
    } else {
      revert("auto-approve disabled");
    }
  }

  function checkUpkeep(
    bytes memory /*checkdata*/
  )
    public
    view
    override
    returns (
      bool upkeepNeeded,
      bytes memory /* performData*/
    )
  {
    // s_account_play[]
    // even though it's conditional but it is based on
    upkeepNeeded =
      block.timestamp > endDate &&
      s_numberOfPerformUpkeepCallsForLatestUpkeep == 0;

    return (upkeepNeeded, "");
  }

  // change into internal
  function requestRandomWords()
    public
    returns (
      // onlyOwner
      uint256 requestId
    )
  {
    // store roomID:
    // request LINK transfer

    requestId = requestRandomness(
      callbackGasLimit,
      requestConfirmations,
      numWords
    );

    s_requests[requestId] = RequestStatus({
      paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
      randomWords: new uint256[](0),
      fulfilled: false
    });

    requestIds.push(requestId);
    // what's for?
    lastRequestId = requestId;
    emit RequestSent(requestId, numWords);
    // emit the damn
    return requestId; //requestID from Chainlink
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
    // LinkTokenInterface link = LinkTokenInterface(linkAddress);
    require(
      LINK.transfer(msg.sender, LINK.balanceOf(address(this))),
      "Unable to transfer"
    );
  }

  function performUpkeep(
    bytes calldata /* performData */
  ) external override {
    (bool upkeepNeeded, ) = checkUpkeep("");
    if (upkeepNeeded) requestRandomWords();
    // s_numberOfPerformUpkeepCallsForLatestUpkeep += 1;
  }
}
