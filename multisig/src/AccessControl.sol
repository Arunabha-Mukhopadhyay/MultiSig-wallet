pragma solidity >=0.8.0;


// import the openzeppelin library
import "@openzeppelin/contracts/access/Ownable.sol";


contract AccessControl {
    address public admin;
    address[] public owners;
    mapping(address => bool) public isOwner;


    modifier onlyOwner(address _address) {
        require(msg.sender == admin || isOwner[msg.sender],"Adimin restricted access");
        if(admin == msg.sender){
          owners.push(_address);
          isOwner[_address] = true;
        }
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0),"Address is null");
        _;
    }

    modifier addOwner(address _address) {
        require(isOwner[_address] == false,"Address is already an owner");
        isOwner[_address] = true;
        owners.push(_address);
        _;
    }


    constructor(address[] memory _owners)  onlyOwner(msg.sender) notNull(msg.sender) {
        admin = msg.sender;
        require(
            _owners.length >= 3,
            "At least 3 owners are required"
        );
        for(uint i = 0; i < _owners.length; i++) {
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
    }

    function getOwners() public view returns(address[] memory) {
        return owners;
    }

    function getOwnerCount() public view returns(uint) {
        return owners.length;
    }

    function addNewOwner(address _newOwner) public onlyOwner(msg.sender) notNull(_newOwner) addOwner(_newOwner) {
        require(owners.length < 10,"Max 10 owners allowed");
        isOwner[_newOwner] = true;
        owners.push(_newOwner);
    }

    function removeOwner(address _owner) public onlyOwner(msg.sender) notNull(_owner) {
        require(owners.length > 2,"At least 3 owners are required");
        for(uint i = 0; i < owners.length; i++) {
            if(owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                isOwner[_owner] = false;    // can delete one owner at a time not continuously
                break;
            }
        }
    }


    function changeAdmin(address from , address to) public onlyOwner(from) notNull(to) {
        require(from == admin,"Only admin can change admin");
        for(uint i = 0; i < owners.length; i++) {
            if(owners[i] == from) {
                admin = to;
                break;
            }
        }
        isOwner[from] = false;
        isOwner[to] = true;  
    }

}