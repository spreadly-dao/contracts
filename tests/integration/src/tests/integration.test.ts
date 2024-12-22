import { getFullnodeUrl, SuiClient } from '@mysten/sui.js/client';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { describe, it, before } from 'mocha';
import assert from 'assert';
import fs from 'fs/promises';
import path from 'path';
import { execSync } from 'child_process';

interface TokenConfig {
    name: string;
    symbol: string;
    decimals: number;
    description: string;
    iconUrl?: string;
}

class TokenFactory {
    private client: SuiClient;
    private keypair: Ed25519Keypair;
    private readonly tempDir: string;

    constructor(client: SuiClient, keypair: Ed25519Keypair) {
        this.client = client;
        this.keypair = keypair;
        this.tempDir = path.join(__dirname, 'temp_contracts');
    }

    private async generateMoveToml(moduleName: string): Promise<string> {
        return `
            [package]
            name = "${moduleName}"
            version = "0.0.1"

            [dependencies]
            Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "devnet" }

            [addresses]
            ${moduleName} = "0x0"`;
    }

    private async generateTokenModule(config: TokenConfig, moduleName: string): Promise<string> {
        return `
            #[allow(unused_use)]
            module ${moduleName}::token {
                use std::option;
                use sui::coin::{Self, TreasuryCap, CoinMetadata};
                use sui::transfer;
                use sui::tx_context::{Self, TxContext};

                /// The type identifier of coin. The coin will have a type
                /// tag of format: {PACKAGE_ID}::token::TOKEN
                struct TOKEN has drop {}

                /// Module initializer is called once on module publish. A treasury
                /// cap and metadata for the coin will be created.
                fun init(witness: TOKEN, ctx: &mut TxContext) {
                    let (treasury_cap, metadata) = coin::create_currency<TOKEN>(
                        witness, 
                        ${config.decimals},
                        b"${config.symbol}",
                        b"${config.name}",
                        b"${config.description}",
                        ${config.iconUrl ? `option::some(b"${config.iconUrl}")` : 'option::none()'},
                        ctx
                    );
                    let initial_supply = coin::mint(&mut treasury_cap, 1_000_000_000_000_000, ctx);
        
                    // Transfer initial supply to deployer
                    transfer::public_transfer(initial_supply, tx_context::sender(ctx));
                    // Transfer the treasury cap to the module publisher
                    transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
                    // Make the metadata public
                    transfer::public_share_object(metadata);
                }

                /// Manager can mint new coins
                public entry fun mint(
                    treasury_cap: &mut TreasuryCap<TOKEN>,
                    amount: u64,
                    recipient: address,
                    ctx: &mut TxContext
                ) {
                    let coin = coin::mint(treasury_cap, amount, ctx);
                    transfer::public_transfer(coin, recipient);
                }

                /// Manager can burn coins
                public entry fun burn(
                    treasury_cap: &mut TreasuryCap<TOKEN>,
                    coin: coin::Coin<TOKEN>
                ) {
                    coin::burn(treasury_cap, coin);
                }
            }`;
    }

    private async setupTempDir(dirPath: string): Promise<void> {
        await fs.mkdir(dirPath, { recursive: true });
        await fs.mkdir(path.join(dirPath, 'sources'), { recursive: true });
    }

    private async cleanupTempDir(dirPath: string): Promise<void> {
        await fs.rm(dirPath, { recursive: true, force: true });
    }

    public async deployToken(config: TokenConfig): Promise<{
        packageId: string;
    }> {
        try {
            const moduleName = `token_${config.symbol.toLowerCase()}`;
            const contractDir = path.join(this.tempDir, moduleName);

            // Setup directory
            await this.setupTempDir(contractDir);

            // Generate and write files
            const moveToml = await this.generateMoveToml(moduleName);
            const moduleContent = await this.generateTokenModule(config, moduleName);

            await fs.writeFile(path.join(contractDir, 'Move.toml'), moveToml);
            await fs.writeFile(
                path.join(contractDir, 'sources', 'token.move'),
                moduleContent
            );

            // Build the package
            execSync('sui move build', { cwd: contractDir });

            // Read the compiled package
            const compiledBytes = await fs.readFile(
                path.join(contractDir, 'build', moduleName, 'bytecode_modules', 'token.mv')
            );


            // Create deployment transaction
            const tx = new TransactionBlock();
            const [upgradeCap] = tx.publish({
                modules: [Array.from(compiledBytes)],
                dependencies: ["0x1", "0x2"],
            });
            tx.transferObjects([upgradeCap], tx.pure(this.keypair.getPublicKey().toSuiAddress()));

            // Execute transaction
            const result = await this.client.signAndExecuteTransactionBlock({
                signer: this.keypair,
                transactionBlock: tx,
                options: {
                    showEffects: true,
                    showEvents: true,
                    showObjectChanges: true,
                }
            });

            // Parse results
            const packageId = result.effects?.created?.find(
                obj => obj.owner === 'Immutable'
            )?.reference.objectId;

            if (!packageId) {
                throw new Error('Failed to extract package ID from transaction');
            }

            // Cleanup
            await this.cleanupTempDir(contractDir);

            return {
                packageId,
            };

        } catch (error) {
            console.error('Error deploying token:', error);
            throw error;
        }
    }
}

describe('Token Factory Integration Tests', function() {
    this.timeout(30000); // Set timeout for the entire test suite
    
    let client: SuiClient;
    let keypair: Ed25519Keypair;
    let factory: TokenFactory;

    before(async function() {
        // Initialize client with your network
        client = new SuiClient({ url: getFullnodeUrl('devnet') });
        
        // Initialize keypair - replace with your own seed phrase
        keypair = Ed25519Keypair.deriveKeypair("question parrot unable timber blossom hamster erase ten vehicle buzz perfect judge");
        
        factory = new TokenFactory(client, keypair);
    });

    it('should deploy a new token', async function() {
        const tokenConfig: TokenConfig = {
            name: "Test Token",
            symbol: "TEST",
            decimals: 9,
            description: "A test token for testing",
        };

        const result = await factory.deployToken(tokenConfig);
        assert(result.packageId, 'Package ID should be defined');
        console.log('Deployed package ID:', result.packageId);
    });
});