(function() {
  window.addEventListener('DOMContentLoaded', () => {
    function setupCheckButton(h1) {
      const btn = document.createElement('span');
      btn.className = 'arxiv-check';
      btn.innerHTML = '★';
      btn.id = h1.id.replace(/^arxiv/, 'btn');
      btn.arxivTitleElement = h1;

      var checked = 0;
      btn.addEventListener('click', () => {
        checked = (checked + 1) % 3;
        switch (checked) {
        case 0:
          btn.classList.remove('arxiv-check--checked', 'arxiv-check--important');
          break;
        case 1:
          btn.classList.add('arxiv-check--checked');
          break;
        case 2:
          btn.classList.add('arxiv-check--important');
          break;
        }
        updateMarkdown();
      });

      h1.insertAdjacentElement('AfterBegin', btn);
    }

    const elems = document.querySelectorAll('h2.title');
    for (var i = 0; i < elems.length; i++) {
      setupCheckButton(elems[i]);
    }

    var pre = document.createElement("pre");
    pre.className = 'arxiv-markdown';
    document.body.appendChild(pre);
    function updateMarkdown() {
      const buff = [];

      // 日付
      var m = document.title.match(/\b(20[0-9]{2})([0-9]{2})([0-9]{2})\b/);
      if (m) buff.push('### ', m[1], '-', m[2], '-', m[3], '\n');

      const buttons = document.querySelectorAll('span.arxiv-check');
      for (var i = 0; i < buttons.length; i++) {
        const btn = buttons[i];
        if (!btn.classList.contains('arxiv-check--checked')) continue;
        const arxivId = btn.id.replace(/^btn\./, "");

        var title = btn.arxivTitleElement.innerText;
        const index = title.indexOf(": ");
        if (index >= 0) title = title.slice(index + 1).trim();
        title = title.replace(/[ \t\n]+/g, " ");
        if (btn.classList.contains('arxiv-check--important'))
          title = '★' + title;

        var url = 'https://arxiv.org/abs/' + arxivId;

        buff.push('- [arXiv:', arxivId, '](', url, '): ', title, '\n');
      }
      pre.textContent = buff.join("");
    }

  });
})();
