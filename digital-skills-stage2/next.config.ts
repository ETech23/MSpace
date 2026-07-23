import type { NextConfig } from "next";
import path from "node:path";

const nextConfig: NextConfig = {
  output: "export",
  outputFileTracingRoot: path.join(__dirname),
  images: {
    unoptimized: true
  },
  trailingSlash: false,
  poweredByHeader: false
};

export default nextConfig;
