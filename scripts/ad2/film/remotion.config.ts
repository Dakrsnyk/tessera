/**
 * Note: When using the Node.JS APIs, the config file
 * doesn't apply. Instead, pass options directly to the APIs.
 *
 * All configuration options: https://remotion.dev/docs/config
 */

import { Config } from "@remotion/cli/config";

Config.setRspack(true);
// Lossless frames (glows and gradients band in JPEG), H.264 High at CRF 16, BT.709 (§7 encoding).
Config.setVideoImageFormat("png");
Config.setCrf(16);
Config.setPixelFormat("yuv420p");
Config.setColorSpace("bt709");
Config.setOverwriteOutput(true);
// WebGL (the 3D phone) on the GPU through ANGLE instead of the software renderer.
Config.setChromiumOpenGlRenderer("angle");
