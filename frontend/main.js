import { 
    GAME_ITEMS_ABI, 
    GAME_TOKEN_ABI, 
    LOOT_DROP_ABI, 
    ETH_AMM_ABI,
    RENTAL_VAULT_ABI,
    GOVERNOR_ABI
} from './abis.js';

// Get addresses from environment variables
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
            
            contracts.token = new ethers.Contract(CONTRACTS.GAME_TOKEN, GAME_TOKEN_ABI, signer);
            contracts.gameItems = new ethers.Contract(CONTRACTS.GAME_ITEMS, GAME_ITEMS_ABI, signer);
            contracts.lootDrop = new ethers.Contract(CONTRACTS.LOOT_DROP, LOOT_DROP_ABI, signer);
            contracts.amm = new ethers.Contract(CONTRACTS.ETH_AMM, ETH_AMM_ABI, signer);
            contracts.vault = new ethers.Contract(CONTRACTS.RENTAL_VAULT, RENTAL_VAULT_ABI, signer);
            contracts.governor = new ethers.Contract(CONTRACTS.GOVERNOR, GOVERNOR_ABI, signer);
            
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
            document.getElementById('networkBadge').innerHTML = networkName;
            document.getElementById('networkBadge').className = 'status-badge success';
            
        } catch (error) {
            console.error(error);
            alert('Failed to connect: ' + error.message);
        }
    } else {
        alert('Please install MetaMask!');
    }
};

async function updateBalances() {
    const eth = await provider.getBalance(userAddress);
    const ggt = await contracts.token.balanceOf(userAddress);
    document.getElementById('ethBalance').innerHTML = `ETH: ${ethers.formatEther(eth)}`;
    document.getElementById('ggtBalance').innerHTML = `GGT: ${ethers.formatEther(ggt)}`;
}

async function loadInventory() {
    if (!userAddress) return;
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
    document.getElementById('inventoryList').innerHTML = html || '<p>No items found</p>';
}

async function loadPoolStats() {
    if (!contracts.amm) return;
    try {
        const [reserveToken, reserveETH] = await contracts.amm.getReserves();
        document.getElementById('poolStats').innerHTML = `
            <p>GGT Reserve: ${ethers.formatEther(reserveToken)}</p>
            <p>ETH Reserve: ${ethers.formatEther(reserveETH)} ETH</p>
            <p style="color: #10b981;">Active</p>
        `;
    } catch(e) {
        document.getElementById('poolStats').innerHTML = '<p>Add liquidity first</p>';
    }
}

async function loadVaultInfo() {
    if (!contracts.vault) return;
    try {
        const totalAssets = await contracts.vault.totalAssets();
        document.getElementById('vaultInfo').innerHTML = `
            <p>Total Assets: ${ethers.formatEther(totalAssets)} GGT</p>
            <p>APY: ~5%</p>
            <p>Yield accrues automatically</p>
        `;
    } catch(e) {
        document.getElementById('vaultInfo').innerHTML = '<p>Vault ready</p>';
    }
}

async function loadGovernancePower() {
    if (!contracts.token || !userAddress) return;
    try {
        const votes = await contracts.token.getVotes(userAddress);
        const hasDelegated = await contracts.token.delegates(userAddress);
        document.getElementById('governancePower').innerHTML = `Voting Power: ${ethers.formatEther(votes)} GGT`;
        if (hasDelegated === '0x0000000000000000000000000000000000000000') {
            document.getElementById('governancePower').innerHTML += ` <button id="delegateBtn" style="padding: 4px 8px; font-size: 12px; background: #3b82f6;">Delegate</button>`;
            document.getElementById('delegateBtn')?.addEventListener('click', delegateVotes);
        }
    } catch(e) {
        console.error('Governance power error:', e);
    }
}

async function delegateVotes() {
    try {
        const tx = await contracts.token.delegate(userAddress);
        await tx.wait();
        alert('Votes delegated! Refresh to see your voting power.');
        await loadGovernancePower();
    } catch(e) {
        alert('Error delegating: ' + e.message);
    }
}

