pragma solidity >=0.8.0;

contract AccessControl {
    address public admin;
    address[] public owners;
    mapping(address => bool) public isOwner;

    modifier onlyOwner() {
        require(isOwner[msg.sender] || msg.sender == admin, "Admin restricted access");
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "Address is null");
        _;
    }

    constructor(address[] memory _owners) {
        admin = msg.sender;
        require(_owners.length >= 3, "At least 3 owners are required");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Address is null");
            require(!isOwner[owner], "Duplicate owner");
            owners.push(owner);
            isOwner[owner] = true;
        }
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getAdmin() public view returns (address) {
        return admin;
    }

    function getOwnerCount() public view returns (uint256) {
        return owners.length;
    }

    function addNewOwner(address _newOwner) public onlyOwner notNull(_newOwner) {
        require(!isOwner[_newOwner], "Address is already an owner");
        require(owners.length < 10, "Max 10 owners allowed");
        isOwner[_newOwner] = true;
        owners.push(_newOwner);
    }

    function removeOwner(address _owner) public onlyOwner notNull(_owner) {
        require(isOwner[_owner], "Not an owner");
        require(owners.length > 3, "At least 3 owners are required");

        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                isOwner[_owner] = false;
                break;
            }
        }
    }

    function changeAdmin(address to) public onlyOwner notNull(to) {
        require(msg.sender == admin, "Only admin can change admin");
        admin = to;

        if (!isOwner[to]) {
            isOwner[to] = true;
            owners.push(to);
        }
    }
}
