pragma solidity >=0.4.21 <0.6.0;

contract DelegateProxy {
  /**
   * @dev Performs a delegatecall and returns whatever the delegatecall returned
    (entire context execution will return!)
   * @param _dst Destination address to perform the delegatecall
   * @param _calldata Calldata for the delegatecall
   */
  function delegatedFwd(address _dst, ) {
    require(isContract(_dst), "The Destination address is not a contract");

    assembly {
      let result := delegatecall(sub(gas, 10000), _dst, add(_calldata, 0x20),
        mload(_calldata), 0, 0)

      let size := returndatasize

      let ptr := mload(0x40)

      returndatacopy(ptr, 0, size)

      switch result case 0 { revert(ptr, size)}
      default { return(ptr, size) }
    }
  }

  function isContract(address _target) internal view returns (bool) {
    uint256 size;

    assembly {size := extcodesize(_target)}
    return size > 0;
  }
}