// ============ GOVERNANCE PROPOSALS ============
async function loadProposals() {
    if (!contracts.governor) return;
    
    const proposalsDiv = document.getElementById('proposalsList');
    proposalsDiv.innerHTML = '<p>Loading proposals...</p>';
    
    try {
        // Get proposal count
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
            document.getElementById('totalProposals').innerText = '0';
            return;
        }
        
        let proposalsHtml = '';
        let passedCount = 0;
        let failedCount = 0;
        let totalVotes = 0;
        
        // Get proposals from 1 to proposalCount
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
                    totalVotes += forVotes + againstVotes + abstainVotes;
                } catch(e) {}
                
                if (state === 2 || state === 5) passedCount++;
                if (state === 3) failedCount++;
                
                // Try to get description from the contract
                let description = `Proposal ${i}`;
                try {
                    const desc = await contracts.governor.getDescription(i);
                    if (desc && desc.length > 0) description = desc;
                } catch(e) {
                    // Fallback to event query
                    try {
                        const filter = contracts.governor.filters.ProposalCreated();
                        const events = await contracts.governor.queryFilter(filter, 0, 'latest');
                        for (const event of events) {
                            if (event.args && Number(event.args[0]) === i) {
                                description = event.args[7];
                                break;
                            }
                        }
                    } catch(e2) {}
                }
                
                if (description.length > 100) {
                    description = description.slice(0, 100) + '...';
                }
                
                proposalsHtml += `
                    <div style="background: rgba(0,0,0,0.2); border-radius: 12px; padding: 12px; margin-bottom: 12px;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                            <span style="font-weight: bold;">Proposal ${i}</span>
                            <span style="background: ${stateColor}; padding: 4px 12px; border-radius: 20px; font-size: 11px;">${stateNames[state] || 'Unknown'}</span>
                        </div>
                        <p style="font-size: 13px; background: rgba(0,0,0,0.3); padding: 10px; border-radius: 8px; margin-bottom: 8px; word-wrap: break-word;">
                            ${description}
                        </p>
                        <div style="display: flex; gap: 20px; font-size: 12px; margin-bottom: 10px;">
                            <span style="color: #10b981;">For: ${forVotes.toFixed(2)} GGT</span>
                            <span style="color: #ef4444;">Against: ${againstVotes.toFixed(2)} GGT</span>
                            <span style="color: #6b7280;">Abstain: ${abstainVotes.toFixed(2)} GGT</span>
                        </div>
                        ${state === 1 ? `<button class="voteBtn" data-proposal="${i}" style="padding: 6px 12px; font-size: 12px; width: 100%;">Vote FOR</button>` : ''}
                    </div>
                `;
            } catch(e) {
                console.log(`Proposal ${i} not found or error:`, e);
            }
        }
        
        proposalsDiv.innerHTML = proposalsHtml;
        
        // Update statistics
        document.getElementById('totalProposals').innerText = proposalCount;
        document.getElementById('passedProposals').innerText = passedCount;
        document.getElementById('failedProposals').innerText = failedCount;
        document.getElementById('totalVotes').innerText = totalVotes.toFixed(2);
        
        try {
            const quorum = await contracts.governor.quorum(await provider.getBlockNumber());
            document.getElementById('quorumRequired').innerText = parseFloat(ethers.formatEther(quorum)).toFixed(2);
        } catch(e) {
            document.getElementById('quorumRequired').innerText = '4% of supply';
        }
        
        // Attach vote event listeners
        document.querySelectorAll('.voteBtn').forEach(btn => {
            btn.removeEventListener('click', voteHandler);
            btn.addEventListener('click', voteHandler);
        });
        
    } catch (error) {
        console.error('Error loading proposals:', error);
        proposalsDiv.innerHTML = '<p>Unable to load proposals</p>';
    }
}

// Separate vote handler function
async function voteHandler(event) {
    const proposalId = event.target.dataset.proposal;
    await castVote(proposalId, 1);
}

// Update the proposal creation to refresh after a delay
document.getElementById('createProposalBtn').onclick = async () => {
    console.log('Create proposal button clicked');
    
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
    
    const status = document.getElementById('proposalsList');
    status.innerHTML = '<p>Creating proposal...</p>';
    
    try {
        const targets = [CONTRACTS.GAME_TOKEN];
        const values = [0];
        const mintCalldata = "0x40c10f19" + 
            "000000000000000000000000" + userAddress.slice(2) + 
            "00000000000000000000000000000000000000000000003635c9adc5dea00000";
        
        const tx = await contracts.governor.propose(targets, values, [mintCalldata], description);
        await tx.wait();
        
        alert(`Proposal created!\n\n"${description}"\n\nTransaction: ${tx.hash}`);
        
        // Wait a few seconds for the block to be processed
        status.innerHTML = '<p>Proposal created! Refreshing...</p>';
        await new Promise(resolve => setTimeout(resolve, 5000));
        
        await loadProposals();
        
    } catch (error) {
        console.error('Proposal error:', error);
        alert('Error creating proposal: ' + error.message);
        await loadProposals();
    }
};

