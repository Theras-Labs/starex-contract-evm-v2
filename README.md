# STAR-EX v2

## Overview

This repository contains the Solidity smart contracts that govern various aspects of our blockchain-based game. The shop, cross-airdrop, marketplace, and NFT contracts will be using Theras' tokenizing hub, which is continually being improved and upgraded to facilitate easier cross-chain features. Meanwhile, the utility of other aspects and the interoperability of the game will be explained here until the team finds a way to modularize them again if needed.

### Update on Cross-Crafting Contracts

Our cross-crafting system is designed with a modular approach: the main crafting module resides on the BASE-NETWORK chain, while additional contracts serve as aggregators. These contracts play a crucial role in system locking and utilize off-chain messages for seamless backend synchronization. Currently in the prototype stage, they require enhancements in scalability, particularly to support increased quantities and enable freestyle crafting using external NFTs beyond the STAR-EX ecosystem.

This cross-crafting mechanism aims to synergize all items into NFTs, offering players the excitement of discovering both unexpected and planned results. Whether experimenting for mysterious outcomes or following blueprints for anticipated creations, players will engage deeply in crafting. Ongoing adjustments to the tier-balancing of crafted assets ensure a balanced and rewarding gameplay experience.

The cross-crafting contracts have been deployed to the following testnets:
———————————————————————————————————————

```
base:
impl-TRC155 : 0xFe9DF23d3EFAB6cC71D3395aFFB3aa505d1935eB
shop 0x16F0EB9CD042e3D9e519baf660c18f4E8E4eF93e
UUPSbadge 0xE39C0AAA925337a5499A2cCe0D906cc38B5CEA54

starex-ship 0x12e96cef6CdB9DD974152113C2f679086E4d14E0
starex-material 0xe528A72C73F8E79A3d8ACFafE106955dC2858c91

hyape-character. 0x014ED3A42D9B997064De7EE87E727Ee79d5e41ae
hyape-foods 0x1cB05f988fbed3e66582Eb56Ffe6b68D4abB9c16

crafting: 0xd65d3146f6a46158741DB47E56da197115879938
```

———————————————————————————————————————

```

zeta:

impl-TRC155: 0xFe9DF23d3EFAB6cC71D3395aFFB3aa505d1935eB
shop 0x16F0EB9CD042e3D9e519baf660c18f4E8E4eF93e
UUPS badge 0xE39C0AAA925337a5499A2cCe0D906cc38B5CEA54
starex-ship 0x12e96cef6CdB9DD974152113C2f679086E4d14E0
starex-material 0xe528A72C73F8E79A3d8ACFafE106955dC2858c91
crafting: 0xed3f3e6eBf67cf360C5EF3f650e0E69CC3a70CAb
```

———————————————————————————————————————

```

// METER

// impl - trc 1155 - 0x5f7fdc53Ec06767259619D85cc62aD9235422832
// nft project - 0xF0AFab58D180EBD5eB19c8435a353ce60ADF9136
// shop - 0x6705EB61d84fFa6217962A73DA094111892DbC8C
// starex-starship - 0x4ebfCB61c231554233f80d75C8220cDa148cC886
// starex-material - 0x2E7a940b58218a3ccb6118341f64fE4797688122

crafting: 0xA4594D36f64d779eE5D6A8d2b33Ddf936904A480
```

<hr/>
<hr/>
<hr/>

## CHAINLINK INTEGRATION - ONCHAIN GAMEPLAY

3 new features:

- Continously Randomise Challenges & Rewards:
- Decentralised Resources Control
- Cross-chain Challenges (actually extension of 1st one but need to separate for easier judging)

## How we built it

The latest update involving chainlink features:
ccip, vrf, automation, ~~functions~~ , data feed, LxLy-zkEVM Bridge.

there are more to do on polishing the feature to be fully ready goes into mainnet, we are releasing to other EVM first in june, and with the following on-chain gameplay in our mini-game release.

1st Feature: Player enter the game -> the amount and rarity of the rewards will be based on VRF, and to avoid bot cheat, then it will use automation programatically to do re-random again with self-logic

