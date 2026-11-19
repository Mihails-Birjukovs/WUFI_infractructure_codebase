// Pinned MathJax 3.2.2; page-local automatic equation numbering.
window.MathJax = {
  tex: {
    inlineMath: [["\\(", "\\)"]],
    displayMath: [["\\[", "\\]"]],
    processEscapes: true,
    processEnvironments: true,
    tags: "all",
    tagSide: "right",
    useLabelIds: true
  },
  options: {
    ignoreHtmlClass: ".*|",
    processHtmlClass: "arithmatex"
  }
};
// Zensical instant navigation: clear prior page's labels and re-typeset.
if (typeof document$ !== "undefined") {
  document$.subscribe(() => {
    if (!window.MathJax || !MathJax.typesetPromise) return;
    MathJax.startup.output.clearCache();
    MathJax.typesetClear();
    MathJax.texReset();
    MathJax.typesetPromise();
  });
}
