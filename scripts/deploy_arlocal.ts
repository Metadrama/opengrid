import { connect, createDataItemSigner } from "npm:@permaweb/aoconnect";
import Arweave from "npm:arweave@1.15.1";
import { readFileSync, writeFileSync, existsSync } from "node:fs";

// Initialize Arweave for wallet generation
const arweave = Arweave.init({
    host: 'localhost',
    port: 1984,
    protocol: 'http'
});

// Load or generate wallet
let wallet;
const walletPath = "arlocal_wallet.json";

if (existsSync(walletPath)) {
    console.log("📂 Loading existing wallet...");
    wallet = JSON.parse(readFileSync(walletPath, "utf-8"));
} else {
    console.log("🔑 Generating new wallet for ArLocal...");
    wallet = await arweave.wallets.generate();
    writeFileSync(walletPath, JSON.stringify(wallet, null, 2));
    console.log("✅ Wallet saved to arlocal_wallet.json");
}

// Connect to ArLocal (local AO environment)
const ao = connect({
    MU_URL: "http://localhost:4002",
    CU_URL: "http://localhost:4004",
    GATEWAY_URL: "http://localhost:1984", // ArLocal gateway
});

console.log("🏠 Connected to ArLocal");

// Load Lua code
const worldManagerLua = readFileSync("ao/world_manager.lua", "utf-8");
const salesmanLua = readFileSync("ao/salesman.lua", "utf-8");

// Helper to spawn and load process
async function deployProcess(name: string, luaCode: string) {
    console.log(`\n🚀 Deploying ${name}...`);

    try {
        // 1. Spawn the process
        const processId = await ao.spawn({
            module: "SBNb1qPhhHYNp99PaGGWOWTbO1-BcSpanfcq5j4Hj3w", // Standard AO module
            scheduler: "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA", // Standard scheduler
            tags: [
                { name: "App-Name", value: "OpenGrid" },
                { name: "Name", value: name }
            ],
            signer: createDataItemSigner(wallet)
        });

        console.log(`✅ Process spawned: ${processId}`);

        // 2. Load Lua code via Eval
        console.log(`📜 Loading Lua code...`);
        await ao.message({
            process: processId,
            tags: [{ name: "Action", value: "Eval" }],
            data: luaCode,
            signer: createDataItemSigner(wallet)
        });

        console.log(`✅ ${name} deployed successfully!`);
        return processId;

    } catch (error) {
        console.error(`❌ Failed to deploy ${name}:`, error);
        throw error;
    }
}

async function main() {
    try {
        console.log("\n╔══════════════════════════════════════╗");
        console.log("║  OpenGrid ArLocal Deployment        ║");
        console.log("╚══════════════════════════════════════╝\n");

        // Deploy World Manager
        const wmPid = await deployProcess("WorldManager", worldManagerLua);

        // Deploy 3 Salesmen
        const s1Pid = await deployProcess("Salesman-Red", salesmanLua);
        const s2Pid = await deployProcess("Salesman-Green", salesmanLua);
        const s3Pid = await deployProcess("Salesman-Blue", salesmanLua);

        // Save configuration
        const config = {
            network: "arlocal",
            worldManager: wmPid,
            salesmen: [
                { id: s1Pid, name: "Red", color: 0xFF0055 },
                { id: s2Pid, name: "Green", color: 0x00FF88 },
                { id: s3Pid, name: "Blue", color: 0x00AAdd }
            ],
            endpoints: {
                mu: "http://localhost:4002",
                cu: "http://localhost:4004",
                gateway: "http://localhost:1984"
            }
        };

        writeFileSync("ao_config.json", JSON.stringify(config, null, 2));
        console.log("\n💾 Configuration saved to ao_config.json");

        // Register salesmen with World Manager
        console.log("\n🔗 Registering salesmen...");
        for (const salesman of config.salesmen) {
            await ao.message({
                process: salesman.id,
                tags: [
                    { name: "Action", value: "Eval" }
                ],
                data: `ao.send({ Target = "${wmPid}", Action = "Register" })`,
                signer: createDataItemSigner(wallet)
            });
            console.log(`  ✅ ${salesman.name} registered`);
        }

        console.log("\n╔══════════════════════════════════════╗");
        console.log("║  ✨ Deployment Complete!            ║");
        console.log("╚══════════════════════════════════════╝");
        console.log(`\n📋 World Manager: ${wmPid}`);
        console.log(`📋 Salesmen: ${config.salesmen.length} agents deployed`);
        console.log(`\n🎮 Next: Update Flutter client to use ao_config.json\n`);

    } catch (error) {
        console.error("\n💥 Deployment failed:", error);
        Deno.exit(1);
    }
}

main();
