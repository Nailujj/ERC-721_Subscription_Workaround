// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ERC20_Adjusted.sol";


contract Subscription is ERC721, ERC721Enumerable, Pausable, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    IERC20 public tokenAddress; //THIS IS THE TOKEN THAT CAN BE USED TO MINT THE SUBSCRIPTION TOKEN (e.g. USDC)
    uint public rate;   //Price of the NFT
    uint public referralValue; //amount of tokens that the referral address is getting as credit

    Sub[] public subMemory;
    string public baseURI;

    mapping (address => Referrer) public referralDB;

    struct Sub{
        uint tokenId;
        uint timestamp;
    }

    struct Referrer {
        uint balance;
        bool isBlacklisted;
    }

    constructor() ERC721("PolarSubscription", "PS") {
    }


    //functions
    function _refer(address referral) internal {
        referralDB[referral].balance += referralValue/(10**18);
    }

    function _verifyUser(address _withdrawer) internal view {
        require(referralDB[msg.sender].balance != 0, "You do not have referral Balance" );
        require(referralDB[msg.sender].isBlacklisted == false, "This wallet is blacklisted. Request support");
    }

    function safeMint() public {
        require(isApprovedForAll(msg.sender, owner()), "Your Approval isnt complete yet");
        require(tokenAddress.allowance(msg.sender, address (this)) >= rate, "allowance too low");
        tokenAddress.transferFrom(msg.sender, address(this), rate);
        uint256 tokenId = _tokenIdCounter.current();
        subMemory.push(Sub(tokenId,block.timestamp));
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }

    function mintWithReferral(address referral) public {
        require(msg.sender != referral, "you cannot refer yourself");
        safeMint();
        _refer(referral);
    }

    function burnExpired()external onlyOwner {
        for(uint i; i < subMemory.length; i++ ){
            if(subMemory[i].timestamp + 30 days <= block.timestamp){//ADJUST TO TIMESTAMP YOU WANTTO Burn AFTER
                _burn(subMemory[i].tokenId);
                subMemory[i] = subMemory[subMemory.length-1]; // Delete NFT from Memory
                subMemory.pop();
            }
        }
    }

    function userWithdrawReferral()public {
        _verifyUser(msg.sender);
        uint balance = referralDB[msg.sender].balance;
        referralDB[msg.sender].balance = 0;
        tokenAddress.transfer(msg.sender, balance*10**18);
    }

    function withdrawTreasury() public onlyOwner {
        tokenAddress.transfer(msg.sender, tokenAddress.balanceOf(address(this)));
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }



    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    //Setters
    function setRate(uint newRate)external onlyOwner{
        rate = newRate*10**18; //Adjust decimals!
    }

    function setTreasurer(address newTreasurer)external onlyOwner {
        treasurer = newTreasurer;
    }

    function setbaseURI(string memory _newURI)external onlyOwner{
        baseURI = _newURI;
    }

    function setTokenAddress(address _mintToken)external onlyOwner {
        tokenAddress = IERC20(_mintToken);
    }    //sets tokenaddress which is used to pay with later

    function getBalance()public view returns(uint){
        return referralDB[msg.sender].balance;
    }

    function setRefferal(uint newReferral) external onlyOwner{  //Prohibits blacklisted NFT owners to withdraw funds from referral
        referralValue = newReferral*10**18;
    }

    function setBlacklist(address _address)external onlyOwner{
        referralDB[_address].isBlacklisted = true;
    }

    function setFrostAddress(address _frost)external onlyOwner{
        frost = IERC20(_frost);
    }

    //others
    function _baseURI() internal pure override returns (string memory) {
        return "baseURI";
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
