pragma solidity >=0.4.21 <0.6.0;

import "../Storage.sol";

import "../upgradable/Ownable.sol";

import "../upgradable/IApplication.sol";

import "erc821/contracts/FullAssetRegistry.sol";

import "./IPatchRegistry.sol";

import "../metadata/IMetadataHolder.sol";



/* solium-disable function-order */
contract PatchRegistry is Storage, Ownable, FullAssetRegistry, IPatchRegistry {
  bytes4 constant public GET_METADATA = bytes4(keccak256("getMetadata(uint256)"));

  function initialize(bytes) external {
    _name = "Districted Patch";
    _symbol = "Patch";
    _description = "Contract that stores the Patch registry";
  }

  modifier onlyProxyOwner() {
    require(msg.sender == proxyOwner, "This function can only be called by the proxy owner");
    _;
  }

  modifier onlyDeployer() {
    require(msg.sender == proxyOwner || authorizedDeploy[msg.sender], "This function can only be called by an authorized deployer");
    _;
  }

  modifier onlyOwnerOf(uint256 assetId) {
    require(
      msg.sender == _ownerOf(assetId),
      "This function can only be called by the owner of the asset"
    );
    _;
  }

  modifier onlyUpdateAuthorized(uint256 tokenId) {
    require(
      msg.sender == _ownerOf(tokenId) ||
      _isAuthorized(msg.sender, tokenId) ||
      _isUpdateAuthorized(msg.sender, tokenId),
      "msg.sender is not authorized to update"
    );
    _;
  }

  //
  // Authorization
  //

  function isUpdateAuthorized(address operator, uint256 assetId) external view returns (bool) {
    return _isUpdateAuthorized(operator, assetId);
  }

  function _isUpdateAuthorized(address operator, uint256 assetId) internal view returns (bool) {
    return operator == _ownerOf(assetId) || updateOperator[assetId] == operator;
  }

  function authorizeDeploy(address beneficiary) external onlyProxyOwner {
    require(beneficiary != address(0), "invalid address");
    require(authorizedDeploy[beneficiary] == false, "address is already authorized");

    authorizedDeploy[beneficiary] = true;
    emit DeployAuthorized(msg.sender, beneficiary);
  }

  function forbidDeploy(address beneficiary) external onlyProxyOwner {
    require(beneficiary != address(0), "invalid address");
    require(authorizedDeploy[beneficiary], "address is already forbidden");

    authorizedDeploy[beneficiary] = false;
    emit DeployForbidden(msg.sender, beneficiary);
  }

  //
  // Patch Create
  //

  function assignNewParcel(int x, int y, address beneficiary) external onlyDeployer {
    _generate(_encodeTokenId(x, y), beneficiary);
  }

  function assignMultipleParcels(int[] x, int[] y, address beneficiary) external onlyDeployer {
    for (uint i = 0; i < x.length; i++) {
      _generate(_encodeTokenId(x[i], y[i]), beneficiary);
    }
  }

  //
  // Inactive keys after 1 year lose ownership
  //

  function ping() external {
    // solium-disable-next-line security/no-block-members
    latestPing[msg.sender] = block.timestamp;
  }

  function setLatestToNow(address user) external {
    require(msg.sender == proxyOwner || _isApprovedForAll(msg.sender, user), "Unauthorized user");
    // solium-disable-next-line security/no-block-members
    latestPing[user] = block.timestamp;
  }

  //
  // Patch Getters
  //

  function encodeTokenId(int x, int y) external pure returns (uint) {
    return _encodeTokenId(x, y);
  }

  function _encodeTokenId(int x, int y) internal pure returns (uint result) {
    require(
      -1000000 < x && x < 1000000 && -1000000 < y && y < 1000000,
      "The coordinates should be inside bounds"
    );
    return _unsafeEncodeTokenId(x, y);
  }

  function _unsafeEncodeTokenId(int x, int y) internal pure returns (uint) {
    return ((uint(x) * factor) & clearLow) | (uint(y) & clearHigh);
  }

  function decodeTokenId(uint value) external pure returns (int, int) {
    return _decodeTokenId(value);
  }

  function _unsafeDecodeTokenId(uint value) internal pure returns (int x, int y) {
    x = expandNegative128BitCast((value & clearLow) >> 128);
    y = expandNegative128BitCast(value & clearHigh);
  }

  function _decodeTokenId(uint value) internal pure returns (int x, int y) {
    (x, y) = _unsafeDecodeTokenId(value);
    require(
      -1000000 < x && x < 1000000 && -1000000 < y && y < 1000000,
      "The coordinates should be inside bounds"
    );
  }

  function expandNegative128BitCast(uint value) internal pure returns (int) {
    if (value & (1<<127) != 0) {
      return int(value | clearLow);
    }
    return int(value);
  }

  function exists(int x, int y) external view returns (bool) {
    return _exists(x, y);
  }

  function _exists(int x, int y) internal view returns (bool) {
    return _exists(_encodeTokenId(x, y));
  }

  function ownerOfPatch(int x, int y) external view returns (address) {
    return _ownerOfPatch(x, y);
  }

  function _ownerOfPatch(int x, int y) internal view returns (address) {
    return _ownerOf(_encodeTokenId(x, y));
  }

  function ownerOfPatchMany(int[] x, int[] y) external view returns (address[]) {
    require(x.length > 0, "You should supply at least one coordinate");
    require(x.length == y.length, "The coordinates should have the same length");

    address[] memory addrs = new address[](x.length);
    for (uint i = 0; i < x.length; i++) {
      addrs[i] = _ownerOfPatch(x[i], y[i]);
    }

    return addrs;
  }

  function landOf(address owner) external view returns (int[], int[]) {
    uint256 len = _assetsOf[owner].length;
    int[] memory x = new int[](len);
    int[] memory y = new int[](len);

    int assetX;
    int assetY;
    for (uint i = 0; i < len; i++) {
      (assetX, assetY) = _decodeTokenId(_assetsOf[owner][i]);
      x[i] = assetX;
      y[i] = assetY;
    }

    return (x, y);
  }

  function tokenMetadata(uint256 assetId) external view returns (string) {
    return _tokenMetadata(assetId);
  }

  function _tokenMetadata(uint256 assetId) internal view returns (string) {
    address _owner = _ownerOf(assetId);
    if (_isContract(_owner) && _owner != address(estateRegistry)) {
      if ((ERC165(_owner)).supportsInterface(GET_METADATA)) {
        return IMetadataHolder(_owner).getMetadata(assetId);
      }
    }
    return _assetData[assetId];
  }

  function landData(int x, int y) external view returns (string) {
    return _tokenMetadata(_encodeTokenId(x, y));
  }

  //
  // Patch Transfer
  //

  function transferFrom(address from, address to, uint256 assetId) external {
    require(to != address(estateRegistry), "EstateRegistry unsafe transfers are not allowed");
    return _doTransferFrom(
      from,
      to,
      assetId,
      "",
      false
    );
  }

  function transferPatch(int x, int y, address to) external {
    uint256 tokenId = _encodeTokenId(x, y);
    _doTransferFrom(
      _ownerOf(tokenId),
      to,
      tokenId,
      "",
      true
    );
  }

  function transferManyPatch(int[] x, int[] y, address to) external {
    require(x.length > 0, "You should supply at least one coordinate");
    require(x.length == y.length, "The coordinates should have the same length");

    for (uint i = 0; i < x.length; i++) {
      uint256 tokenId = _encodeTokenId(x[i], y[i]);
      _doTransferFrom(
        _ownerOf(tokenId),
        to,
        tokenId,
        "",
        true
      );
    }
  }

  function transferPatchToEstate(int x, int y, uint256 estateId) external {
    require(
      estateRegistry.ownerOf(estateId) == msg.sender,
      "You must own the Estate you want to transfer to"
    );

    uint256 tokenId = _encodeTokenId(x, y);
    _doTransferFrom(
      _ownerOf(tokenId),
      address(estateRegistry),
      tokenId,
      toBytes(estateId),
      true
    );
  }


  function setUpdateOperator(uint256 assetId, address operator) external onlyAuthorized(assetId) {
    updateOperator[assetId] = operator;
    emit UpdateOperator(assetId, operator);
  }



  function toBytes(uint256 x) internal pure returns (bytes b) {
    b = new bytes(32);
    // solium-disable-next-line security/no-inline-assembly
    assembly { mstore(add(b, 32), x) }
  }

  //
  // Patch Update
  //

  function updatePatchData(
    int x,
    int y,
    string data
  )
    external
  {
    return _updatePatchData(x, y, data);
  }

  function _updatePatchData(
    int x,
    int y,
    string data
  )
    internal
    onlyUpdateAuthorized(_encodeTokenId(x, y))
  {
    uint256 assetId = _encodeTokenId(x, y);
    address owner = _holderOf[assetId];

    _update(assetId, data);

    emit Update(
      assetId,
      owner,
      msg.sender,
      data
    );
  }

  function updateManyPatchData(int[] x, int[] y, string data) external {
    require(x.length > 0, "You should supply at least one coordinate");
    require(x.length == y.length, "The coordinates should have the same length");
    for (uint i = 0; i < x.length; i++) {
      _updatePatchData(x[i], y[i], data);
    }
  }

  function _doTransferFrom(
    address from,
    address to,
    uint256 assetId,
    bytes userData,
    bool doCheck
  )
    internal
  {
    updateOperator[assetId] = address(0);

    super._doTransferFrom(
      from,
      to,
      assetId,
      userData,
      doCheck
    );
  }

  function _isContract(address addr) internal view returns (bool) {
    uint size;
    // solium-disable-next-line security/no-inline-assembly
    assembly { size := extcodesize(addr) }
    return size > 0;
  }
