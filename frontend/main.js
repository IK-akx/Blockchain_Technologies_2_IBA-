import { 
    GAME_ITEMS_ABI, 
    GAME_TOKEN_ABI, 
    LOOT_DROP_ABI, 
    ETH_AMM_ABI,
    RENTAL_VAULT_ABI,
    GOVERNOR_ABI
} from './abis.js';

const CONTRACTS = {
    GAME_ITEMS: import.meta.env.VITE_GAME_ITEMS,
    GAME_TOKEN: import.meta.env.VITE_GAME_TOKEN,
    LOOT_DROP: import.meta.env.VITE_LOOT_DROP,
    ETH_AMM: import.meta.env.VITE_ETH_AMM,
    RENTAL_VAULT: import.meta.env.VITE_RENTAL_VAULT,
    GOVERNOR: import.meta.env.VITE_GOVERNOR,
    TIMELOCK: import.meta.env.VITE_TIMELOCK
};

console.log('Addresses loaded:', CONTRACTS);

let provider, signer, userAddress;
let contracts = {};

const ITEM_NAMES = { 0: 'Wood', 1: 'Stone', 2: 'Iron', 3: 'Gold' };

const RENTABLE_ITEMS = {
    0: { name: 'Wood', pricePerDay: 1, power: 'Common' },
    4: { name: 'Legendary Sword', pricePerDay: 50, power: 'Legendary', description: '+100 Attack Power' },
    5: { name: 'Fireball Spell', pricePerDay: 10, power: 'Epic', description: 'Deals 50 damage' },
    6: { name: 'Dragon Armor', pricePerDay: 75, power: 'Legendary', description: '+200 Defense' },
    7: { name: 'Phoenix Feather', pricePerDay: 25, power: 'Epic', description: 'Revive once per battle' }
};

// Connect Wallet
document.getElementById('connectWallet').onclick = async () => {
    if (typeof window.ethereum !== 'undefined') {
        try {
            const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
            userAddress = accounts[0];
            provider = new ethers.BrowserProvider(window.ethereum);
            signer = await provider.getSigner();
            
            // Initialize contracts only if addresses exist
            if (CONTRACTS.GAME_TOKEN && CONTRACTS.GAME_TOKEN !== 'undefined') {
                contracts.token = new ethers.Contract(CONTRACTS.GAME_TOKEN, GAME_TOKEN_ABI, signer);
            }
            if (CONTRACTS.GAME_ITEMS && CONTRACTS.GAME_ITEMS !== 'undefined') {
                contracts.gameItems = new ethers.Contract(CONTRACTS.GAME_ITEMS, GAME_ITEMS_ABI, signer);
            }
            if (CONTRACTS.LOOT_DROP && CONTRACTS.LOOT_DROP !== 'undefined') {
                contracts.lootDrop = new ethers.Contract(CONTRACTS.LOOT_DROP, LOOT_DROP_ABI, signer);
            }
            if (CONTRACTS.ETH_AMM && CONTRACTS.ETH_AMM !== 'undefined') {
                contracts.amm = new ethers.Contract(CONTRACTS.ETH_AMM, ETH_AMM_ABI, signer);
            }
            if (CONTRACTS.RENTAL_VAULT && CONTRACTS.RENTAL_VAULT !== 'undefined') {
                contracts.vault = new ethers.Contract(CONTRACTS.RENTAL_VAULT, RENTAL_VAULT_ABI, signer);
            }
            if (CONTRACTS.GOVERNOR && CONTRACTS.GOVERNOR !== 'undefined') {
                contracts.governor = new ethers.Contract(CONTRACTS.GOVERNOR, GOVERNOR_ABI, signer);
            }
            
            document.getElementById('connectWallet').style.display = 'none';
            document.getElementById('walletInfo').style.display = 'block';
            document.getElementById('walletAddress').innerText = userAddress;
            
            await updateBalances();
            await loadInventory();
            await loadPoolStats();
            await loadVaultInfo();
            await loadGovernancePower();
            await loadProposals();
            await loadMyRentals();
            
            const network = await provider.getNetwork();
            const networkName = network.chainId === 11155111n ? 'Sepolia' : 'Unknown';
            const networkBadge = document.getElementById('networkBadge');
            if (networkBadge) {
                networkBadge.innerHTML = networkName;
                networkBadge.className = 'status-badge success';
            }
            
        } catch (error) {
            console.error(error);
            alert('Failed to connect: ' + error.message);
        }
    } else {
        alert('Please install MetaMask!');
    }
};