async function castVote(proposalId, support) {
    if (!userAddress) {
        alert('Connect wallet first');
        return;
    }
    try {
        const votes = await contracts.token.getVotes(userAddress);
        if (votes === 0) {
            alert('You have no voting power! Delegate your GGT tokens first.');
            return;
        }
        const tx = await contracts.governor.castVote(proposalId, support);
        await tx.wait();
        alert(`Voted FOR on proposal ${proposalId}!`);
        await loadProposals();
        await loadGovernancePower();
    } catch (error) {
        alert('Error voting: ' + error.message);
    }
}

// ============ EXCHANGE ============

let isBuyMode = true;

document.getElementById('buyModeBtn').onclick = () => {
    isBuyMode = true;
    document.getElementById('buyModeBtn').style.background = '#e94560';
    document.getElementById('sellModeBtn').style.background = 'rgba(255,255,255,0.1)';
    document.getElementById('buyMode').style.display = 'block';
    document.getElementById('sellMode').style.display = 'none';
};

document.getElementById('sellModeBtn').onclick = () => {
    isBuyMode = false;
    document.getElementById('sellModeBtn').style.background = '#e94560';
    document.getElementById('buyModeBtn').style.background = 'rgba(255,255,255,0.1)';
    document.getElementById('buyMode').style.display = 'none';
    document.getElementById('sellMode').style.display = 'block';
};

document.getElementById('exchangeAmount')?.addEventListener('input', async () => {
    const amount = document.getElementById('exchangeAmount').value;
    if (!amount || amount <= 0 || !contracts.amm) {
        document.getElementById('estimatedOutput').innerText = '0';
        return;
    }
    try {
        const ethAmount = ethers.parseEther(amount);
        const output = await contracts.amm.getTokenOutForEthIn(ethAmount);
        document.getElementById('estimatedOutput').innerText = ethers.formatEther(output);
    } catch(e) {
        document.getElementById('estimatedOutput').innerText = '?';
    }
});

document.getElementById('exchangeAmountSell')?.addEventListener('input', async () => {
    const amount = document.getElementById('exchangeAmountSell').value;
    if (!amount || amount <= 0 || !contracts.amm) {
        document.getElementById('estimatedOutputSell').innerText = '0';
        return;
    }
    try {
        const tokenAmount = ethers.parseEther(amount);
        const output = await contracts.amm.getEthOutForTokenIn(tokenAmount);
        document.getElementById('estimatedOutputSell').innerText = ethers.formatEther(output);
    } catch(e) {
        document.getElementById('estimatedOutputSell').innerText = '?';
    }
});

document.getElementById('executeExchangeBtn').onclick = async () => {
    const amount = document.getElementById('exchangeAmount').value;
    if (!amount) { alert('Enter amount'); return; }
    
    const status = document.getElementById('exchangeStatus');
    status.style.display = 'block';
    status.className = 'status info';
    status.innerHTML = 'Processing...';
    
    try {
        const ethAmount = ethers.parseEther(amount);
        const tx = await contracts.amm.swapEthForToken(0, { value: ethAmount });
        await tx.wait();
        status.className = 'status success';
        status.innerHTML = `Bought GGT with ${amount} ETH!`;
        await updateBalances();
        await loadPoolStats();
        setTimeout(() => { status.style.display = 'none'; }, 3000);
    } catch (error) {
        status.className = 'status error';
        status.innerHTML = error.message.slice(0, 100);
    }
};

document.getElementById('executeSellBtn').onclick = async () => {
    const amount = document.getElementById('exchangeAmountSell').value;
    if (!amount) { alert('Enter amount'); return; }
    
    const status = document.getElementById('exchangeStatus');
    status.style.display = 'block';
    status.className = 'status info';
    status.innerHTML = 'Processing...';
    
    try {
        const tokenAmount = ethers.parseEther(amount);
        await contracts.token.approve(CONTRACTS.ETH_AMM, tokenAmount);
        const tx = await contracts.amm.swapTokenForEth(tokenAmount, 0);
        await tx.wait();
        status.className = 'status success';
        status.innerHTML = `Sold ${amount} GGT for ETH!`;
        await updateBalances();
        await loadPoolStats();
        setTimeout(() => { status.style.display = 'none'; }, 3000);
    } catch (error) {
        status.className = 'status error';
        status.innerHTML = error.message.slice(0, 100);
    }
};

// ============ RENTAL FUNCTIONS ============

