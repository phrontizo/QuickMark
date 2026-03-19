(function() {
  var code = document.querySelector('code');
  if (!code) return;
  var lang = (code.className.match(/language-(\w+)/) || [])[1] || '';
  var highlighted = code.innerHTML;
  try {
    if (typeof hljs !== 'undefined' && lang) {
      highlighted = hljs.highlight(code.textContent, {language: lang}).value;
    }
  } catch(e) {}
  var lines = highlighted.split('\n');
  if (lines.length > 0 && lines[lines.length - 1] === '') lines.pop();
  code.innerHTML = lines.map(function(line, i) {
    return '<span class="line"><span class="line-number">' + (i + 1) + '</span>' + line + '</span>';
  }).join('');
  code.classList.add('hljs');
  code.setAttribute('data-highlighted', 'yes');
})();
