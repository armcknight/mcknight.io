/* The parts of a globe that do not depend on what is drawn on it, shared by
 * travel.mcknight.io and books.mcknight.io: an orthographic projection sized
 * to the page, turning by drag, magnifying by wheel and pinch, a slow spin
 * until it is touched, a tooltip, and the camera moves that frame a thing.
 *
 * Each site's own script draws its layers and answers its own clicks; this
 * draws the ocean, the graticule and the edge, and calls the site's `draw`
 * after every change of view. It lives in shared/ and is copied into each
 * site's build by shared/_plugins/shared_assets.rb.
 *
 * SVG, not canvas: every country and every dot answers the pointer, and the
 * browser does that work for free in SVG. The cost is redrawing paths on each
 * frame of a drag, which a few hundred simplified shapes absorb easily.
 */

(function () {
  'use strict';

  // A globe on an <svg>. The options:
  //
  //   svg      the <svg>, as a d3 selection
  //   figure   the element around it, which the globe sizes itself to and
  //            places the tooltip within
  //   tooltip  the tooltip, as a d3 selection
  //   rotate   where the globe opens, as a d3 rotation
  //   reserve  pixels kept free under the globe for what follows it, such as
  //            a legend; 150 by default
  //   fit      'below', the default: the globe fits in the window under what
  //            is above it, so the whole page fits without scrolling. Or
  //            'screen': it fits the window's height alone, for a page with
  //            more above the globe than a window holds beside it — a long
  //            introduction — which is scrolled away to see the globe whole.
  //   draw     the site's layers, redrawn after every change of view
  //
  // The site adds its layers with `layer()`, which puts each between the
  // graticule and the edge, in the order they are added.
  function create(options) {
    var svg = options.svg;
    var figure = options.figure;
    var tooltip = options.tooltip;
    var reserve = options.reserve === undefined ? 150 : options.reserve;
    var fit = options.fit || 'below';
    var draw = options.draw || function () {};

    var projection = d3.geoOrthographic().clipAngle(90).precision(0.4).rotate(options.rotate || [0, 0]);
    var path = d3.geoPath(projection);
    var graticule = d3.geoGraticule10();

    var sphere = svg.append('path').attr('class', 'sphere');
    var lines = svg.append('path').attr('class', 'graticule');
    // The edge sits above everything, so the sphere keeps a crisp edge no
    // matter what a site draws under it.
    var edge = svg.append('path').attr('class', 'globe-outline');

    function layer() {
      return svg.insert('g', '.globe-outline');
    }

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

    // One place decides how big the globe is: the narrower of the available width
    // and the height left over under the header, so the whole sphere always fits
    // without the page scrolling.
    function measure() {
      // How far in the globe currently is, as a multiple of its whole-globe
      // scale. Resizing must keep that, not throw it away: this used to reset
      // the scale outright, so any resize — including the one a browser fires
      // while a page settles — silently undid the reader's zoom and any focus.
      var magnification = size ? projection.scale() / baseScale() : 1;

      // The narrower of the column and the height there is, once the legend
      // and the hint have their room: the height left under what is above
      // the globe, so the whole page fits without scrolling, or, fitting the
      // screen, the window's whole height.
      var above = fit === 'screen' ? 0 : figure.getBoundingClientRect().top;
      var available = Math.min(
        figure.clientWidth,
        window.innerHeight - above - reserve
      );
      size = Math.max(280, Math.min(available, 760));
      svg.attr('width', size).attr('height', size).attr('viewBox', '0 0 ' + size + ' ' + size);
      projection.translate([size / 2, size / 2]).scale(baseScale() * magnification);
    }

    // Whether a point on the Earth faces the viewer. A dot has no extent for
    // the projection to clip, so it is hidden by hand when this is false.
    function visible(point) {
      var rotation = projection.rotate();
      return d3.geoDistance([point.lon, point.lat], [-rotation[0], -rotation[1]]) < Math.PI / 2;
    }


    function render() {
      sphere.attr('d', path({ type: 'Sphere' }));
      lines.attr('d', path(graticule));
      edge.attr('d', path({ type: 'Sphere' }));
      draw();
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

    // CAMERA
    //
    // Turning to a thing and moving in far enough to see it.

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

    // Back to the whole globe, keeping where it faces.
    function zoomOut() {
      stopSpinning();
      d3.transition().duration(650).ease(d3.easeCubicInOut).tween('unfocus', function () {
        var magnify = d3.interpolate(projection.scale(), baseScale());
        return function (t) {
          projection.scale(magnify(t));
          render();
        };
      });
    }

    // A set of points framed by where they are, rather than by the outline of
    // what holds them: France's geometry reaches from French Guiana to
    // Réunion, so framing by it put the centre in the Atlantic. Returns the
    // centre and how far the points reach from it, with a margin, and a floor
    // for a single point, so it has room around it.
    function framePoints(points) {
      if (!points.length) return null;
      var centre = d3.geoCentroid({ type: 'MultiPoint', coordinates: points });
      var reach = d3.max(points, function (point) { return d3.geoDistance(point, centre); }) || 0;
      return { centre: centre, radius: Math.max(reach * 1.35, 0.035) };
    }

    // Sized, drawn, and answering the pointer, the wheel and the window.
    function start() {
      measure();
      render();
      enableGestures();
      enableZoom();
      spin();
      window.addEventListener('resize', function () {
        measure();
        schedule();
      });
    }

    return {
      projection: projection,
      path: path,
      sphere: sphere,
      layer: layer,
      size: function () { return size; },
      start: start,
      measure: measure,
      render: render,
      schedule: schedule,
      visible: visible,
      showTooltip: showTooltip,
      hideTooltip: hideTooltip,
      stopSpinning: stopSpinning,
      baseScale: baseScale,
      scaleToFit: scaleToFit,
      angularRadius: angularRadius,
      framePoints: framePoints,
      moveTo: moveTo,
      zoomOut: zoomOut
    };
  }

  window.GlobeCore = { create: create };
})();
