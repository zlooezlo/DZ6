const appConfig = window.APP_CONFIG ?? {};
const apiBaseUrl = (appConfig.apiBaseUrl ?? "/api").replace(/\/$/, "");

document.querySelector("#frontend-version").textContent =
    appConfig.frontendVersion ?? "v1";

async function loadBackendInfo() {
    const errorElement = document.querySelector("#error");
    errorElement.textContent = "";

    const response = await fetch(`${apiBaseUrl}/visits`, {
        headers: { Accept: "application/json" },
        cache: "no-store",
    });

    if (!response.ok) {
        throw new Error(`Backend returned ${response.status}`);
    }

    const data = await response.json();

    document.querySelector("#backend-version").textContent =
        data.version ?? "unknown";

    document.querySelector("#backend-pod").textContent =
        data.pod ?? "unknown";

    document.querySelector("#visits").textContent =
        data.total ?? "unknown";
}

document.querySelector("#refresh").addEventListener("click", () => {
    loadBackendInfo().catch((error) => {
        console.error(error);
        document.querySelector("#backend-version").textContent = "ошибка";
        document.querySelector("#error").textContent =
            "Backend временно недоступен";
    });
});

loadBackendInfo().catch((error) => {
    console.error(error);
    document.querySelector("#backend-version").textContent = "ошибка";
    document.querySelector("#error").textContent =
        "Backend временно недоступен";
});
