pragma solidity >=0.4.21 <0.6.0;

import "../Storage.sol";

contract Ownable is Storage {
  /* EVENT definition: The application would connect to
  Ethereum node over JSON-RPC and either watch
  (wait) for the event to happen or read all the past events to sync up
  the application internal state with Ethereum blockchain. */
  event OwnerUpdate(address _prevOwner, address _newOwner);

  modifier onlyOwner {
    assert(msg.sender == owner);
    _;
  }

  function transferOwnership(address _newOwner) public onlyOwner {
    require(_newOwner != owner, "Cannot transfer to yourself");
    owner = _newOwner;
  }
}
