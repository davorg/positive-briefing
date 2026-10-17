(() => {
  if (!["positivitybriefing.com", "www.positivitybriefing.com"].includes(window.location.hostname)) {
    return;
  }

  window.dataLayer = window.dataLayer || [];
  window.gtag = function () { window.dataLayer.push(arguments); };
  window.gtag("js", new Date());
  window.gtag("config", "G-L866B8F7YN");

  const script = document.createElement("script");
  script.async = true;
  script.src = "https://www.googletagmanager.com/gtag/js?id=G-L866B8F7YN";
  document.head.appendChild(script);
})();
