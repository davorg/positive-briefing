function titleCase(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

const backgrounds = [
  {
    file: "ocean-sunset.jpg",
    photographer: "Anna Khmel",
    source: "https://unsplash.com/photos/4wEka_nkQZ0",
  },
  {
    file: "rolling-hills.jpg",
    photographer: "Zetong Li",
    source: "https://unsplash.com/photos/2XpVkLppH_o",
  },
  {
    file: "mountain-lake.jpg",
    photographer: "Guillaume Briard",
    source: "https://unsplash.com/photos/5mmngbWIflg",
  },
  {
    file: "snowy-mountains.jpg",
    photographer: "Darien Attridge",
    source: "https://unsplash.com/photos/tcG4KrYaC5U",
  },
];

function setDailyBackground(d = new Date()) {
  // UTC days provide a stable daily rotation across time zones and DST changes.
  const day = Math.floor(d.getTime() / 86_400_000);
  const background = backgrounds[day % backgrounds.length];
  const url = `images/backgrounds/${background.file}`;

  // Keep the CSS sunset and its credit until today's photo has loaded.
  const img = new Image();
  img.onload = () => {
    document.body.style.backgroundImage = `url("${url}")`;
    const credit = document.getElementById("background-credit");
    credit.textContent = `Photo by ${background.photographer} on Unsplash`;
    credit.href = background.source;
  };
  img.onerror = () => {
    console.warn("Background image failed to load:", url);
  };
  img.src = url;
}

function render(items) {
  const content = document.getElementById("content");
  content.innerHTML = "";

  const iconPaths = {
    useful: "M12 2v20M2 12h20M5 5l14 14M5 19L19 5",
    hopeful: "M2 20h20M6 20a6 6 0 0 1 12 0M12 2v4M3 7l3 3M21 7l-3 3",
    action: "M5 19L19 5M5 5h14v14",
  };

  for (const [index, item] of items.entries()) {
    const div = document.createElement("article");
    div.className = "point";

    const heading = document.createElement("div");
    heading.className = "point-heading";

    const icon = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    icon.setAttribute("class", "point-icon");
    icon.setAttribute("viewBox", "0 0 24 24");
    icon.setAttribute("fill", "none");
    icon.setAttribute("stroke", "currentColor");
    icon.setAttribute("stroke-width", "1.4");
    icon.setAttribute("aria-hidden", "true");
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    path.setAttribute("d", iconPaths[item.type] || iconPaths.useful);
    icon.appendChild(path);

    const label = document.createElement("h2");
    label.className = "label";
    label.textContent = titleCase(item.type);

    const number = document.createElement("span");
    number.className = "point-number";
    number.textContent = String(index + 1).padStart(2, "0");
    number.setAttribute("aria-hidden", "true");

    const text = document.createElement("p");
    text.className = "point-text";
    text.textContent = item.text;

    heading.append(icon, label, number);
    div.appendChild(heading);
    div.appendChild(text);
    content.appendChild(div);
  }
  content.setAttribute("aria-busy", "false");
}

async function main() {
  setDailyBackground();

  const meta = document.getElementById("meta");
  meta.textContent = `Updated daily`;
  document.getElementById("edition-date").textContent = new Intl.DateTimeFormat("en-GB", {
    weekday: "long", day: "numeric", month: "long",
  }).format(new Date());

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
    content.setAttribute("aria-busy", "false");
    // Leave background in place even on error
  }
}

main();
