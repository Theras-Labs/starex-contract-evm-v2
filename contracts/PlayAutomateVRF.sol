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

struct GameMatchInfo {
  RegistrationParams params;
  uint256 upkeepID;
  address initiator;
  uint256 counter;
  bool isLatestUpkeepPaused;
  bool isLatestUpkeepCancelled;
  uint256 latestBlock;
  uint256 vrfLatest;
  uint256 lastRequestId; //vrf Id
}

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

//
interface KeeperRegistryInterface {
  function addFunds(uint256 id, uint96 amount) external;

  function pauseUpkeep(uint256 id) external;

  function unpauseUpkeep(uint256 id) external;

  function cancelUpkeep(uint256 id) external;

  function setUpkeepGasLimit(uint256 id, uint32 gasLimit) external;

  function withdrawFunds(uint256 id, address to) external;
}

library StringUtils {
  function uintToString(uint256 v) internal pure returns (string memory) {
    if (v == 0) {
      return "0";
    }
    uint256 maxLength = 78;
    bytes memory reversed = new bytes(maxLength);
    uint256 i = 0;
    while (v != 0) {
      uint256 remainder = v % 10;
      v = v / 10;
      reversed[i++] = bytes1(uint8(48 + remainder));
    }
    bytes memory s = new bytes(i);
    for (uint256 j = 0; j < i; j++) {
      s[j] = reversed[i - j - 1];
    }
    return string(s);
  }

  function stringToUint(string memory s) internal pure returns (uint256) {
    bytes memory b = bytes(s);
    uint256 result = 0;
    for (uint256 i = 0; i < b.length; i++) {
      if (b[i] >= 0x30 && b[i] <= 0x39) {
        result = result * 10 + (uint256(uint8(b[i])) - 48);
      } else {
        revert("Invalid character in string");
      }
    }
    return result;
  }
}

