/* The books globe: each country coloured by how many of the authors on the
 * chosen shelves were born there, a dot for each birthplace, and a list beside
 * it that the globe opens.
 *
 * The globe itself — projection, sizing, turning, magnifying, spinning, the
 * tooltip and the camera — is the shared core, globe-core.js, which travel's
 * globe uses too. This draws the countries and the dots on it.
 */

(function () {
  'use strict';

  var svg = d3.select('#globe');
  var tooltip = d3.select('#tooltip');
  var figure = document.getElementById('globe-figure');
  var outline = document.getElementById('outline');

  var authors = JSON.parse(document.getElementById('author-data').textContent);
  var books = JSON.parse(document.getElementById('book-data').textContent);

  // The shelf shown, chosen with the switch at the top. The globe's colours,
  // its dots and the list all count only the books on it.
  var shelf = 'read';

  var booksBy = {};
  books.forEach(function (book) {
    (booksBy[book.author] = booksBy[book.author] || []).push(book);
  });

  function shownBooks(name) {
    return (booksBy[name] || []).filter(function (book) { return book.shelf === shelf; });
  }

  // COLOUR
  //
  // On a logarithmic scale, from one author to the most of any country. Half
  // the authors are from the United States, so a straight scale would paint it
  // dark and everything else nearly the same pale blue; on a log scale three
  // authors and fourteen are visibly apart.
  var style = getComputedStyle(document.documentElement);
  var few = style.getPropertyValue('--few').trim();
  var many = style.getPropertyValue('--many').trim();

  var tally = {};   // country code -> { authors, books }
  var most = 1;

  function count() {
    tally = {};
    authors.forEach(function (author) {
      var shown = shownBooks(author.name).length;
      if (!shown) return;
      var entry = tally[author.country] = tally[author.country] || { authors: 0, books: 0 };
      entry.authors += 1;
      entry.books += shown;
    });
    most = d3.max(Object.values(tally), function (entry) { return entry.authors; }) || 1;
    document.getElementById('scale-most').textContent = most;
  }

  function fill(feature) {
    var entry = tally[feature.properties.iso];
    if (!entry) return null;   // the stylesheet's land colour
    var t = most > 1 ? Math.log(entry.authors) / Math.log(most) : 1;
    return d3.interpolateRgb(few, many)(t);
  }

  function plural(n, one, several) { return n + ' ' + (n === 1 ? one : several); }

  function escape(text) {
    return String(text).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  // As exactly as Wikidata knows it, as the list says it: a year, or for a
  // date known only roughly, its decade, century or millennium.
  function bornText(author) {
    if (author.born == null) return '';
    var year = Math.abs(author.born);
    var era = author.born < 0 ? ' BC' : '';
    function ordinal(n) {
      var suffix = n % 100 >= 11 && n % 100 <= 13 ? 'th' : ({ 1: 'st', 2: 'nd', 3: 'rd' })[n % 10] || 'th';
      return n + suffix;
    }
    switch (author.born_precision) {
      case 'century': return 'born ' + ordinal(Math.ceil(year / 100)) + ' century' + era;
      case 'millennium': return 'born ' + ordinal(Math.ceil(year / 1000)) + ' millennium' + era;
      case 'decade': return 'born ' + Math.floor(year / 10) * 10 + 's' + era;
      default: return 'born ' + year + era;
    }
  }

  // THE GLOBE

  // Opening over the Atlantic, between the United States and Europe, where
  // most of the authors are from. Sized to the screen, not to the room left
  // under the introduction, which would leave it a small ball: the
  // introduction is read first, then scrolled away to see the globe whole.
  var core = GlobeCore.create({ svg: svg, figure: figure, tooltip: tooltip, rotate: [40, -35], fit: 'screen', draw: draw });

  var layers = {
    countries: core.layer(),
    dots: core.layer()
  };

  function draw() {
    layers.countries.selectAll('path').attr('d', core.path);
    var radius = Math.max(2.2, core.size() / 260);
    layers.dots.selectAll('circle')
      .attr('transform', function (d) {
        var point = core.projection([d.lon, d.lat]);
        return point ? 'translate(' + point[0] + ',' + point[1] + ')' : null;
      })
      .attr('display', function (d) { return core.visible(d) ? null : 'none'; })
      .attr('r', radius);
  }

  // What the shelf changes: the counts, the colours, and which birthplaces
  // have a dot.
  function paint() {
    count();
    layers.countries.selectAll('path')
      .style('fill', fill)
      .classed('has-authors', function (d) { return Boolean(tally[d.properties.iso]); });

    layers.dots.selectAll('circle')
      .data(authors.filter(function (author) { return shownBooks(author.name).length; }), function (d) { return d.name; })
      .join('circle')
      .attr('class', 'birthplace')
      .on('pointerenter', function (event, d) {
        var where = [bornText(d), d.birthplace].filter(Boolean).join(', ') +
          (d.then ? ' · then ' + d.then.join(', ') : '');
        core.showTooltip(event, escape(d.name), escape(where));
      })
      .on('pointerleave', core.hideTooltip)
      .on('click', function (event, d) { focusAuthor(d.name); });

    markGlobe();
    core.schedule();
  }

  // FOCUS
  //
  // Choosing a country or an author, on the globe or in the list, turns the
  // globe to it, moves in, fades the rest back, and marks the row in the
  // list, as on the travel globe.

  var focused = null;   // { kind: 'country'|'author', key }

  function markGlobe() {
    svg.classed('focus-active', focused !== null);
    layers.countries.selectAll('path').classed('focused', function (d) {
      return focused !== null && focused.kind === 'country' && d.properties.iso === focused.key;
    });
    layers.dots.selectAll('circle').classed('focused', function (d) {
      if (focused === null) return false;
      return focused.kind === 'country' ? d.country === focused.key : d.name === focused.key;
    });
  }

  function markList(row) {
    outline.querySelectorAll('.entry.focused').forEach(function (node) { node.classList.remove('focused'); });
    if (!row) return;
    // Choosing something shows it in the list, so a folded list unfolds.
    if (window.OutlineFold) OutlineFold.open();
    var level = row.closest('details');
    while (level) {
      level.open = true;
      level = level.parentElement ? level.parentElement.closest('details') : null;
    }
    row.classList.add('focused');
    // Scroll the list, never the page, as travel's does.
    if (outline.scrollHeight > outline.clientHeight) {
      var rowBox = row.getBoundingClientRect();
      var listBox = outline.getBoundingClientRect();
      if (rowBox.top < listBox.top) {
        outline.scrollTop -= listBox.top - rowBox.top;
      } else if (rowBox.bottom > listBox.bottom) {
        outline.scrollTop += rowBox.bottom - listBox.bottom;
      }
    }
  }

  // A country is framed by where its authors were born, not by its outline:
  // the United States' reaches from Alaska to Hawaii.
  function focusCountry(iso) {
    var here = authors.filter(function (author) { return author.country === iso; });
    var frame = core.framePoints(here.map(function (author) { return [author.lon, author.lat]; }));
    if (!frame) return;
    focused = { kind: 'country', key: iso };
    markGlobe();
    markList(outline.querySelector('.country-entry[data-iso="' + CSS.escape(iso) + '"]'));
    core.moveTo(frame.centre, core.scaleToFit(frame.radius));
  }

  function focusAuthor(name) {
    var author = authors.find(function (each) { return each.name === name; });
    if (!author) return;
    focused = { kind: 'author', key: name };
    markGlobe();
    markList(outline.querySelector('.author-entry[data-author="' + CSS.escape(name) + '"]'));
    core.moveTo([author.lon, author.lat], core.baseScale() * 12);
  }

  function clearFocus() {
    if (!focused) return;
    focused = null;
    markGlobe();
    markList(null);
    core.zoomOut();
  }

  // THE LIST
  //
  // Books on other shelves are hidden, then any author with none left, then
  // any country with none left; the counts follow.
  function filterList() {
    outline.querySelectorAll('.books li').forEach(function (item) {
      item.hidden = item.className !== shelf;
    });
    outline.querySelectorAll('li.author').forEach(function (item) {
      item.hidden = !item.querySelector('.books li:not([hidden])');
    });
    outline.querySelectorAll('details').forEach(function (group) {
      var shown = group.querySelectorAll('li.author:not([hidden])').length;
      group.hidden = shown === 0;
      var label = group.querySelector('summary .count');
      if (label) label.textContent = shown;
    });
  }

  outline.addEventListener('click', function (event) {
    var entry = event.target.closest('.country-entry, .author-entry');
    if (!entry) return;
    // Choosing the name chooses the place; it should not also fold the row.
    event.preventDefault();
    if (entry.dataset.iso) focusCountry(entry.dataset.iso);
    else focusAuthor(entry.dataset.author);
  });

  // A country or author chosen on one shelf may have nothing on the next, so
  // a change of shelf steps back out of focus first.
  //
  // Each shelf keeps its own list: which countries are open, and how far down
  // it is scrolled. Leaving a shelf remembers them, and coming back puts them
  // back; a shelf not shown yet starts with every country shut. Whether the
  // whole list is folded away is the page's, not a shelf's, and stays.
  var lists = {};   // shelf -> { open: [country code or 'unplaced'], scroll }

  function keyOf(group) {
    return group.dataset.iso || 'unplaced';
  }

  function rememberList() {
    lists[shelf] = {
      open: Array.prototype.map.call(outline.querySelectorAll('details[open]'), keyOf),
      scroll: outline.scrollTop
    };
  }

  function restoreList() {
    var saved = lists[shelf] || { open: [], scroll: 0 };
    outline.querySelectorAll('details').forEach(function (group) {
      group.open = saved.open.indexOf(keyOf(group)) !== -1;
    });
    outline.scrollTop = saved.scroll;
  }

  var switcher = document.getElementById('shelf-switch');
  switcher.hidden = false;
  switcher.addEventListener('change', function (event) {
    if (event.target.name !== 'shelf') return;
    rememberList();
    shelf = event.target.value;
    clearFocus();
    filterList();
    restoreList();
    paint();
  });

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape') clearFocus();
  });

  filterList();

  d3.json('/assets/geo/countries.json').then(function (countries) {
    layers.countries.selectAll('path')
      .data(countries.features)
      .join('path')
      .attr('class', 'country')
      .on('pointerenter', function (event, d) {
        var entry = tally[d.properties.iso];
        if (!entry) return;
        core.showTooltip(event, escape(d.properties.name),
          plural(entry.authors, 'author', 'authors') + ' · ' + plural(entry.books, 'book', 'books'));
      })
      .on('pointerleave', core.hideTooltip)
      .on('click', function (event, d) {
        if (tally[d.properties.iso]) focusCountry(d.properties.iso);
      });

    core.sphere.style('cursor', 'default').on('click', clearFocus);

    paint();
    core.start();
  }).catch(function (error) {
    figure.insertAdjacentHTML('beforeend', '<p class="hint">The borders did not load, so the globe cannot be drawn.</p>');
    console.error(error);
  });
})();