2nd Feature: Each major blockchain who control zone rarity, amount. All those data will be based on chainlink-vrf making it more decentralised and no centralised decision to side with specific network, and it will be automatically refresh for each 3days (or perhaps we change it into each 1week)

3rd Feature: This is mainly for streamer and best when our multiplayer is ready, so viewer can contribute to increase the level of challenges in the game ~~while also able to plant minefiled and steal the resources for incentive program ~~

```
Contracts on-chain gameplays:
Avax fuji token has little only, so deploying to other.

Feature 1: on Avax fuji - 0xFe9DF23d3EFAB6cC71D3395aFFB3aa505d1935eB
Feature 2: on ~~zkEVM crdn testnet~~ Avax fuji - 0xBe913A4F01fd9012674DC342aB1dD2d8fbeeA6Fa
Feature 3:  ccip  Amoi -  0x0c5941a32eABc3de826343e997EB03f762C64A0f , Sepolia - 0xb070889604849da652b6119e33C4BF881917ff77
```

## Contracts deployed:

### Sepolia Testnet - 11155111

- **TRC1155 Implementation**: 0xEF3177ebc9190f5007E39d8Ce314d66Db5559DF2
- **THERAS SHOP**: 0x07Ab9eed2d023dB86a1E6F38bC71565f76d561Fb
- **CLAIM MANAGER**: TBC
- **NFT Project (BADGE)**: 0x23cEb32CaCB7dbe2D78C2a38ab6E99aFbd626565
- **1155 STAREX STARSHIP**: 0xE41B1f5d9C4d8d1c309118b034C807126D87FcB4
- **1155 STAREX-ASSET**: [Contract Address]
- **AIRDROP POOL**: TBC
- **CRAFTING MANAGER**: TBC

### opBNB Testnet - 842

- **TRC1155 Implementation**: 0x16F0EB9CD042e3D9e519baf660c18f4E8E4eF93e
- **THERAS SHOP**: 0xa921a43516A0c85504d61bd3BD8bcE354a7bBEf1
- **CLAIM MANAGER**: TBC
- **NFT Project (BADGE)**:0xE39C0AAA925337a5499A2cCe0D906cc38B5CEA54
- **STAREX STARSHIP**: 0x12e96cef6CdB9DD974152113C2f679086E4d14E0
- **STAREX MATERIAL**: -
- **AIRDROP POOL**: TBC
- **CRAFTING MANAGER**: TBC

### BTTC Testnet Donaou - 1029

- **TRC1155 Implementation**: 0x16F0EB9CD042e3D9e519baf660c18f4E8E4eF93e
- **THERAS SHOP**: 0xE39C0AAA925337a5499A2cCe0D906cc38B5CEA54
- **CLAIM MANAGER**: TBC
- **NFT Project (BADGE)**: 0xC8E633D1Da2b23A12458682cB0d065A4452b6030
- **1155 STAREX STARSHIP**: 0xD8f003dc5C270aAeDd94B4104402095c4EcE814C
- **1155 STAREX-ASSET**: 0x8B226463af57EC5a9e8b4161BF4287f8606bde34
- **AIRDROP POOL**: TBC
- **CRAFTING MANAGER**: TBC

### Lisk Sepolia - 4202

- **TRC1155 Implementation**: 0x16F0EB9CD042e3D9e519baf660c18f4E8E4eF93e
- **THERAS SHOP**: 0xE39C0AAA925337a5499A2cCe0D906cc38B5CEA54
- **CLAIM MANAGER**: TBC
- **NFT Project (BADGE)**: 0xC8E633D1Da2b23A12458682cB0d065A4452b6030
- **1155 STAREX STARSHIP**: 0xD8f003dc5C270aAeDd94B4104402095c4EcE814C
- **1155 STAREX-ASSET**: 0x8B226463af57EC5a9e8b4161BF4287f8606bde34
- **AIRDROP POOL**: TBC
- **CRAFTING MANAGER**: TBC

```

```