async function updateBalances() {
    if (!contracts.token) return;
    const eth = await provider.getBalance(userAddress);
    const ggt = await contracts.token.balanceOf(userAddress);
    const ethFormatted = Number(ethers.formatEther(eth)).toFixed(8);
    const ggtFormatted = Number(ethers.formatEther(ggt)).toFixed(4);
    const ethEl = document.getElementById('ethBalance');
    const ggtEl = document.getElementById('ggtBalance');
    if (ethEl) ethEl.innerHTML = `ETH: ${ethFormatted}`;
    if (ggtEl) ggtEl.innerHTML = `GGT: ${ggtFormatted}`;
}

async function loadInventory() {
    if (!userAddress || !contracts.gameItems) return;
    let html = '';
    for (const [id, name] of Object.entries(ITEM_NAMES)) {
        try {
            const balance = await contracts.gameItems.balanceOf(userAddress, id);
            if (balance > 0) {
                html += `<div class="inventory-item"><span>${name}</span><span>${balance.toString()}</span></div>`;
            }
        } catch(e) {}
    }
    for (const [id, item] of Object.entries(RENTABLE_ITEMS)) {
        if (id >= 4) {
            try {
                const balance = await contracts.gameItems.balanceOf(userAddress, id);
                if (balance > 0) {
                    html += `<div class="inventory-item"><span>${item.name}</span><span>${balance.toString()}</span></div>`;
                }
            } catch(e) {}
        }
    }
    const inventoryEl = document.getElementById('inventoryList');
    if (inventoryEl) inventoryEl.innerHTML = html || '<p>No items found</p>';
}

async function loadPoolStats() {
    if (!contracts.amm) return;
    try {
        const [reserveToken, reserveETH] = await contracts.amm.getReserves();
        const poolStatsEl = document.getElementById('poolStats');
        if (poolStatsEl) {
            poolStatsEl.innerHTML = `
                <p>GGT Reserve: ${ethers.formatEther(reserveToken)}</p>
                <p>ETH Reserve: ${ethers.formatEther(reserveETH)} ETH</p>
                <p style="color: #10b981;">Active</p>
            `;
        }
    } catch(e) {
        const poolStatsEl = document.getElementById('poolStats');
        if (poolStatsEl) poolStatsEl.innerHTML = '<p>Add liquidity first</p>';
    }
}

async function loadVaultInfo() {
    if (!contracts.vault) return;
    try {
        const totalAssets = await contracts.vault.totalAssets();
        const vaultInfoEl = document.getElementById('vaultInfo');
        if (vaultInfoEl) {
            vaultInfoEl.innerHTML = `
                <p>Total Assets: ${ethers.formatEther(totalAssets)} GGT</p>
                <p>APY: ~5%</p>
                <p>Yield accrues automatically</p>
            `;
        }
    } catch(e) {
        const vaultInfoEl = document.getElementById('vaultInfo');
        if (vaultInfoEl) vaultInfoEl.innerHTML = '<p>Vault ready</p>';
    }
}

async function loadGovernancePower() {
    if (!contracts.token || !userAddress) return;
    try {
        const votes = await contracts.token.getVotes(userAddress);
        const govPowerEl = document.getElementById('governancePower');
        if (govPowerEl) {
            govPowerEl.innerHTML = `Voting Power: ${ethers.formatEther(votes)} GGT`;
        }
    } catch(e) {
        console.error('Governance power error:', e);
    }
}

