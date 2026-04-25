// Single entry point — esbuild bundles every dep into one self-contained
// ESM file at docs/viewer/viewer.bundle.js. No CDN peer-dep collisions.
//
// Build: docs/viewer/build.sh

export {Deck, OrbitView, COORDINATE_SYSTEM} from '@deck.gl/core';
export {PointCloudLayer}                    from '@deck.gl/layers';
export {Tile3DLayer}                        from '@deck.gl/geo-layers';
export {load}                               from '@loaders.gl/core';
export {LASLoader}                          from '@loaders.gl/las';
export {Tiles3DLoader}                      from '@loaders.gl/3d-tiles';
// copc.js handles LAS 1.4 / COPC chunked range reads — loaders.gl/las
// still pins to a laz-perf build that caps at LAS 1.3.
export {Copc, Getter, Hierarchy, Las}       from 'copc';