async function loadMyRentals() {
    if (!contracts.vault) return;
    
    const rentalsDiv = document.getElementById('myRentals');
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

document.getElementById('rentItemBtn').onclick = async () => {
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
    status.style.display = 'block';
    status.innerHTML = 'Processing rental...';
    status.className = 'status info';
    
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
        
        status.className = 'status success';
        status.innerHTML = `Rented ${item.name} for ${days} days! Cost: ${totalPrice} GGT`;
        await updateBalances();
        await loadMyRentals();
        await loadInventory();
        
        setTimeout(() => { status.style.display = 'none'; }, 5000);
        
    } catch (error) {
        status.className = 'status error';
        status.innerHTML = error.message.slice(0, 150);
        console.error(error);
    }
};

document.getElementById('checkRentalBtn')?.addEventListener('click', loadMyRentals);

// ============ VAULT FUNCTIONS ============

document.getElementById('depositVault').onclick = async () => {
    const amount = document.getElementById('vaultAmount').value;
    if (!amount) { alert('Enter amount'); return; }
    
    const status = document.getElementById('vaultStatus');
    status.style.display = 'block';
    status.innerHTML = 'Depositing...';
    status.className = 'status info';
    
    try {
        const tokenAmount = ethers.parseEther(amount);
        await contracts.token.approve(CONTRACTS.RENTAL_VAULT, tokenAmount);
        const tx = await contracts.vault.deposit(tokenAmount, userAddress);
        await tx.wait();
        status.className = 'status success';
        status.innerHTML = 'Deposit successful! You now earn yield.';
        await loadVaultInfo();
        await updateBalances();
        setTimeout(() => { status.style.display = 'none'; }, 3000);
    } catch (error) {
        status.className = 'status error';
        status.innerHTML = error.message.slice(0, 100);
    }
};

document.getElementById('withdrawVault').onclick = async () => {
    const amount = document.getElementById('vaultAmount').value;
    if (!amount) { alert('Enter amount'); return; }
    
    const status = document.getElementById('vaultStatus');
    status.style.display = 'block';
    status.innerHTML = 'Withdrawing...';
    status.className = 'status info';
    
    try {
        const tokenAmount = ethers.parseEther(amount);
        const tx = await contracts.vault.withdraw(tokenAmount, userAddress, userAddress);
        await tx.wait();
        status.className = 'status success';
        status.innerHTML = 'Withdrawal successful!';
        await loadVaultInfo();
        await updateBalances();
        setTimeout(() => { status.style.display = 'none'; }, 3000);
    } catch (error) {
        status.className = 'status error';
        status.innerHTML = error.message.slice(0, 100);
    }
};

// ============ PROPOSAL CREATE ============

document.getElementById('createProposalBtn').onclick = async () => {
    console.log('Create proposal button clicked');
    
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
    
    const status = document.getElementById('proposalsList');
    status.innerHTML = '<p>Creating proposal...</p>';
    
    try {
        const targets = [CONTRACTS.GAME_TOKEN];
        const values = [0];
        const mintCalldata = "0x40c10f19" + 
            "000000000000000000000000" + userAddress.slice(2) + 
            "00000000000000000000000000000000000000000000003635c9adc5dea00000";
        
        console.log('Creating proposal...');
        const tx = await contracts.governor.propose(targets, values, [mintCalldata], description);
        await tx.wait();
        
        alert(`Proposal created!\n\n"${description}"\n\nTransaction: ${tx.hash}`);
        await loadProposals();
        
    } catch (error) {
        console.error('Proposal error:', error);
        alert('Error creating proposal: ' + error.message);
        await loadProposals();
    }
};

// ============ LOOT BOX ============

document.getElementById('openLootBox').onclick = async () => {
    const status = document.getElementById('lootResult');
    status.style.display = 'block';
    status.className = 'status info';
    status.innerHTML = 'Opening loot box...';
    
    try {
        const price = ethers.parseEther("0.001");
        const tx = await contracts.lootDrop.requestLoot({ value: price });
        await tx.wait();
        status.className = 'status success';
        status.innerHTML = 'Loot box opened! Check your inventory.';
        await loadInventory();
        setTimeout(() => { status.style.display = 'none'; }, 5000);
    } catch (error) {
        status.className = 'status error';
        status.innerHTML = error.message.slice(0, 100);
    }
};

// ============ REFRESH ============

document.getElementById('refreshBtn').onclick = async () => {
    await loadInventory();
    await updateBalances();
    await loadPoolStats();
    await loadVaultInfo();
    await loadGovernancePower();
    await loadMyRentals();
};

console.log('Frontend ready!');