async function delegateVotes() {
    if (!contracts.token) {
        alert('Token contract not configured');
        return;
    }
    try {
        const tx = await contracts.token.delegate(userAddress);
        await tx.wait();
        alert('Votes delegated! Refresh to see your voting power.');
        await loadGovernancePower();
    } catch(e) {
        alert('Error delegating: ' + e.message);
    }
}

// Add delegate button manually
const delegateBtn = document.getElementById('delegateVotesBtn');
if (delegateBtn) {
    delegateBtn.onclick = delegateVotes;
}

// ============ GOVERNANCE PROPOSALS ============

async function loadProposals() {
    if (!contracts.governor) return;
    
    const proposalsDiv = document.getElementById('proposalsList');
    if (!proposalsDiv) return;
    proposalsDiv.innerHTML = '<p>Loading proposals...</p>';
    
    try {
        let proposalCount = 0;
        try {
            proposalCount = await contracts.governor.proposalCount();
            proposalCount = Number(proposalCount);
        } catch(e) {
            proposalCount = 0;
        }
        
        console.log('Proposal count:', proposalCount);
        
        if (proposalCount === 0) {
            proposalsDiv.innerHTML = '<p style="color: #aaa; text-align: center;">No proposals yet. Create one above!</p>';
            return;
        }
        
        let proposalsHtml = '';
        
        for (let i = proposalCount; i >= 1; i--) {
            try {
                const state = await contracts.governor.state(i);
                const stateNames = ['Pending', 'Active', 'Succeeded', 'Defeated', 'Queued', 'Executed', 'Canceled'];
                const stateColor = state === 1 ? '#f59e0b' : (state === 2 || state === 5 ? '#10b981' : (state === 3 ? '#ef4444' : '#6b7280'));
                
                let forVotes = 0, againstVotes = 0, abstainVotes = 0;
                try {
                    const votes = await contracts.governor.proposalVotes(i);
                    forVotes = parseFloat(ethers.formatEther(votes[1]));
                    againstVotes = parseFloat(ethers.formatEther(votes[0]));
                    abstainVotes = parseFloat(ethers.formatEther(votes[2]));
                } catch(e) {}
                
                proposalsHtml += `
                    <div style="background: rgba(0,0,0,0.2); border-radius: 12px; padding: 12px; margin-bottom: 12px;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                            <span style="font-weight: bold;">Proposal ${i}</span>
                            <span style="background: ${stateColor}; padding: 4px 12px; border-radius: 20px; font-size: 11px;">${stateNames[state] || 'Unknown'}</span>
                        </div>
                        <div style="display: flex; gap: 20px; font-size: 12px; margin-bottom: 10px;">
                            <span style="color: #10b981;">For: ${forVotes.toFixed(2)} GGT</span>
                            <span style="color: #ef4444;">Against: ${againstVotes.toFixed(2)} GGT</span>
                            <span style="color: #6b7280;">Abstain: ${abstainVotes.toFixed(2)} GGT</span>
                        </div>
                    </div>
                `;
            } catch(e) {}
        }
        
        proposalsDiv.innerHTML = proposalsHtml;
        
    } catch (error) {
        console.error('Error loading proposals:', error);
        proposalsDiv.innerHTML = '<p>Unable to load proposals</p>';
    }
}

// ============ EXCHANGE ============

let isBuyMode = true;

const buyModeBtn = document.getElementById('buyModeBtn');
const sellModeBtn = document.getElementById('sellModeBtn');
const buyMode = document.getElementById('buyMode');
const sellMode = document.getElementById('sellMode');

if (buyModeBtn && sellModeBtn) {
    buyModeBtn.onclick = () => {
        isBuyMode = true;
        buyModeBtn.style.background = '#e94560';
        sellModeBtn.style.background = 'rgba(255,255,255,0.1)';
        if (buyMode) buyMode.style.display = 'block';
        if (sellMode) sellMode.style.display = 'none';
    };

    sellModeBtn.onclick = () => {
        isBuyMode = false;
        sellModeBtn.style.background = '#e94560';
        buyModeBtn.style.background = 'rgba(255,255,255,0.1)';
        if (buyMode) buyMode.style.display = 'none';
        if (sellMode) sellMode.style.display = 'block';
    };
}