contract PlayAutomateVRF is
  AutomationCompatible,
  VRFV2WrapperConsumerBase,
  ConfirmedOwner
{
  using StringUtils for uint256;
  using StringUtils for string;
  event RequestSent(uint256 requestId, uint32 numWords, uint256 roomId);
  event RequestFulfilled(
    uint256 requestId,
    uint256[] randomWords,
    uint256 payment,
    uint256 roomId
  );
  struct RequestStatus {
    uint256 paid; // amount paid in link
    bool fulfilled; // whether the request has been successfully fulfilled
    uint256[] randomWords;
    uint256 roomId;
    // sender
  }
  mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */

  // past requests Id.
  uint256[] public requestIds;
  //   uint256 public lastRequestId; //does not matter in game

  // Use consistent naming for the mapping
  mapping(uint256 => GameMatchInfo) public s_gameMatch;
  mapping(uint256 => uint256) public s_upkeepMatchId; // track match id by upkeepid

  // Counter to generate unique match IDs
  uint256 public s_idCounter;

  // Event to emit when an upkeep task is registered
  event UpkeepRegistered(
    uint256 indexed id,
    address indexed initiator,
    address indexed sender,
    string upkeepName,
    uint256 upkeepID,
    uint32 gasLimit
  );

  // eth-sepolia
  // 0x779877A7B0D9E8603169DdbD7836e478b4624789
  // 0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976 // REGISTRARRR -> AutomationRegistrarInterface
  // 0x86EFBD0b6736Bed994962f9797049422A3A8E8Ad // registry -> KeeperRegistryInterface
  // 0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1 // wrapper vrf

  // polygon-amoy testnet
  // 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904
  // 0x99083A4bb154B0a3EC7a0D1eb40370C892Db4225
  // 0x93C0e201f7B158F503a1265B6942088975f92ce7
  // 0x6e6c366a1cd1F92ba87Fd6f96F743B0e6c967Bf0

  // bnb-testnet
  // 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06
  // 0x0631ea498c2Cd8371B020b9eC03f5F779174562B
  // 0x96bb60aAAec09A0FceB4527b81bbF3Cc0c171393
  // 0x471506e6ADED0b9811D05B8cAc8Db25eE839Ac94

  // avax-fuji-testnet
  // 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846
  // 0xD23D3D1b81711D75E1012211f1b65Cc7dBB474e2
  // 0x819B58A646CDd8289275A87653a2aA4902b14fe6
  // 0x327B83F409E1D5f13985c6d0584420FA648f1F56

  //   LinkTokenInterface public LINK;
  AutomationRegistrarInterface public REGISTRAR;
  KeeperRegistryInterface public KEEPER_REGISTRY;

  // gas default for now, need able to change it ?
  uint32 callbackGasLimit = 100000;

  // The default is 3, but you can set this higher.
  uint16 requestConfirmations = 3;

  // For this example, retrieve 2 random values in one request.
  // Cannot exceed VRFV2Wrapper.getConfig().maxNumWords.
  uint32 numWords = 1;

  // address WRAPPER - hardcoded for Sepolia
  //   address wrapperAddress = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;

  constructor(
    address wrapperAddress,
    address linkAddress,
    address registrarAddress,
    address keeperRegistryAddress
  ) {
    // LINK = LinkTokenInterface(linkAddress);
    REGISTRAR = AutomationRegistrarInterface(registrarAddress);
    KEEPER_REGISTRY = KeeperRegistryInterface(keeperRegistryAddress);
  }

  // Note: The upkeep that will be registered here won't be visible in the Automation UI (https://automation.chain.link/) because the adminAddress is being set to the address of this contract (not to any wallet).
  function registerUpkeep(
    // string memory upkeepName,
    uint96 initialAmount,
    uint32 gasLimit
  ) external returns (uint256 id) {
    // require user to transfer around 5 LINK tokens for VRF fund
    require(
      LINK.transferFrom(msg.sender, address(this), 5 * 10**18),
      "Insufficient LINK tokens transferred"
    );

    // Increment the counter to generate unique IDs
    s_idCounter++; // game match 3

    // Create default values for configuration
    bytes memory encryptedEmail;
    address upkeepContract = address(this);
    address adminAddress = address(this); // wont show GUI
    uint8 triggerType = 0;
    bytes memory checkData;
    bytes memory triggerConfig;
    bytes memory offchainConfig;

    // Convert s_idCounter to string
    string memory upkeepName = s_idCounter.uintToString();

    // Create RegistrationParams object
    RegistrationParams memory params = RegistrationParams(
      upkeepName,
      encryptedEmail,
      upkeepContract, //
      gasLimit,
      adminAddress, //
      triggerType,
      checkData,
      triggerConfig,
      offchainConfig,
      initialAmount
    );

    // Approve LINK transfer
    if (params.amount < 1e18) {
      revert LessThanMinimumAmount(1e18);
    }
    LINK.approve(address(REGISTRAR), params.amount);

    // Register upkeep task with Chainlink registrar
    uint256 upkeepID = REGISTRAR.registerUpkeep(params);

    if (upkeepID == 0) {
      revert("auto-approve disabled");
    }

    // Create GameMatchInfo object
    GameMatchInfo memory gameMatchInfo = GameMatchInfo(
      params,
      upkeepID,
      msg.sender, //address
      0, //counter
      false,
      false,
      block.timestamp, //current
      0,
      0
    );

    // Store the registration information in the mapping
    s_gameMatch[s_idCounter] = gameMatchInfo;

    // track upkeepd <> matchId for easier find
    s_upkeepMatchId[upkeepID] = s_idCounter;

    // start immediately to do randomized;
    requestRandomWords(s_idCounter);

    // Emit event with additional information
    emit UpkeepRegistered(
      s_idCounter,
      gameMatchInfo.initiator,
      msg.sender,
      upkeepName,
      upkeepID,
      gasLimit
    );

    // Return the generated ID
    return s_idCounter;
  }

  function addFundsToUpkeep(uint96 amount, uint256 matchId) external {
    // Check if the upkeep for the given match ID exists
    if (s_gameMatch[matchId].upkeepID == 0) {
      revert UpkeepIsNotRegisteredYet();
    }

    // Check if the upkeep for the given match ID is cancelled
    if (s_gameMatch[matchId].isLatestUpkeepCancelled) {
      revert UpkeepIsAlreadyCancelled();
    }

    // Approve LINK transfer
    LINK.approve(address(KEEPER_REGISTRY), amount);

    // Add funds to the upkeep
    KEEPER_REGISTRY.addFunds(s_gameMatch[matchId].upkeepID, amount);
  }

  function withdrawFundsFromUpkeep(uint256 matchId, address to) external {
    if (s_gameMatch[matchId].upkeepID == 0) revert UpkeepIsNotRegisteredYet();
    if (!s_gameMatch[matchId].isLatestUpkeepCancelled)
      revert UpkeepNeedsToBeCancelledFirst();

    KEEPER_REGISTRY.withdrawFunds(s_gameMatch[matchId].upkeepID, to);
  }

  function pauseUpkeep(uint256 matchId) external {
    if (s_gameMatch[matchId].upkeepID == 0) revert UpkeepIsNotRegisteredYet();
    if (s_gameMatch[matchId].isLatestUpkeepCancelled)
      revert UpkeepIsAlreadyCancelled();
    if (s_gameMatch[matchId].isLatestUpkeepPaused)
      revert UpkeepIsAlreadyInPausedState();
    KEEPER_REGISTRY.pauseUpkeep(s_gameMatch[matchId].upkeepID);
    s_gameMatch[matchId].isLatestUpkeepPaused = true;
  }

  function unpauseUpkeep(uint256 matchId) external {
    if (s_gameMatch[matchId].upkeepID == 0) revert UpkeepIsNotRegisteredYet();
    if (s_gameMatch[matchId].isLatestUpkeepCancelled)
      revert UpkeepIsAlreadyCancelled();
    if (!s_gameMatch[matchId].isLatestUpkeepPaused)
      revert UpkeepIsAlreadyInUnpausedOrActiveState();
    KEEPER_REGISTRY.unpauseUpkeep(s_gameMatch[matchId].upkeepID);
    s_gameMatch[matchId].isLatestUpkeepPaused = false;
  }

  function editUpkeepGasLimit(uint256 matchId, uint32 newGasLimit) external {
    if (s_gameMatch[matchId].upkeepID == 0) revert UpkeepIsNotRegisteredYet();
    if (s_gameMatch[matchId].isLatestUpkeepCancelled)
      revert UpkeepIsAlreadyCancelled();
    KEEPER_REGISTRY.setUpkeepGasLimit(
      s_gameMatch[matchId].upkeepID,
      newGasLimit
    );
  }

  function cancelUpkeep(uint256 matchId) external {
    if (s_gameMatch[matchId].upkeepID == 0) revert UpkeepIsNotRegisteredYet();
    if (s_gameMatch[matchId].isLatestUpkeepCancelled)
      revert UpkeepIsAlreadyCancelled();
    KEEPER_REGISTRY.cancelUpkeep(s_gameMatch[matchId].upkeepID);
    s_gameMatch[matchId].isLatestUpkeepPaused = false;
    s_gameMatch[matchId].isLatestUpkeepCancelled = true;
  }

  function castStringToUint(string memory strId)
    external
    pure
    returns (uint256)
  {
    // Convert string to uint
    uint256 id = strId.stringToUint();
    return id;
  }

  function performUpkeep(bytes calldata performData) external override {
    // Decode the performData to extract RegistrationParams
    RegistrationParams memory params = abi.decode(
      performData,
      (RegistrationParams)
    );

    // Convert the params.name (string) to matchId (uint)
    uint256 matchId = params.name.stringToUint();

    // Fetch the gameMatchInfo using the matchId
    GameMatchInfo storage gameMatchInfo = s_gameMatch[matchId];

    // Check if the timestamp condition is met
    // check balance
    if (
      block.timestamp > gameMatchInfo.latestBlock + 30 &&
      !s_gameMatch[matchId].isLatestUpkeepCancelled &&
      !s_gameMatch[matchId].isLatestUpkeepPaused
      // if balance is ready
      // balance must be stored individually to the game match
    ) {
      requestRandomWords(matchId); // start to get the randomId
      // Update the state
      gameMatchInfo.counter += 1;
      gameMatchInfo.latestBlock = block.timestamp;
      //
    }
  }

  // change into internal
  function requestRandomWords(uint256 matchId)
    public
    returns (
      // onlyOwner
      uint256 requestId
    )
  {
    GameMatchInfo storage gameMatchInfo = s_gameMatch[matchId];

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
      fulfilled: false,
      roomId: matchId
    });

    gameMatchInfo.lastRequestId = requestId;

    emit RequestSent(requestId, numWords, matchId);
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
    uint256 matchId = s_requests[_requestId].roomId;

    GameMatchInfo storage gameMatchInfo = s_gameMatch[matchId];
    gameMatchInfo.vrfLatest = _randomWords[0];

    emit RequestFulfilled(
      _requestId,
      _randomWords,
      s_requests[_requestId].paid,
      matchId
    );
  }
}
