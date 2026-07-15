async function loadBackendInfo() {
    const response = await fetch("/api/visits");

    if (!response.ok) {
        throw new Error(`Backend returned ${response.status}`);
    }

    const data = await response.json();

    document.querySelector("#backend-version").textContent =
        data.version ?? "unknown";

    document.querySelector("#backend-pod").textContent =
        data.pod ?? "unknown";

    document.querySelector("#visits").textContent =
        data.visits ?? "unknown";
}

document.querySelector("#refresh").addEventListener("click", () => {
    loadBackendInfo().catch((error) => {
        console.error(error);
        document.querySelector("#backend-version").textContent = "ошибка";
    });
});

loadBackendInfo().catch(console.error);