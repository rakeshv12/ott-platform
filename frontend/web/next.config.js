/** @type {import("next").NextConfig} */
const nextConfig = {
  output: "standalone",
  images: {
    domains: ["via.placeholder.com"],
  },
  env: {
    NEXT_PUBLIC_AUTH_API: process.env.NEXT_PUBLIC_AUTH_API || "http://localhost:3001",
  },
}
module.exports = nextConfig