const exchangeAmount = document.getElementById('exchangeAmount');
if (exchangeAmount) {
    exchangeAmount.addEventListener('input', async () => {
        const amount = exchangeAmount.value;
        const estimatedOutput = document.getElementById('estimatedOutput');
        if (!amount || amount <= 0 || !contracts.amm) {
            if (estimatedOutput) estimatedOutput.innerText = '0';
            return;
        }
        try {
            const ethAmount = ethers.parseEther(amount);
            const output = await contracts.amm.getTokenOutForEthIn(ethAmount);
            if (estimatedOutput) estimatedOutput.innerText = ethers.formatEther(output);
        } catch(e) {
            if (estimatedOutput) estimatedOutput.innerText = '?';
        }
    });
}

const exchangeAmountSell = document.getElementById('exchangeAmountSell');
if (exchangeAmountSell) {
    exchangeAmountSell.addEventListener('input', async () => {
        const amount = exchangeAmountSell.value;
        const estimatedOutputSell = document.getElementById('estimatedOutputSell');
        if (!amount || amount <= 0 || !contracts.amm) {
            if (estimatedOutputSell) estimatedOutputSell.innerText = '0';
            return;
        }
        try {
            const tokenAmount = ethers.parseEther(amount);
            const output = await contracts.amm.getEthOutForTokenIn(tokenAmount);
            if (estimatedOutputSell) estimatedOutputSell.innerText = ethers.formatEther(output);
        } catch(e) {
            if (estimatedOutputSell) estimatedOutputSell.innerText = '?';
        }
    });
}

const executeExchangeBtn = document.getElementById('executeExchangeBtn');
if (executeExchangeBtn) {
    executeExchangeBtn.onclick = async () => {
        const amount = document.getElementById('exchangeAmount').value;
        if (!amount) { alert('Enter amount'); return; }
        
        const status = document.getElementById('exchangeStatus');
        if (status) {
            status.style.display = 'block';
            status.className = 'status info';
            status.innerHTML = 'Processing...';
        }
        
        try {
            const ethAmount = ethers.parseEther(amount);
            const tx = await contracts.amm.swapEthForToken(0, { value: ethAmount });
            await tx.wait();
            if (status) {
                status.className = 'status success';
                status.innerHTML = `Bought GGT with ${amount} ETH!`;
            }
            await updateBalances();
            await loadPoolStats();
            setTimeout(() => { if (status) status.style.display = 'none'; }, 3000);
        } catch (error) {
            if (status) {
                status.className = 'status error';
                status.innerHTML = error.message.slice(0, 100);
            }
        }
    };
}

const executeSellBtn = document.getElementById('executeSellBtn');
if (executeSellBtn) {
    executeSellBtn.onclick = async () => {
        const amount = document.getElementById('exchangeAmountSell').value;
        if (!amount) { alert('Enter amount'); return; }
        
        const status = document.getElementById('exchangeStatus');
        if (status) {
            status.style.display = 'block';
            status.className = 'status info';
            status.innerHTML = 'Processing...';
        }
        
        try {
            const tokenAmount = ethers.parseEther(amount);
            await contracts.token.approve(CONTRACTS.ETH_AMM, tokenAmount);
            const tx = await contracts.amm.swapTokenForEth(tokenAmount, 0);
            await tx.wait();
            if (status) {
                status.className = 'status success';
                status.innerHTML = `Sold ${amount} GGT for ETH!`;
            }
            await updateBalances();
            await loadPoolStats();
            setTimeout(() => { if (status) status.style.display = 'none'; }, 3000);
        } catch (error) {
            if (status) {
                status.className = 'status error';
                status.innerHTML = error.message.slice(0, 100);
            }
        }
    };
}

// ============ RENTAL FUNCTIONS ============

