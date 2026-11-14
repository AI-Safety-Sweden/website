// Netlify injects its "Powered by Netlify" badge as an iframe appended to <body>. Remove it.
(function () {
  function removeBadge() {
    var frame = document.getElementById("nl-badge-frame");
    if (frame) frame.remove();
  }

  removeBadge();
  new MutationObserver(removeBadge).observe(document.documentElement, { childList: true, subtree: true });
})();
