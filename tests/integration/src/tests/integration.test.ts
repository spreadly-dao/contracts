import { getFullnodeUrl, SuiClient } from '@mysten/sui.js/client';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { describe, it, before } from 'mocha';
import assert from 'assert';

describe('Sui Contract Integration Tests', () => {
    let client: SuiClient;
    let keypair: Ed25519Keypair;

    before(async () => {
        // Initialize the Sui client (using testnet)
        client = new SuiClient({ url: getFullnodeUrl('testnet') });
        
        // Create a new keypair for testing
        keypair = new Ed25519Keypair();
    });

    it('should connect to the network', async () => {
        const objects = await client.getAllCoins({
            owner: keypair.getPublicKey().toSuiAddress(),
        });
        assert(objects !== undefined);
    });
});