async function loadMyRentals() {
    if (!contracts.vault) return;
    
    const rentalsDiv = document.getElementById('myRentals');
    if (!rentalsDiv) return;
    rentalsDiv.innerHTML = '<p>Loading your rentals...</p>';
    
    let rentalsHtml = '<h4>Your Active Rentals:</h4>';
    let hasRentals = false;
    
    for (const [id, item] of Object.entries(RENTABLE_ITEMS)) {
        try {
            const rental = await contracts.vault.activeRentals(id, userAddress);
            if (rental && rental.expiry && Number(rental.expiry) > 0) {
                const expiryDate = new Date(Number(rental.expiry) * 1000);
                hasRentals = true;
                rentalsHtml += `
                    <div style="display: flex; justify-content: space-between; padding: 8px; border-bottom: 1px solid rgba(255,255,255,0.1);">
                        <span>${item.name}</span>
                        <span style="color: #10b981;">Expires: ${expiryDate.toLocaleString()}</span>
                    </div>
                `;
            }
        } catch(e) {}
    }
    
    if (!hasRentals) {
        rentalsHtml += '<p style="color: #aaa;">No active rentals. Rent an item above!</p>';
    }
    
    rentalsDiv.innerHTML = rentalsHtml;
}

const rentItemBtn = document.getElementById('rentItemBtn');
if (rentItemBtn) {
    rentItemBtn.onclick = async () => {
        const itemId = document.getElementById('rentItemId').value;
        const days = document.getElementById('rentDays').value;
        
        if (!itemId || !days) { 
            alert('Enter item ID and days'); 
            return;
        }
        
        if (days < 1 || days > 30) { 
            alert('Days must be between 1 and 30'); 
            return;
        }
        
        const status = document.getElementById('rentalStatus');
        if (status) {
            status.style.display = 'block';
            status.innerHTML = 'Processing rental...';
            status.className = 'status info';
        }
        
        try {
            const item = RENTABLE_ITEMS[itemId];
            if (!item) {
                throw new Error(`Item ID ${itemId} not found`);
            }
            
            const totalPrice = item.pricePerDay * days;
            const priceWei = ethers.parseEther(totalPrice.toString());
            
            const ggtBalance = await contracts.token.balanceOf(userAddress);
            if (ggtBalance < priceWei) {
                throw new Error(`Insufficient GGT. Need ${totalPrice} GGT`);
            }
            
            const approveTx = await contracts.token.approve(CONTRACTS.RENTAL_VAULT, priceWei);
            await approveTx.wait();
            
            const rentTx = await contracts.vault.rentItem(itemId, days);
            await rentTx.wait();
            
            if (status) {
                status.className = 'status success';
                status.innerHTML = `Rented ${item.name} for ${days} days! Cost: ${totalPrice} GGT`;
            }
            await updateBalances();
            await loadMyRentals();
            await loadInventory();
            
            setTimeout(() => { if (status) status.style.display = 'none'; }, 5000);
            
        } catch (error) {
            if (status) {
                status.className = 'status error';
                status.innerHTML = error.message.slice(0, 150);
            }
            console.error(error);
        }
    };
}

const checkRentalBtn = document.getElementById('checkRentalBtn');
if (checkRentalBtn) {
    checkRentalBtn.addEventListener('click', loadMyRentals);
}

// ============ VAULT FUNCTIONS ============

const depositVault = document.getElementById('depositVault');
if (depositVault) {
    depositVault.onclick = async () => {
        const amount = document.getElementById('vaultAmount').value;
        if (!amount) { alert('Enter amount'); return; }
        
        const status = document.getElementById('vaultStatus');
        if (status) {
            status.style.display = 'block';
            status.innerHTML = 'Depositing...';
            status.className = 'status info';
        }
        
        try {
            const tokenAmount = ethers.parseEther(amount);
            await contracts.token.approve(CONTRACTS.RENTAL_VAULT, tokenAmount);
            const tx = await contracts.vault.deposit(tokenAmount, userAddress);
            await tx.wait();
            if (status) {
                status.className = 'status success';
                status.innerHTML = 'Deposit successful! You now earn yield.';
            }
            await loadVaultInfo();
            await updateBalances();
            setTimeout(() => { if (status) status.style.display = 'none'; }, 3000);
        } catch (error) {
            if (status) {
                status.className = 'status error';
                status.innerHTML = error.message.slice(0, 100);
            }
        }
    };
}

