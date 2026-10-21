/* An interactive globe of everywhere I have been.
 *
 * Three layers, each saying a different thing:
 *   - a country I have visited, filled pale
 *   - a state, province or region I have visited, filled strong on top
 *   - a trip, a line, coloured by its type; a type is any word the data
 *     uses, so the colours are given out here rather than in the stylesheet
 *   - a city, point of interest or high mark, a dot
 *
 * High marks can also be narrowed to a range of heights, with a histogram over
 * the range showing how many there are at each height.
 *
 * The globe itself — an orthographic projection, sized to the page, turned,
 * magnified and spun — is the shared core, globe-core.js, which the books site
 * uses too. The projection clips the shapes on the far side of the Earth; the
 * dots are not shapes, so they are hidden by hand, with the core's visible().
 */

(function () {
  'use strict';

  var svg = d3.select('#globe');
  var tooltip = d3.select('#tooltip');
  var figure = document.getElementById('globe-figure');
  // Every kind of place together, each carrying the kind that tells them apart
  // and an id the list uses to point at it.
  var places = JSON.parse(document.getElementById('place-data').textContent);

  // A place names its regions by key. The names and countries behind those
  // keys are written once, in region-data, and joined on here. A point of
  // interest can lie in several regions, and so in several countries.
  var regionsByKey = JSON.parse(document.getElementById('region-data').textContent);
  var placesById = {};
  places.forEach(function (place) {
    var regions = place.regions.map(function (key) { return regionsByKey[key]; }).filter(Boolean);
    place.countryCodes = regions.map(function (r) { return r.countryCode; })
      .filter(function (code, i, all) { return all.indexOf(code) === i; });
    place.where = [
      regions.map(function (r) { return r.name; }).join(', '),
      regions.map(function (r) { return r.country; })
        .filter(function (name, i, all) { return all.indexOf(name) === i; }).join(', ')
    ].filter(Boolean).join(' \u00b7 ');
    placesById[place.id] = place;
  });

  // Whether a place is in a region, a country, or any of a list of countries.
  function placeIn(d, kind, key) {
    if (kind === 'region') return d.regions.indexOf(key) !== -1;
    var wanted = String(key).split(',');
    return d.countryCodes.some(function (code) { return wanted.indexOf(code) !== -1; });
  }

  // The kinds present in the data, in the order they first appear. Nothing here
  // names a kind, so adding one to the data and to the page's list is enough
  // — this follows.
  var KINDS = [];
  places.forEach(function (place) {
    if (KINDS.indexOf(place.kind) === -1) KINDS.push(place.kind);
  });

  // Heights are stored in metres, once, and shown in whichever unit is chosen.
  // One function formats every one of them, so the list, the tooltips and the
  // labels on the globe can never disagree about a number.
  var unit = 'ft';

  function elevationText(metres) {
    if (metres === undefined || metres === null) return '';
    var value = unit === 'ft' ? Math.round(metres * 3.28084) : Math.round(metres);
    return value.toLocaleString() + ' ' + unit;
  }

  // Which layers are drawn. The legend doubles as the control for these.
  var showing = { countries: true, regions: true, trips: true, labels: true };
  KINDS.forEach(function (kind) { showing[kind] = true; });

  // The heights of high mark shown, as a test on each place. Everything else
  // has no height and is never filtered by it. Set by wireHeights.
  var inHeightRange = function () { return true; };

  // Widens the heights shown just enough to take in a high mark the list
  // offers but the range leaves out. Set by wireHeights.
  var includeHeight = function () {};

  // The projection, sizing, gestures, spin, tooltip and camera are the shared
  // globe core's (shared/assets/js/globe-core.js); this script draws the
  // layers on it. Opening on the Americas, where most of the data is, rather
  // than on the Atlantic at 0,0 where there is nothing to see.
  var core = GlobeCore.create({ svg: svg, figure: figure, tooltip: tooltip, rotate: [75, -25], draw: draw });
  var projection = core.projection;
  var path = core.path;
  var schedule = core.schedule;
  var visible = core.visible;
  var showTooltip = core.showTooltip;
  var hideTooltip = core.hideTooltip;
  var stopSpinning = core.stopSpinning;
  var baseScale = core.baseScale;
  var scaleToFit = core.scaleToFit;
  var angularRadius = core.angularRadius;
  var moveTo = core.moveTo;

  var layers = {
    countries: core.layer(),
    regions: core.layer(),
    // Trips sit over the regions and under the dots, so a summit's dot is not
    // hidden by the line that climbs to it.
    trips: core.layer(),
    // One group per kind of place, created between the regions and the labels
    // so dots sit over fills and names sit over dots. Showing or hiding a kind
    // is then one attribute on one group.
    dots: {},
    labels: null
  };

  KINDS.forEach(function (kind) { layers.dots[kind] = core.layer(); });
  layers.labels = core.layer();

  var outline = document.getElementById('outline');
  var clearButton = document.getElementById('clear-focus');

  // Every city carries its name, but only the names that fit are drawn.
  //
  // Placement is greedy: the city nearest the middle of the globe is labelled
  // first, and any label that would cover one already placed is left out. So a
  // crowded coast shows a few names now and more as the globe is magnified,
  // rather than a solid block of overlapping text. Whatever is left out still
  // answers the pointer.
  //
  // Widths are estimated from the letter count. Measuring 71 real text boxes on
  // every frame of a drag costs far more than the estimate costs in accuracy.
  // A high mark carries its height on the globe as well, since that is the
  // whole point of marking one.
  function labelText(d) {
    return d.elevation ? d.name + '  ' + elevationText(d.elevation) : d.name;
  }

  function placeLabels(radius) {
    var rotation = projection.rotate();
    var centre = [-rotation[0], -rotation[1]];
    var fontSize = Math.max(9.5, Math.min(13, core.size() / 58));
    var candidates = [];

    layers.labels.selectAll('text').each(function (d) {
      // A hidden kind gives up its place in the queue as well as its ink, so
      // hiding the cities lets the points of interest claim the room.
      var wanted = showing.labels && showing[d.kind] && inHeightRange(d);
      var point = wanted && visible(d) ? projection([d.lon, d.lat]) : null;
      if (!point) {
        this.style.display = 'none';
        return;
      }
      candidates.push({
        node: this,
        x: point[0] + radius + 3,
        y: point[1] + (fontSize * 0.35),
        width: labelText(d).length * fontSize * 0.55,
        height: fontSize,
        distance: d3.geoDistance([d.lon, d.lat], centre)
      });
    });

    candidates.sort(function (a, b) { return a.distance - b.distance; });

    var placed = [];
    candidates.forEach(function (candidate) {
      var clashes = placed.some(function (other) {
        return candidate.x < other.x + other.width &&
               candidate.x + candidate.width > other.x &&
               candidate.y - candidate.height < other.y &&
               candidate.y > other.y - other.height;
      });
      if (clashes) {
        candidate.node.style.display = 'none';
        return;
      }
      placed.push(candidate);
      candidate.node.style.display = null;
      candidate.node.setAttribute('x', candidate.x);
      candidate.node.setAttribute('y', candidate.y);
      candidate.node.setAttribute('font-size', fontSize);
    });
  }

  // The site's layers, which the core redraws after every change of view.
  function draw() {
    layers.countries.selectAll('path').attr('d', path);
    layers.regions.selectAll('path').attr('d', path);
    layers.trips.selectAll('path').attr('d', path);

    var radius = Math.max(2.4, core.size() / 230);

    // A dot has no extent, so it is drawn only when its side of the Earth faces
    // the viewer. Without this the back of the globe shows through.
    KINDS.forEach(function (kind) {
      layers.dots[kind].selectAll('circle')
        .attr('transform', function (d) {
          var point = projection([d.lon, d.lat]);
          return point ? 'translate(' + point[0] + ',' + point[1] + ')' : null;
        })
        .attr('display', function (d) { return visible(d) && inHeightRange(d) ? null : 'none'; })
        .attr('r', radius);
    });

    placeLabels(radius);
  }

  // FOCUS MODE
  //
  // Choosing a place, on the globe or in the list, turns the globe to it and
  // moves in far enough to see it, fades everything else back, and marks the
  // matching row in the list. The two views therefore always agree about what
  // is being looked at, whichever one was clicked.

  var focused = null;   // { kind: 'continent'|'country'|'region'|'place', key: string }

  function markOutline() {
    if (!outline) return;
    outline.querySelectorAll('.entry.focused').forEach(function (node) {
      node.classList.remove('focused');
    });
    if (!focused) return;

    // Choosing something shows it in the list, so a folded list unfolds. The
    // toggle does the unfolding, so its label and the globe's size follow.
    var toggle = outline.querySelector('.outline-toggle');
    if (toggle && toggle.getAttribute('aria-expanded') === 'false') toggle.click();

    var selector;
    if (focused.kind === 'place') {
      selector = '.entry[data-id="' + CSS.escape(focused.key) + '"]';
    } else if (focused.kind === 'trip') {
      selector = '.trip-entry[data-id="' + CSS.escape(focused.key) + '"]';
    } else if (focused.kind === 'continent') {
      selector = '.continent-entry[data-name="' + focused.label + '"]';
    } else {
      selector = focused.kind === 'country'
        ? '.country-entry[data-code="' + focused.key + '"]'
        : '.region-entry[data-key="' + focused.key + '"]';
    }

    var row = outline.querySelector(selector);
    if (!row) return;

    // A row inside a shut level cannot be scrolled to, so open everything above
    // it first. That now includes the subheading for its kind, since those are
    // <details> as well.
    var level = row.closest('details');
    while (level) {
      level.open = true;
      level = level.parentElement ? level.parentElement.closest('details') : null;
    }

    row.classList.add('focused');

    // Focusing a place opens the way down to it. Focusing a region, country or
    // continent instead opens what is inside it, so choosing Colorado shows
    // Colorado's places rather than a shut row with its name on it.
    var container = row.closest('details');
    if (container && focused.kind !== 'place' && focused.kind !== 'trip') {
      container.querySelectorAll('details.kind').forEach(function (kind) {
        kind.open = true;
      });
    }

    // Scroll the list, never the page. scrollIntoView moves whatever ancestor
    // it must, and on a phone — where the list sits under the globe rather than
    // beside it — that threw the globe off the screen the moment anything was
    // tapped. When the list is not its own scrolling box, as on a phone, there
    // is nothing to scroll and nothing should move.
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

  function markGlobe() {
    svg.classed('focus-active', focused !== null);
    layers.countries.selectAll('path').classed('focused', function (d) {
      if (focused === null) return false;
      if (focused.kind === 'country') return d.properties.iso === focused.key;
      if (focused.kind === 'continent') return String(focused.key).split(',').indexOf(d.properties.iso) !== -1;
      return false;
    });
    layers.regions.selectAll('path').classed('focused', function (d) {
      return focused !== null && focused.kind === 'region' && d.properties.key === focused.key;
    });
    // A place counts as focused when it is the chosen one, or when it belongs to
    // the chosen region, country or continent. Fading a region's own places
    // along with everything else would hide the very thing being looked at.
    //
    function placeIsFocused(d) {
      if (focused === null) return false;
      if (focused.kind === 'place') return d.id === focused.key;
      return placeIn(d, focused.kind, focused.key);
    }
    KINDS.forEach(function (kind) {
      layers.dots[kind].selectAll('circle').classed('focused', placeIsFocused);
    });
    layers.labels.selectAll('text').classed('focused', placeIsFocused);
    // A trip is focused when it is the chosen one, or passes through the
    // chosen region, country or continent.
    layers.trips.selectAll('path').classed('focused', function (d) {
      if (focused === null || focused.kind === 'place') return false;
      if (focused.kind === 'trip') return d.properties.id === focused.key;
      return placeIn(d.properties, focused.kind, focused.key);
    });
    if (clearButton) clearButton.hidden = focused === null;
  }

  // Which visited places belong to the thing being focused.
  function placesOf(kind, key) {
    return places.filter(function (d) { return placeIn(d, kind, key); });
  }

  // A place is framed by where I actually went in it, not by the outline of the
  // whole thing.
  //
  // That is both more useful and more correct. France's geometry reaches from
  // French Guiana to Réunion, so its bounding box spans half the planet: framing
  // by geometry put the centre in the Atlantic and zoomed to nothing. Alaska's
  // reaches across the date line, for the same kind of reason. The cities have
  // neither problem, and they are the point of the map.
  //
  // A country with no city recorded yet — India — has nothing to frame, so it
  // falls back to its geometry.
  function frameOf(kind, key) {
    var members = placesOf(kind, key);

    if (members.length) {
      return core.framePoints(members.map(function (d) { return [d.lon, d.lat]; }));
    }

    var layer = kind === 'country' ? layers.countries : layers.regions;
    var property = kind === 'country' ? 'iso' : 'code';
    var parts = layer.selectAll('path').data().filter(function (d) {
      return d.properties[property] === key;
    });
    if (!parts.length) return null;

    var group = { type: 'FeatureCollection', features: parts };
    var geometricCentre = d3.geoCentroid(group);
    return { centre: geometricCentre, radius: angularRadius(group, geometricCentre) };
  }

  function focusOn(kind, key, label) {
    var centre;
    var scale;

    if (kind === 'place') {
      var place = placesById[key];
      if (!place) return;
      centre = [place.lon, place.lat];
      scale = baseScale() * 20;
    } else if (kind === 'trip') {
      var trip = layers.trips.selectAll('path').data().filter(function (d) { return d.properties.id === key; })[0];
      if (!trip) return;
      centre = d3.geoCentroid(trip);
      scale = scaleToFit(Math.max(angularRadius(trip, centre) * 1.35, 0.004));
    } else {
      var frame = frameOf(kind, key);
      if (!frame) return;
      centre = frame.centre;
      scale = scaleToFit(frame.radius);
    }

    focused = { kind: kind, key: String(key), label: label };
    markGlobe();
    markOutline();
    moveTo(centre, scale);
  }

  function clearFocus() {
    if (!focused) return;
    focused = null;
    markGlobe();
    markOutline();
    core.zoomOut();
  }

  // The legend is the control panel: each row is a checkbox beside the colour
  // it stands for, so what a colour means and whether it is drawn are one thing.
  //
  // Countries are the exception. Switching them off paints the visited ones like
  // everywhere else rather than removing the land, because removing the land
  // would leave an empty ball.
  function wireLayerControls() {
    var panel = document.getElementById('layers');
    if (!panel) return;

    function apply() {
      svg.classed('hide-countries', !showing.countries);
      layers.regions.attr('display', showing.regions ? null : 'none');
      layers.trips.attr('display', showing.trips ? null : 'none');
      KINDS.forEach(function (kind) {
        layers.dots[kind].attr('display', showing[kind] ? null : 'none');
      });
      layers.labels.attr('display', showing.labels ? null : 'none');
      schedule();
    }

    // The trips group sits inside the legend, so its switch is heard here too.
    panel.addEventListener('change', function (event) {
      if (!event.target.dataset.layer) return;
      showing[event.target.dataset.layer] = event.target.checked;
      apply();
    });

    apply();
  }

  // HEIGHTS
  //
  // Two sliders over one track choose the lowest and highest high mark shown,
  // with a histogram above them: one bar per bucket of height, as tall as the
  // number of high marks in it. The buckets are equal steps of height rather
  // than percentiles, because a bucket per percentile holds the same number of
  // places by definition, and the bars would all be one height.
  //
  // The steps are round numbers in whichever unit is chosen — 500 ft, or
  // 200 m — so they are worked out again when the unit changes. The sliders
  // move a whole bucket at a time, so the range always lines up with the bars.
  //
  // Returns the function that works the buckets out again, or null when there
  // are too few heights to be worth a control.
  function wireHeights() {
    var panel = document.getElementById('heights');
    var measured = places.filter(function (d) { return d.kind === 'highmark' && d.elevation; });
    if (!panel || measured.length < 2) return null;

    var histogram = panel.querySelector('.histogram');
    var low = panel.querySelector('.low');
    var high = panel.querySelector('.high');
    var span = panel.querySelector('.span');

    // The chosen range in metres, so it survives a change of unit. Null ends
    // mean the whole way to the lowest or highest.
    var chosen = { from: null, to: null };
    var bounds = [];   // bucket edges, in the shown unit, lowest first

    function shown(metres) {
      return unit === 'ft' ? metres * 3.28084 : metres;
    }

    // The last bucket includes its top edge, so the highest high mark is in it
    // even when it falls exactly on a round number.
    function bucketOf(metres) {
      var value = shown(metres);
      var i = 0;
      while (i < bounds.length - 2 && value >= bounds[i + 1]) i += 1;
      return i;
    }

    function rebin() {
      var values = measured.map(function (d) { return shown(d.elevation); });
      var lowest = d3.min(values);
      var highest = d3.max(values);
      var step = d3.tickStep(lowest, highest, 20);
      var start = Math.floor(lowest / step) * step;
      var end = Math.max(Math.ceil(highest / step) * step, start + step);
      bounds = d3.range(start, end + (step / 2), step);

      var buckets = bounds.length - 1;
      [low, high].forEach(function (input) { input.max = buckets; });

      // The edges nearest the chosen range that still contain it.
      var from = chosen.from === null ? 0 : d3.bisectRight(bounds, shown(chosen.from)) - 1;
      var to = chosen.to === null ? buckets : d3.bisectLeft(bounds, shown(chosen.to));
      low.value = Math.max(0, Math.min(from, buckets - 1));
      high.value = Math.max(Number(low.value) + 1, Math.min(to, buckets));

      var counts = bounds.slice(0, -1).map(function () { return 0; });
      measured.forEach(function (d) { counts[bucketOf(d.elevation)] += 1; });
      var most = d3.max(counts);
      histogram.replaceChildren.apply(histogram, counts.map(function (count, i) {
        var bar = document.createElement('i');
        bar.style.height = (count / most * 100) + '%';
        // An empty bucket keeps its slot, so the bars stay lined up with the
        // slider, but draws nothing: even a hairline reads as one high mark.
        bar.classList.toggle('empty', count === 0);
        bar.title = edgeText(bounds[i]) + '\u2013' + edgeText(bounds[i + 1]) + ': ' + count;
        return bar;
      }));

      apply();
    }

    function edgeText(value) {
      return Math.round(value).toLocaleString();
    }

    function apply() {
      var from = Number(low.value);
      var to = Number(high.value);
      var whole = from === 0 && to === bounds.length - 1;

      inHeightRange = whole ? function () { return true; } : function (d) {
        if (d.kind !== 'highmark' || !d.elevation) return true;
        var bucket = bucketOf(d.elevation);
        return bucket >= from && bucket < to;
      };

      Array.prototype.forEach.call(histogram.children, function (bar, i) {
        bar.classList.toggle('out', i < from || i >= to);
      });
      span.textContent = edgeText(bounds[from]) + ' \u2013 ' + edgeText(bounds[to]) + ' ' + unit +
        (whole ? '' : ' \u00b7 ' + measured.filter(inHeightRange).length + ' of ' + measured.length);

      // The list keeps the high marks the globe leaves out, greyed, so they
      // can still be found; choosing one widens the range to take it in.
      outline.querySelectorAll('.highmark-entry[data-id]').forEach(function (entry) {
        var place = placesById[entry.dataset.id];
        var out = Boolean(place) && !inHeightRange(place);
        entry.classList.toggle('filtered-out', out);
        if (out) entry.title = 'Outside the heights shown. Choose it to widen them.';
        else entry.removeAttribute('title');
      });
      schedule();
    }

    // A handle cannot pass the other: the range always holds one bucket.
    function moved(event) {
      if (Number(low.value) >= Number(high.value)) {
        if (event.target === low) low.value = Number(high.value) - 1;
        else high.value = Number(low.value) + 1;
      }
      remember();
    }

    // Only the end on the high mark's side moves, and only as far as its
    // bucket, so the rest of the range is kept.
    includeHeight = function (d) {
      if (!d || !d.elevation || inHeightRange(d)) return;
      var bucket = bucketOf(d.elevation);
      if (bucket < Number(low.value)) low.value = bucket;
      if (bucket >= Number(high.value)) high.value = bucket + 1;
      remember();
    };

    function remember() {
      var buckets = bounds.length - 1;
      var unitToMetres = unit === 'ft' ? 1 / 3.28084 : 1;
      chosen.from = Number(low.value) === 0 ? null : bounds[low.value] * unitToMetres;
      chosen.to = Number(high.value) === buckets ? null : bounds[high.value] * unitToMetres;
      apply();
    }

    low.addEventListener('input', moved);
    high.addEventListener('input', moved);
    panel.hidden = false;
    rebin();
    return rebin;
  }

  // Switching the unit rewrites every height already on the page: the ones in
  // the list, which the server left empty for this reason, the ones in the
  // labels on the globe, and the buckets of the height control.
  function wireUnits(rebinHeights) {
    function redraw() {
      document.querySelectorAll('#outline .elevation').forEach(function (node) {
        node.textContent = ' ' + elevationText(Number(node.dataset.metres));
      });
      layers.labels.selectAll('text').text(labelText);
      if (rebinHeights) rebinHeights();
      schedule();
    }

    document.querySelectorAll('input[name="elevation-unit"]').forEach(function (radio) {
      radio.addEventListener('change', function () {
        if (!radio.checked) return;
        unit = radio.value;
        redraw();
      });
    });

    redraw();
  }

  function wireOutline() {
    if (!outline) return;
    outline.addEventListener('click', function (event) {
      var entry = event.target.closest('.entry');
      if (!entry || entry.classList.contains('not-located')) return;

      // Without this the click reaches the <summary> it sits in and toggles
      // the level as well as choosing the place.
      event.preventDefault();

      var kind = entry.dataset.kind;
      var key = kind === 'place' || kind === 'trip' ? entry.dataset.id
              : kind === 'continent' ? entry.dataset.countries
              : kind === 'country' ? entry.dataset.code
              : entry.dataset.key;
      if (entry.classList.contains('filtered-out')) includeHeight(placesById[key]);
      focusOn(kind, key, entry.dataset.name);
    });
    if (clearButton) clearButton.addEventListener('click', clearFocus);
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') clearFocus();
    });
  }

  // TRIP TYPES
  //
  // A trip's type is free text, so there is no list of types to colour in the
  // stylesheet. Each type gets a colour from one palette instead, the most
  // used type first, so the types there are most of never share a colour. The
  // legend shows each type with its colour and how many trips it has, and the
  // list marks each trip with its type's colour.
  function colourTripTypes(features) {
    var counts = d3.rollups(features, function (group) { return group.length; },
      function (d) { return d.properties.type || ''; });
    counts.sort(function (a, b) { return b[1] - a[1] || d3.ascending(a[0], b[0]); });
    var colour = d3.scaleOrdinal(counts.map(function (pair) { return pair[0]; }), d3.schemeTableau10);

    var legend = document.getElementById('trip-legend');
    var key = legend && legend.querySelector('.trip-key');
    if (key && counts.length) {
      key.replaceChildren.apply(key, counts.map(function (pair) {
        var item = document.createElement('span');
        var swatch = document.createElement('i');
        swatch.className = 'line';
        swatch.style.background = colour(pair[0]);
        item.append(swatch, ' ' + (pair[0] || 'no type') + ' ', Object.assign(document.createElement('span'), {
          className: 'count', textContent: pair[1]
        }));
        return item;
      }));
      legend.hidden = false;
    }

    document.querySelectorAll('#outline .trip-entry .trip-type').forEach(function (label) {
      label.style.color = colour(label.parentNode.dataset.type || '');
    });

    return colour;
  }

  Promise.all([
    d3.json('/assets/geo/countries.json'),
    d3.json('/assets/geo/regions.json'),
    // No trips yet is no reason not to draw the rest.
    d3.json('/assets/geo/trips.json').catch(function () { return { features: [] }; })
  ]).then(function (data) {
    var countries = data[0];
    var regions = data[1];
    var trips = data[2];

    // The countries a trip passes through, for focusing a country or a
    // continent, worked out from its regions as a place's are.
    trips.features.forEach(function (feature) {
      var properties = feature.properties;
      var known = (properties.regions || []).map(function (key) { return regionsByKey[key]; }).filter(Boolean);
      properties.regions = properties.regions || [];
      properties.countryCodes = known.map(function (r) { return r.countryCode; })
        .filter(function (code, i, all) { return all.indexOf(code) === i; });
      properties.where = known.map(function (r) { return r.name; }).join(', ');
    });

    var tripColour = colourTripTypes(trips.features);

    layers.trips.selectAll('path')
      .data(trips.features)
      .join('path')
      .attr('class', 'trip')
      .style('stroke', function (d) { return tripColour(d.properties.type); })
      .on('pointerenter', function (event, d) {
        showTooltip(event, d.properties.name, [d.properties.type, d.properties.where].filter(Boolean).join(' \u00b7 '));
      })
      .on('pointerleave', hideTooltip)
      .on('click', function (event, d) { focusOn('trip', d.properties.id, d.properties.name); });

    layers.countries.selectAll('path')
      .data(countries.features)
      .join('path')
      .attr('class', function (d) { return 'country' + (d.properties.visited ? ' visited' : ''); })
      .on('pointerenter', function (event, d) {
        if (!d.properties.visited) return;
        showTooltip(event, d.properties.name, 'country');
      })
      .on('pointerleave', hideTooltip)
      .on('click', function (event, d) {
        if (d.properties.visited) focusOn('country', d.properties.iso);
      });

    layers.regions.selectAll('path')
      .data(regions.features)
      .join('path')
      .attr('class', 'region')
      .on('pointerenter', function (event, d) {
        showTooltip(event, d.properties.name, d.properties.code || d.properties.country);
      })
      .on('pointerleave', hideTooltip)
      .on('click', function (event, d) { focusOn('region', d.properties.key); });

    KINDS.forEach(function (kind) {
      layers.dots[kind].selectAll('circle')
        .data(places.filter(function (d) { return d.kind === kind; }))
        .join('circle')
        // The kind becomes a class, so a city and a point of interest are told
        // apart by the stylesheet rather than by this script.
        .attr('class', function (d) { return 'place ' + d.kind; })
        .on('pointerenter', function (event, d) {
          showTooltip(event, d.name + (d.elevation ? '  ' + elevationText(d.elevation) : ''), d.where);
        })
        .on('pointerleave', hideTooltip)
        .on('click', function (event, d) { focusOn('place', d.id); });
    });

    layers.labels.selectAll('text')
      .data(places)
      .join('text')
      .attr('class', function (d) { return 'place-label ' + d.kind; })
      .text(labelText);

    core.sphere.style('cursor', 'default').on('click', clearFocus);

    core.start();
    wireOutline();
    wireLayerControls();
    wireUnits(wireHeights());
  }).catch(function (error) {
    document.getElementById('globe-figure').insertAdjacentHTML(
      'beforeend',
      '<p class="hint">The map data did not load, so the globe cannot be drawn.</p>'
    );
    console.error(error);
  });
})();
