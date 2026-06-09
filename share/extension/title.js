// Shorten the window title: "Microsoft Teams" → "Teams".
// Notification counts are preserved, e.g. "(3) Microsoft Teams" → "(3) Teams".
function trimTitle() {
  const next = document.title.replace(/\bMicrosoft Teams\b/g, 'Teams');
  if (next !== document.title) document.title = next;
}

new MutationObserver(trimTitle)
  .observe(document.documentElement, { subtree: true, childList: true });

trimTitle();
