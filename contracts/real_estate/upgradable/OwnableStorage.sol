pragma solidity >=0.4.21 <0.6.0;

contract OwnableStorage {
  address public owner;

  constructor() internal {
    owner = msg.sender;
  }
}
