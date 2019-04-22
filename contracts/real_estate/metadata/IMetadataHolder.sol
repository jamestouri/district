pragma solidity >=0.4.21 <0.6.0;

import "erc821/contracts/ERC165.sol";


contract IMetadataHolder is ERC165 {
  function getMetadata(uint256 /* assetId */) external view returns (string);
}
