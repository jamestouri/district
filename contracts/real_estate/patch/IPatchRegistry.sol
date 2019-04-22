pragma solidity >=0.4.21 <0.6.0;

contract IPatchRegistry {
  function mint(address to, string metadata) external returns (uint256);
  function ownerOf(uint256 _tokenId) public view returns (address _owner); // from ERC721

  // Events

  event CreatePatch(
    address indexed _owner,
    uint256 indexed _patchId,
    string _data
  );

  event AddLand(
    uint256 indexed _patchId,
    uint256 indexed _landId
  );

  event RemoveLand(
    uint256 indexed _patchId,
    uint256 indexed _landId,
    address indexed _destinatary
  );

  event Update(
    uint256 indexed _assetId,
    address indexed _holder,
    address indexed _operator,
    string _data
  );

  event UpdateOperator(
    uint256 indexed _patchId,
    address indexed _operator
  );

  event SetPatchRegistry(
    address indexed _registry
  );
}
