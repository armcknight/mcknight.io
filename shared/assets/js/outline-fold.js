/* The list beside a globe folds away to the right, to give the globe the room,
 * and starts folded. Shared by travel.mcknight.io and books.mcknight.io, with
 * its styles in globe-core.css.
 *
 * A page puts a button in its list, #outline, inside the .layout grid:
 *
 *   <button type="button" class="outline-toggle" aria-expanded="true"
 *           aria-controls="outline" hidden>Hide list</button>
 *
 * and loads this straight after the list, without defer, so it runs as soon as
 * the list exists. A page's globe script waits for its map data, and folding
 * from there showed the list and then jumped it away. With no script the
 * button stays hidden and the list stays open.
 *
 * Folding fires a resize, which the globe core answers by measuring itself
 * again. OutlineFold.open() unfolds the list, for a globe script to call when
 * something is chosen on the globe, so the list can show where it is.
 */

(function () {
  'use strict';

  var outline = document.getElementById('outline');
  var layout = outline && outline.closest('.layout');
  var toggle = outline && outline.querySelector('.outline-toggle');
  if (!layout || !toggle) return;

  function fold(shut) {
    layout.classList.toggle('outline-shut', shut);
    toggle.setAttribute('aria-expanded', String(!shut));
    toggle.textContent = shut ? 'Show list' : 'Hide list';
    window.dispatchEvent(new Event('resize'));
  }

  toggle.hidden = false;
  toggle.addEventListener('click', function () {
    fold(!layout.classList.contains('outline-shut'));
  });
  fold(true);

  window.OutlineFold = {
    open: function () {
      if (layout.classList.contains('outline-shut')) fold(false);
    }
  };
})();
