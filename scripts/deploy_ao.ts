
import { connect, createDataItemSigner } from "npm:@permaweb/aoconnect";
import { readFileSync, writeFileSync } from "node:fs";

// Connect to Local WAO
// Note: For real network, remove the module config
const ao = connect({
    MU_URL: "http://localhost:4002",
    CU_URL: "http://localhost:4004",
    GATEWAY_URL: "http://localhost:4000",
});

// Load Lua Code
const worldManagerLua = readFileSync("ao/world_manager.lua", "utf-8");
const salesmanLua = readFileSync("ao/salesman.lua", "utf-8");

// Helper to spawn process
async function spawnProcess(name: string, luaCode: string) {
    console.log(`🚀 Spawning ${name}...`);
    try {
        // 1. Spawn Process
        const result = await ao.spawn({
            module: "Approved-Module", // Placeholder for local WAO
            scheduler: "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA", // Standard Scheduler
            tags: [
                { name: "App-Name", value: "OpenGrid-Salesman" },
                { name: "Name", value: name },
                { name: "Description", value: `OpenGrid ${name}` }
            ],
            signer: createDataItemSigner(globalThis.crypto) // Use ephemeral signer
        });

        const pid = result;
        console.log(`✅ ${name} Spawned: ${pid}`);

        // 2. Load Lua Code (Eval)
        console.log(`📜 Loading Lua code into ${pid}...`);
        const evalId = await ao.message({
            process: pid,
            tags: [{ name: "Action", value: "Eval" }],
            data: luaCode,
            signer: createDataItemSigner(globalThis.crypto)
        });

        return pid;
    } catch (e) {
        console.error(`❌ Failed to spawn ${name}:`, e);
        throw e;
    }
}

async function main() {
    try {
        const wmPid = await spawnProcess("WorldManager", worldManagerLua);
        const s1Pid = await spawnProcess("Salesman-1", salesmanLua);
        const s2Pid = await spawnProcess("Salesman-2", salesmanLua);
        const s3Pid = await spawnProcess("Salesman-3", salesmanLua);

        // Config to save
        const config = {
            worldManager: wmPid,
            salesmen: [s1Pid, s2Pid, s3Pid]
        };

        writeFileSync("server/ao_config.json", JSON.stringify(config, null, 2));
        console.log("💾 Config saved to server/ao_config.json");

        // Register Salesmen with WorldManager
        console.log("🔗 Registering salesmen...");
        for (const sPid of config.salesmen) {
            await ao.message({
                process: wmPid,
                tags: [{ name: "Action", value: "Register" }],
                // Data usually contains more info, but Register handler checks msg.From
                // But we need to pretend the message comes FROM the salesman? 
                // No, 'ao.message' sends from OUR wallet (the deployer).
                // The WorldManager registers msg.From.
                // So this registers THE DEPLOYER as a salesman? 
                // YES. This logic is flawed for external processes.
                // The Salesman process itself should send the 'Register' message to WM.
                signer: createDataItemSigner(globalThis.crypto)
            });
        }

        // Fix: We need to tell the Salesman process to register itself!
        console.log("🤖 Commanding salesmen to register self...");
        for (const sPid of config.salesmen) {
            // Send a custom eval to make it send a message
            const registerLua = `
          ao.send({
            Target = "${wmPid}",
            Action = "Register"
          })
        `;
            await ao.message({
                process: sPid,
                tags: [{ name: "Action", value: "Eval" }],
                data: registerLua,
                signer: createDataItemSigner(globalThis.crypto)
            });
        }

        console.log("✨ Deployment Complete!");
    } catch (e) {
        console.error("Critical Failure:", e);
    }
}

main();
