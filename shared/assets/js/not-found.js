// The not-found page's script, every site's (loaded by the shared text,
// shared/_includes/not-found.html, which each site's 404.html includes; the
// bucket serves that page for an address with nothing behind it): shows the
// address that was asked for, which the static page cannot know itself, and
// puts it in the links that can use it: the Wayback Machine's latest copy of
// it, and the report's subject and body, with the page that linked here where
// the browser says. The include names its site, and the address to report
// to, in the script tag:
//
//   <script src="/assets/js/not-found.js" data-site="https://travel.mcknight.io"
//           data-email="travel@andrew.mcknight.io"></script>
(function () {
  var site = document.currentScript.dataset.site;
  var email = document.currentScript.dataset.email;
  var path = window.location.pathname + window.location.search;
  if (path === '/404.html') return;

  document.getElementById('error-path').textContent = path;
  document.getElementById('error-address').hidden = false;

  var url = site + path;
  document.getElementById('wayback-link').href = 'https://web.archive.org/web/' + url;

  var host = site.replace(/^https?:\/\//, '');
  var body = 'Hi Andrew,\n\nThis address on your site is missing:\n' + url + '\n\n' +
    (document.referrer ? 'I followed a link to it from:\n' + document.referrer + '\n\n' : '') +
    'Thanks!';
  document.getElementById('report-link').href = 'mailto:' + email +
    '?subject=' + encodeURIComponent('Broken link on ' + host + ': ' + path) +
    '&body=' + encodeURIComponent(body);
})();
