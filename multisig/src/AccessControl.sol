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
    constructor() public {

    }
}