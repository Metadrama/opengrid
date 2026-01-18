
import { connect } from "npm:@permaweb/aoconnect";

console.log("--------------------------------");
console.log("Testing AO Connection...");

const ao = connect({
    MU_URL: "http://127.0.0.1:4002",
    CU_URL: "http://127.0.0.1:4004",
    GATEWAY_URL: "http://127.0.0.1:4000",
});

async function test() {
    try {
        console.log("Connect object created.");
        // Just try to get something simple, e.g. dryrun a fake message
        // Note: dryrun usually requires a process ID on real network, 
        // but on local WAO it checks if process exists first? 
        // Let's try to 'spawn' quickly.

        console.log("Attempting spawn...");
        const pid = await ao.spawn({
            module: "test",
            scheduler: "test",
            tags: [{ name: "Test", value: "1" }]
        });
        console.log("Spawn success! PID:", pid);

    } catch (e) {
        console.error("Test Failed:", e);
    }
}

test();
