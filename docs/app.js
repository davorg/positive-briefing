function titleCase(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function yyyymmddUTC(d = new Date()) {
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${yyyy}${mm}${dd}`;
}

function setDailyBackground() {
  const sig = yyyymmddUTC();

  // More reliable Unsplash Source format:
  const url = `https://source.unsplash.com/1920x1080/?sunrise&sig=${sig}`;

  // Preload so failures are visible and we only set it when loaded.
  const img = new Image();
  img.onload = () => {
    document.body.style.backgroundImage = `url("${url}")`;
  };
  img.onerror = () => {
    console.warn("Background image failed to load:", url);
  };
  img.src = url;
}

function render(items) {
  const content = document.getElementById("content");
  content.innerHTML = "";

  for (const item of items) {
    const div = document.createElement("div");
    div.className = "point";

    const label = document.createElement("div");
    label.className = "label";
    label.textContent = titleCase(item.type);

    const text = document.createElement("div");
    text.textContent = item.text;

    div.appendChild(label);
    div.appendChild(text);
    content.appendChild(div);
  }
}

async function main() {
  setDailyBackground();

  const meta = document.getElementById("meta");
  meta.textContent = `Updated daily`;

  try {
    const res = await fetch("briefing.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const items = await res.json();

    if (!Array.isArray(items) || items.length !== 3) {
      throw new Error("Unexpected briefing format");
    }

    render(items);
  } catch (e) {
    const content = document.getElementById("content");
    content.innerHTML = `<p class="error">Couldn’t load today’s briefing. Try refreshing.</p>`;
    // Leave background in place even on error
  }
}

main();
