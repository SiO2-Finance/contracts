// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.11;

import {ERC20} from '../open-zeppelin/ERC20.sol';
import {Ownable} from '../open-zeppelin/Ownable.sol';
import {ITransferHook} from '../interfaces/ITransferHook.sol';
import {VersionedInitializable} from '../utils/VersionedInitializable.sol';
import {SafeMath} from '../open-zeppelin/SafeMath.sol';

/**
 * @notice implementation of the SiO2 token contract
 * @author SiO2
 */
contract SiO2Token is Ownable, ERC20, VersionedInitializable {
  using SafeMath for uint256;

  /// @dev snapshot of a value on a specific block, used for balances
  struct Snapshot {
    uint128 blockNumber;
    uint128 value;
  }

  string internal constant NAME = 'SiO2 Token';
  string internal constant SYMBOL = 'SiO2';
  uint8 internal constant DECIMALS = 18;

  /// @dev the amount being distributed for the PSI and PEI
  uint256 internal constant DISTRIBUTION_AMOUNT = 700000000 ether;
  /// @dev the amount being distribyted by liquidity miniong incentives
  uint256 internal constant INCENTIVE_AMOUNT = 300000000 ether;

  uint256 public constant REVISION = 1;

  bool public allowTransfer = false;

  /// @dev owner => next valid nonce to submit with permit()
  mapping(address => uint256) public _nonces;

  mapping(address => mapping(uint256 => Snapshot)) public _snapshots;

  mapping(address => uint256) public _countsSnapshots;
 
  mapping(address => bool) public _senderWhiteList;

  /// @dev reference to the SiO2 governance contract to call (if initialized) on _beforeTokenTransfer
  /// !!! IMPORTANT The SiO2 governance is considered a trustable contract, being its responsibility
  /// to control all potential reentrancies by calling back the SiO2Token
  ITransferHook public _sio2Governance;

  bytes32 public DOMAIN_SEPARATOR;
  bytes public constant EIP712_REVISION = bytes('1');
  bytes32 internal constant EIP712_DOMAIN = keccak256(
    'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
  );
  bytes32 public constant PERMIT_TYPEHASH = keccak256(
    'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'
  );

  event SnapshotDone(address owner, uint128 oldValue, uint128 newValue);

  constructor() public ERC20(NAME, SYMBOL) Ownable(){}

  receive()  external payable {}

  /**
   * @dev initializes the contract upon assignment to the InitializableAdminUpgradeabilityProxy
   * @param vestingAddress the address of the vesting contract
   */
  function initialize(
    address vestingAddress,
    address vaultAddress,
    ITransferHook sio2Governance
  ) external initializer {
    uint256 chainId;

    //solium-disable-next-line
    assembly {
      chainId := chainid()
    }

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        EIP712_DOMAIN,
        keccak256(bytes(NAME)),
        keccak256(EIP712_REVISION),
        chainId,
        address(this)
      )
    );
    _name = NAME;
    _symbol = SYMBOL;
    _setupDecimals(DECIMALS);
    _sio2Governance = sio2Governance;

    // set up owner
    address msgSender = _msgSender();
    _owner = msgSender;
    emit OwnershipTransferred(address(0), msgSender);

    _mint(vestingAddress, DISTRIBUTION_AMOUNT);
    _mint(vaultAddress, INCENTIVE_AMOUNT);
  }

  /**
   * @dev implements the permit function as for https://github.com/ethereum/EIPs/blob/8a34d644aacf0f9f8f00815307fd7dd5da07655f/EIPS/eip-2612.md
   * @param owner the owner of the funds
   * @param spender the spender
   * @param value the amount
   * @param deadline the deadline timestamp, type(uint256).max for no deadline
   * @param v signature param
   * @param s signature param
   * @param r signature param
   */

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(owner != address(0), 'INVALID_OWNER');
    //solium-disable-next-line
    require(block.timestamp <= deadline, 'INVALID_EXPIRATION');
    uint256 currentValidNonce = _nonces[owner];
    bytes32 digest = keccak256(
      abi.encodePacked(
        '\x19\x01',
        DOMAIN_SEPARATOR,
        keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, currentValidNonce, deadline))
      )
    );

    require(owner == ecrecover(digest, v, r, s), 'INVALID_SIGNATURE');
    _nonces[owner] = currentValidNonce.add(1);
    _approve(owner, spender, value);
  }

  /**
   * @dev returns the revision of the implementation contract
   */
  function getRevision() internal override pure returns (uint256) {
    return REVISION;
  }

  /**
   * @dev Writes a snapshot for an owner of tokens
   * @param owner The owner of the tokens
   * @param oldValue The value before the operation that is gonna be executed after the snapshot
   * @param newValue The value after the operation
   */
  function _writeSnapshot(
    address owner,
    uint128 oldValue,
    uint128 newValue
  ) internal {
    uint128 currentBlock = uint128(block.number);

    uint256 ownerCountOfSnapshots = _countsSnapshots[owner];
    mapping(uint256 => Snapshot) storage snapshotsOwner = _snapshots[owner];

    // Doing multiple operations in the same block
    if (
      ownerCountOfSnapshots != 0 &&
      snapshotsOwner[ownerCountOfSnapshots - 1].blockNumber == currentBlock
    ) {
      snapshotsOwner[ownerCountOfSnapshots - 1].value = newValue;
    } else {
      snapshotsOwner[ownerCountOfSnapshots] = Snapshot(currentBlock, newValue);
      _countsSnapshots[owner] = ownerCountOfSnapshots + 1;
    }

    emit SnapshotDone(owner, oldValue, newValue);
  }

  /**
   * @dev Writes a snapshot before any operation involving transfer of value: _transfer, _mint and _burn
   * - On _transfer, it writes snapshots for both "from" and "to"
   * - On _mint, only for _to
   * - On _burn, only for _from
   * @param from the from address
   * @param to the to address
   * @param amount the amount to transfer
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    if (from == to) {
      return;
    }

    require(_allowTransfer(from, to), "UNABLE_TO_TRANSFER");

    if (from != address(0)) {
      uint256 fromBalance = balanceOf(from);
      _writeSnapshot(from, uint128(fromBalance), uint128(fromBalance.sub(amount)));
    }
    if (to != address(0)) {
      uint256 toBalance = balanceOf(to);
      _writeSnapshot(to, uint128(toBalance), uint128(toBalance.add(amount)));
    }

    // caching the sio2 governance address to avoid multiple state loads
    ITransferHook sio2Governance = _sio2Governance;
    if (sio2Governance != ITransferHook(address(0))) {
      sio2Governance.onTransfer(from, to, amount);
    }
  }

  /**
   * @dev check if the sender or msg.sender can transfer asset
   */
  function _allowTransfer(address sender, address receipt) internal returns (bool) {
    // allow _mint or _burn
    if(address(0) == sender || address(0) == receipt){
      return true;
    }

    // allow msg.sender in sender list to transfer
    // support transer and transferFrom
    if(_senderWhiteList[msg.sender]){
      return true;
    }

    // allow transfer after the locked window
    if(allowTransfer){
      return true;
    }

    return false;
  }

  /**
   * @dev enable or disable transfer function for accounts
   */
  function setAllowTransfer(bool allowed) onlyOwner public {
    allowTransfer = allowed;
  }

  /**
   * @dev added address to the sender whitelist
   */
  function setSenderWhiteList(address[] memory whileList, bool allowed) onlyOwner public{
    for(uint i = 0; i < whileList.length; i++){
      require(address(0) != whileList[i], "INVALID_ADDRESS");
      _senderWhiteList[whileList[i]] = allowed;
    }
  }
}