const withdrawVault = document.getElementById('withdrawVault');
if (withdrawVault) {
    withdrawVault.onclick = async () => {
        const amount = document.getElementById('vaultAmount').value;
        if (!amount) { alert('Enter amount'); return; }
        
        const status = document.getElementById('vaultStatus');
        if (status) {
            status.style.display = 'block';
            status.innerHTML = 'Withdrawing...';
            status.className = 'status info';
        }
        
        try {
            const tokenAmount = ethers.parseEther(amount);
            const tx = await contracts.vault.withdraw(tokenAmount, userAddress, userAddress);
            await tx.wait();
            if (status) {
                status.className = 'status success';
                status.innerHTML = 'Withdrawal successful!';
            }
            await loadVaultInfo();
            await updateBalances();
            setTimeout(() => { if (status) status.style.display = 'none'; }, 3000);
        } catch (error) {
            if (status) {
                status.className = 'status error';
                status.innerHTML = error.message.slice(0, 100);
            }
        }
    };
}

// ============ PROPOSAL CREATE ============

const createProposalBtn = document.getElementById('createProposalBtn');
if (createProposalBtn) {
    createProposalBtn.onclick = async () => {
        if (!contracts.governor) {
            alert('Governor contract not configured');
            return;
        }
        
        if (!userAddress) {
            alert('Connect wallet first');
            return;
        }
        
        const description = prompt("Enter proposal description:", "Mint 1000 GGT to treasury");
        if (!description) return;
        
        const proposalsDiv = document.getElementById('proposalsList');
        if (proposalsDiv) proposalsDiv.innerHTML = '<p>Creating proposal...</p>';
        
        try {
            const targets = [CONTRACTS.GAME_TOKEN];
            const values = [0];
            const mintCalldata = "0x40c10f19" + 
                "000000000000000000000000" + userAddress.slice(2) + 
                "00000000000000000000000000000000000000000000003635c9adc5dea00000";
            
            const tx = await contracts.governor.propose(targets, values, [mintCalldata], description);
            await tx.wait();
            
            alert(`Proposal created!\n\n"${description}"\n\nTransaction: ${tx.hash}`);
            await loadProposals();
            
        } catch (error) {
            console.error('Proposal error:', error);
            alert('Error creating proposal: ' + error.message);
            if (proposalsDiv) proposalsDiv.innerHTML = '<p>Error creating proposal</p>';
        }
    };
}

// ============ LOOT BOX ============

const openLootBox = document.getElementById('openLootBox');
if (openLootBox) {
    openLootBox.onclick = async () => {
        if (!contracts.lootDrop) {
            alert('LootDrop contract not configured');
            return;
        }
        
        const status = document.getElementById('lootResult');
        if (status) {
            status.style.display = 'block';
            status.className = 'status info';
            status.innerHTML = 'Opening loot box...';
        }
        
        try {
            const price = ethers.parseEther("0.001");
            const tx = await contracts.lootDrop.requestLoot({ value: price });
            await tx.wait();
            if (status) {
                status.className = 'status success';
                status.innerHTML = 'Loot box opened! Check your inventory.';
            }
            await loadInventory();
            setTimeout(() => { if (status) status.style.display = 'none'; }, 5000);
        } catch (error) {
            console.error('Loot box error:', error);
            if (status) {
                status.className = 'status error';
                status.innerHTML = error.message.slice(0, 100);
            }
        }
    };
}

// ============ REFRESH ============

const refreshBtn = document.getElementById('refreshBtn');
if (refreshBtn) {
    refreshBtn.onclick = async () => {
        await loadInventory();
        await updateBalances();
        await loadPoolStats();
        await loadVaultInfo();
        await loadGovernancePower();
        await loadMyRentals();
    };
}

console.log('Frontend ready!');