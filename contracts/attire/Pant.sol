pragma solidity >=0.4.21 <0.6.0;

contract Pant {
  uint[3] = _volume;
  address private _owner;

  constructor(uint256 length, uint256 width, uint256 height, address owner) public {
    _volume[0] = length;
    _volume[1] = width;
    _volume[2] = height;
    _owner = owner;
  }
}
