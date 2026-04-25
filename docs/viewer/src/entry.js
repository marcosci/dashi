// Single ESM entry. esbuild bundles into docs/viewer/viewer.bundle.js.
//
// Adopts opengeos/maplibre-gl-lidar wholesale — that lib already implements
// COPC streaming, EPT, color schemes, classification legend, percentile
// coloring, point picking, Z-offset, elevation filter, and a control-panel
// UI. The dashi viewer is a thin wrapper that wires it to the dashi serving
// surface (presigned RustFS URL passed via ?url=…).

import maplibregl       from 'maplibre-gl';
import {LidarControl}   from 'maplibre-gl-lidar';

// CSS shipped as text via esbuild --loader:.css=text. The viewer page
// injects them into <style> tags so we ship a single bundle.
import maplibreCss      from 'maplibre-gl/dist/maplibre-gl.css';
import lidarCss         from 'maplibre-gl-lidar/style.css';

export {maplibregl, LidarControl, maplibreCss, lidarCss};
