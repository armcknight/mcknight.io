/* An interactive globe of everywhere I have been.
 *
 * Three layers, each saying a different thing:
 *   - a country I have visited, filled pale
 *   - a state, province or region I have visited, filled strong on top
 *   - a city or point of interest, a dot
 *
 * The projection is orthographic, which is a real globe: half the Earth is
 * behind the sphere and must not be drawn. d3.geoPath does that for the shapes,
 * because clipAngle is set; the dots are not shapes, so they are hidden by hand.
 *
 * SVG, not canvas: every country and every dot answers the pointer, and the
 * browser does that work for free in SVG. The cost is redrawing paths on each
 * frame of a drag, which a few hundred simplified shapes absorb easily.
 */

(function () {
  'use strict';

  var svg = d3.select('#globe');
  var tooltip = d3.select('#tooltip');
  var figure = document.getElementById('globe-figure');
  // Cities and points of interest together, each carrying the kind that tells
  // them apart. One array, so an index means the same thing to the list, the
  // dots and the labels.
  var places = JSON.parse(document.getElementById('place-data').textContent);

  // Each place remembers where it sits in the array, because the dots are split
  // across two groups and a position within a group identifies nothing.
  places.forEach(function (place, i) { place.index = i; });

  // The kinds present in the data, in the order they first appear. Nothing here
  // names a kind, so adding one to travel.yml and to the page's list is enough
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
  var showing = { countries: true, regions: true, labels: true };
  KINDS.forEach(function (kind) { showing[kind] = true; });

  // Opening on the Americas, where most of the data is, rather than on the
  // Atlantic at 0,0 where there is nothing to see.
  var projection = d3.geoOrthographic().clipAngle(90).precision(0.4).rotate([75, -25]);
  var path = d3.geoPath(projection);
  var graticule = d3.geoGraticule10();

  var layers = {
    sphere: svg.append('path').attr('class', 'sphere'),
    graticule: svg.append('path').attr('class', 'graticule'),
    countries: svg.append('g'),
    regions: svg.append('g'),
    // One group per kind of place, created between the regions and the labels
    // so dots sit over fills and names sit over dots. Showing or hiding a kind
    // is then one attribute on one group.
    dots: {},
    labels: null,
    outline: null
  };

  KINDS.forEach(function (kind) { layers.dots[kind] = svg.append('g'); });
  layers.labels = svg.append('g');
  layers.outline = svg.append('path').attr('class', 'globe-outline');

  // The closest the globe will go, as a multiple of the whole-globe scale.
  //
  // One number for every way of moving in — the wheel, a pinch, and focus mode
  // — because two numbers is how scrolling in while focused used to compute a
  // larger scale and then clamp it back down to a smaller cap, which read as
  // zooming out. Beyond about this the 10m boundaries have no more detail to
  // show, so going closer only magnifies the same corners.
  var MAX_MAGNIFICATION = 60;

  var size = 0;
  var spinning = true;
  var frame = null;
  var outline = document.getElementById('outline');
  var clearButton = document.getElementById('clear-focus');

  // One place decides how big the globe is: the narrower of the available width
  // and the height left over under the header, so the whole sphere always fits
  // without the page scrolling.
  function measure() {
    // How far in the globe currently is, as a multiple of its whole-globe
    // scale. Resizing must keep that, not throw it away: this used to reset
    // the scale outright, so any resize — including the one a browser fires
    // while a page settles — silently undid the reader's zoom and any focus.
    var magnification = size ? projection.scale() / baseScale() : 1;

    // The narrower of the column and the height left under the header, once the
    // legend and the hint have their room, so the whole sphere always fits
    // without the page scrolling.
    var available = Math.min(
      figure.clientWidth,
      window.innerHeight - figure.getBoundingClientRect().top - 150
    );
    size = Math.max(280, Math.min(available, 760));
    svg.attr('width', size).attr('height', size).attr('viewBox', '0 0 ' + size + ' ' + size);
    projection.translate([size / 2, size / 2]).scale(baseScale() * magnification);
  }

  function visible(city) {
    var rotation = projection.rotate();
    return d3.geoDistance([city.lon, city.lat], [-rotation[0], -rotation[1]]) < Math.PI / 2;
  }

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
    var fontSize = Math.max(9.5, Math.min(13, size / 58));
    var candidates = [];

    layers.labels.selectAll('text').each(function (d) {
      // A hidden kind gives up its place in the queue as well as its ink, so
      // hiding the cities lets the points of interest claim the room.
      var wanted = showing.labels && showing[d.kind];
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

  function render() {
    layers.sphere.attr('d', path({ type: 'Sphere' }));
    layers.graticule.attr('d', path(graticule));
    layers.outline.attr('d', path({ type: 'Sphere' }));
    layers.countries.selectAll('path').attr('d', path);
    layers.regions.selectAll('path').attr('d', path);

    var radius = Math.max(2.4, size / 230);

    // A dot has no extent, so it is drawn only when its side of the Earth faces
    // the viewer. Without this the back of the globe shows through.
    KINDS.forEach(function (kind) {
      layers.dots[kind].selectAll('circle')
        .attr('transform', function (d) {
          var point = projection([d.lon, d.lat]);
          return point ? 'translate(' + point[0] + ',' + point[1] + ')' : null;
        })
        .attr('display', function (d) { return visible(d) ? null : 'none'; })
        .attr('r', radius);
    });

    placeLabels(radius);
  }

  function schedule() {
    if (frame) return;
    frame = requestAnimationFrame(function () {
      frame = null;
      render();
    });
  }

  function showTooltip(event, title, where) {
    var box = figure.getBoundingClientRect();
    tooltip
      .html('<strong>' + title + '</strong>' + (where ? '<div class="where">' + where + '</div>' : ''))
      .style('left', (event.clientX - box.left + 14) + 'px')
      .style('top', (event.clientY - box.top + 14) + 'px')
      .classed('visible', true);
  }

  function hideTooltip() {
    tooltip.classed('visible', false);
  }

  function stopSpinning() {
    spinning = false;
  }

  function setScale(value) {
    projection.scale(Math.max(baseScale(), Math.min(value, baseScale() * MAX_MAGNIFICATION)));
  }

  // ALL POINTER GESTURES IN ONE PLACE
  //
  // One finger turns the globe. Two pinch it.
  //
  // Written against pointer events rather than d3.drag plus touch handlers,
  // because those two fight: d3.drag calls preventDefault on pointerdown, which
  // suppresses the touch events a pinch handler needs. Pointer events describe
  // mouse, trackpad, pen and finger alike, and counting them is how a gesture is
  // recognised, so one handler covers every case with nothing to conflict with.
  //
  // The one subtlety is pointer capture. Capturing keeps the moves coming when a
  // finger slides off the globe, but it also retargets the click that follows to
  // the element that captured — so capturing on pointerdown sent every click to
  // the <svg> instead of to the country under the finger, and nothing on the
  // globe could be chosen any more. So capture is taken only once a drag is
  // actually under way, and released as soon as it ends.
  function enableGestures() {
    var node = svg.node();
    var active = new Map();          // every finger or button currently down
    var mode = null;                 // rotate | pinch
    var startRotation = null;
    var startPoint = null;
    var startSpread = 0;
    var startScale = 0;
    var captured = false;
    var moved = false;

    function spread() {
      var points = Array.from(active.values());
      return Math.sqrt(Math.pow(points[0].x - points[1].x, 2) + Math.pow(points[0].y - points[1].y, 2));
    }

    function capture(pointerId) {
      if (captured) return;
      try {
        node.setPointerCapture(pointerId);
        captured = true;
      } catch (ignored) {
        // Carry on without capture rather than lose the gesture.
      }
    }

    function releaseCapture(pointerId) {
      if (!captured) return;
      try {
        node.releasePointerCapture(pointerId);
      } catch (ignored) {
        // Already gone.
      }
      captured = false;
    }

    node.addEventListener('pointerdown', function (event) {
      active.set(event.pointerId, { x: event.clientX, y: event.clientY });
      stopSpinning();
      hideTooltip();

      if (active.size === 2) {
        // Two fingers can only mean a pinch, so there is no click to protect.
        mode = 'pinch';
        startSpread = spread();
        startScale = projection.scale();
        capture(event.pointerId);
        moved = true;
        svg.classed('dragging', false);
        return;
      }

      mode = 'rotate';
      startPoint = { x: event.clientX, y: event.clientY };
      startRotation = projection.rotate();
      moved = false;
    });

    node.addEventListener('pointermove', function (event) {
      if (!active.has(event.pointerId)) return;
      active.set(event.pointerId, { x: event.clientX, y: event.clientY });

      if (mode === 'pinch' && active.size >= 2) {
        if (startSpread > 0) setScale(startScale * (spread() / startSpread));
        schedule();
        return;
      }

      if (mode !== 'rotate') return;

      var dx = event.clientX - startPoint.x;
      var dy = event.clientY - startPoint.y;

      // Below this it is a tap with an unsteady hand, not a drag.
      if (!moved && Math.abs(dx) < 4 && Math.abs(dy) < 4) return;

      if (!moved) {
        moved = true;
        capture(event.pointerId);
        svg.classed('dragging', true);
      }

      // Sensitivity falls as the globe is magnified, so a pixel of movement
      // always covers about the same distance on screen.
      var degreesPerPixel = 90 / projection.scale();
      projection.rotate([
        startRotation[0] + (dx * degreesPerPixel),
        Math.max(-90, Math.min(90, startRotation[1] - (dy * degreesPerPixel)))
      ]);
      schedule();
    });

    function release(event) {
      active.delete(event.pointerId);
      releaseCapture(event.pointerId);

      if (active.size === 1 && mode === 'pinch') {
        // A finger lifted mid-pinch: carry on turning with the one left, rather
        // than freezing until both are lifted.
        var remaining = Array.from(active.values())[0];
        mode = 'rotate';
        startPoint = { x: remaining.x, y: remaining.y };
        startRotation = projection.rotate();
        return;
      }

      if (active.size === 0) {
        mode = null;
        svg.classed('dragging', false);
      }
    }

    node.addEventListener('pointerup', release);
    node.addEventListener('pointercancel', release);

    // A drag must not also count as choosing whatever was under the finger.
    // Captured, so it is decided before the shapes see the click.
    node.addEventListener('click', function (event) {
      if (!moved) return;
      event.stopPropagation();
      event.preventDefault();
      moved = false;
    }, true);
  }

  function enableZoom() {
    // A trackpad pinch arrives as a wheel event with ctrlKey set, so both are
    // handled here. preventDefault stops the browser zooming the page instead.
    // A pinch on a touchscreen is not a wheel event at all; that lives in
    // enableGestures with the rest of the touch handling.
    figure.addEventListener('wheel', function (event) {
      event.preventDefault();
      stopSpinning();
      var factor = Math.max(0.5, Math.min(Math.pow(1.0015, -event.deltaY), 2));
      setScale(projection.scale() * factor);
      schedule();
    }, { passive: false });
  }

  // A slow turn on arrival shows that the globe can be turned at all. It stops
  // at the first touch, and never starts for a visitor who asked for less
  // motion.
  function spin() {
    var still = window.matchMedia('(prefers-reduced-motion: reduce)');
    if (still.matches) {
      spinning = false;
      return;
    }
    var last = performance.now();
    d3.timer(function () {
      var now = performance.now();
      var elapsed = now - last;
      last = now;
      if (!spinning) return true;   // returning true stops the timer
      var rotation = projection.rotate();
      projection.rotate([rotation[0] + elapsed * 0.006, rotation[1]]);
      render();
    });
  }

  // FOCUS MODE
  //
  // Choosing a place, on the globe or in the list, turns the globe to it and
  // moves in far enough to see it, fades everything else back, and marks the
  // matching row in the list. The two views therefore always agree about what
  // is being looked at, whichever one was clicked.

  var focused = null;   // { kind: 'continent'|'country'|'region'|'place', key: string }

  function baseScale() {
    return (size / 2) - 2;
  }

  // In an orthographic projection a point an angle away from the centre lands
  // at scale * sin(angle) pixels from the middle. So to fit something of a
  // known angular size, divide the pixels available by the sine of it.
  function scaleToFit(radians) {
    var fitted = ((size / 2) * 0.72) / Math.max(Math.sin(radians), 0.015);
    // A province is a small thing on a planet. Capping at a few times the
    // whole-globe scale would leave it a speck in the middle.
    return Math.max(baseScale(), Math.min(fitted, baseScale() * MAX_MAGNIFICATION));
  }

  // How wide the thing is, as an angle from its own middle. The corners of its
  // bounding box are enough: this only has to choose a sensible magnification,
  // not a tight one.
  function angularRadius(feature, centre) {
    var bounds = d3.geoBounds(feature);
    var corners = [
      [bounds[0][0], bounds[0][1]], [bounds[1][0], bounds[1][1]],
      [bounds[0][0], bounds[1][1]], [bounds[1][0], bounds[0][1]]
    ];
    return d3.max(corners, function (corner) { return d3.geoDistance(corner, centre); }) || 0.02;
  }

  function moveTo(centre, scale) {
    stopSpinning();
    d3.transition()
      .duration(850)
      .ease(d3.easeCubicInOut)
      .tween('focus', function () {
        var turn = d3.interpolate(projection.rotate(), [-centre[0], -centre[1], 0]);
        var magnify = d3.interpolate(projection.scale(), scale);
        return function (t) {
          projection.rotate(turn(t)).scale(magnify(t));
          render();
        };
      });
  }

  function markOutline() {
    if (!outline) return;
    outline.querySelectorAll('.entry.focused').forEach(function (node) {
      node.classList.remove('focused');
    });
    if (!focused) return;

    var selector;
    if (focused.kind === 'place') {
      selector = '.entry[data-index="' + focused.key + '"]';
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
    if (container && focused.kind !== 'place') {
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
    // Identity is the stored index, not the position in a group: the dots are
    // split across two groups now, so a position means nothing on its own.
    function placeIsFocused(d) {
      if (focused === null) return false;
      if (focused.kind === 'place') return String(d.index) === String(focused.key);
      if (focused.kind === 'region') return d.regionKey === focused.key;
      if (focused.kind === 'continent') return String(focused.key).split(',').indexOf(d.countryCode) !== -1;
      return d.countryCode === focused.key;
    }
    KINDS.forEach(function (kind) {
      layers.dots[kind].selectAll('circle').classed('focused', placeIsFocused);
    });
    layers.labels.selectAll('text').classed('focused', placeIsFocused);
    if (clearButton) clearButton.hidden = focused === null;
  }

  // Which visited places belong to the thing being focused.
  function placesOf(kind, key) {
    if (kind === 'country') {
      return places.filter(function (d) { return d.countryCode === key; });
    }
    if (kind === 'region') {
      return places.filter(function (d) { return d.regionKey === key; });
    }
    var wanted = String(key).split(',');
    return places.filter(function (d) { return wanted.indexOf(d.countryCode) !== -1; });
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
      var points = { type: 'MultiPoint', coordinates: members.map(function (d) { return [d.lon, d.lat]; }) };
      var centre = d3.geoCentroid(points);
      var reach = d3.max(members, function (d) { return d3.geoDistance([d.lon, d.lat], centre); }) || 0;
      // A margin, and a floor for the single-city case, so the place has room
      // around it instead of sitting against the edge.
      return { centre: centre, radius: Math.max(reach * 1.35, 0.035) };
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
      var place = places[Number(key)];
      if (!place) return;
      centre = [place.lon, place.lat];
      scale = baseScale() * 20;
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
    stopSpinning();
    d3.transition().duration(650).ease(d3.easeCubicInOut).tween('unfocus', function () {
      var magnify = d3.interpolate(projection.scale(), baseScale());
      return function (t) {
        projection.scale(magnify(t));
        render();
      };
    });
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
      KINDS.forEach(function (kind) {
        layers.dots[kind].attr('display', showing[kind] ? null : 'none');
      });
      layers.labels.attr('display', showing.labels ? null : 'none');
      schedule();
    }

    panel.addEventListener('change', function (event) {
      if (!event.target.dataset.layer) return;
      showing[event.target.dataset.layer] = event.target.checked;
      apply();
    });

    apply();
  }

  // Switching the unit rewrites every height already on the page: the ones in
  // the list, which the server left empty for this reason, and the ones in the
  // labels on the globe.
  function wireUnits() {
    function redraw() {
      document.querySelectorAll('#outline .elevation').forEach(function (node) {
        node.textContent = ' ' + elevationText(Number(node.dataset.metres));
      });
      layers.labels.selectAll('text').text(labelText);
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
      var key = kind === 'place' ? entry.dataset.index
              : kind === 'continent' ? entry.dataset.countries
              : kind === 'country' ? entry.dataset.code
              : entry.dataset.key;
      focusOn(kind, key, entry.dataset.name);
    });
    if (clearButton) clearButton.addEventListener('click', clearFocus);
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') clearFocus();
    });
  }

  Promise.all([
    d3.json('/assets/geo/countries.json'),
    d3.json('/assets/geo/regions.json')
  ]).then(function (data) {
    var countries = data[0];
    var regions = data[1];

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
          var where = [d.region, d.country].filter(Boolean).join(' \u00b7 ');
          showTooltip(event, d.name + (d.elevation ? '  ' + elevationText(d.elevation) : ''), where);
        })
        .on('pointerleave', hideTooltip)
        .on('click', function (event, d) { focusOn('place', d.index); });
    });

    layers.labels.selectAll('text')
      .data(places)
      .join('text')
      .attr('class', function (d) { return 'place-label ' + d.kind; })
      .text(labelText);

    layers.sphere.style('cursor', 'default').on('click', clearFocus);

    measure();
    render();
    enableGestures();
    enableZoom();
    wireOutline();
    wireLayerControls();
    wireUnits();
    spin();

    window.addEventListener('resize', function () {
      measure();
      schedule();
    });
  }).catch(function (error) {
    document.getElementById('globe-figure').insertAdjacentHTML(
      'beforeend',
      '<p class="hint">The map data did not load, so the globe cannot be drawn.</p>'
    );
    console.error(error);
  });
})();
