//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.3;

import "../IStrat.sol";
import "./IIdleToken.sol";
import "../../vault/IVault.sol";
import "../../misc/Timelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract idleTokenStrat is IStrat {
    
    using SafeERC20 for IERC20;
    IVault public vault;
    IIdleToken public idleToken;
    IERC20 public underlying;
    Timelock public timelock;

    modifier onlyVault {
        require(msg.sender == address(vault));
        _;
    }

    constructor(IVault vault_, IIdleToken idleToken_) {
        vault = vault_;
        idleToken = idleToken_;
        timelock = new Timelock(msg.sender, 7 days);
        underlying = IERC20(idleToken_.underlying());
        underlying.safeApprove(address(idleToken), uint(-1));
    }

    function invest() external override onlyVault {
        uint balance = underlying.balanceOf(address(this));
        require(balance > 0);
        require(idleToken.mintIdleToken(balance) == 0);
    }

    function divest(uint amount) external override onlyVault {
        require(idleToken.redeemIdleToken(amount) == 0);
        underlying.safeTransfer(address(vault), amount);
    }

    // TODO: find an equivalent function in IDLE for unction balanceOfUnderlying(address owner) external returns (uint);
    function calcTotalValue() external override returns (uint) {
        return idleToken.balanceOfUnderlying(address(this));
    }

    // IMPORTANT: This function can only be called by the timelock to recover any token amount including deposited cTokens
    // However, the owner of the timelock must first submit their request and wait 7 days before confirming.
    // This gives depositors a good window to withdraw before a potentially malicious escape
    // The intent is for the owner to be able to rescue funds in the case they become stuck after launch
    // However, users should not trust the owner and watch the timelock contract least once a week on Etherscan
    // In the future, the timelock contract will be destroyed and the functionality will be removed after the code gets audited
    function rescue(address _token, address _to, uint _amount) external {
        require(msg.sender == address(timelock));
        IERC20(_token).transfer(_to, _amount);
    }

    // Any tokens (other than the idleToken) that are sent here by mistake are recoverable by the vault owner
    function sweep(address _token) external {
        address owner = vault.owner();
        require(msg.sender == owner);
        require(_token != address(idleToken));
        IERC20(_token).transfer(owner, IERC20(_token).balanceOf(address(this)));
    }

}