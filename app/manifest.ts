import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Setline — Workout Execution Tracker",
    short_name: "Setline",
    description:
      "Follow structured workouts, record sets, and control rest periods without relying on a network connection.",
    start_url: "/",
    display: "standalone",
    background_color: "#f4f5ef",
    theme_color: "#f4f5ef",
    orientation: "portrait",
    icons: [
      {
        src: "/icon-192.png",
        sizes: "192x192",
        type: "image/png",
        purpose: "any maskable",
      },
      {
        src: "/icon-512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "any maskable",
      },
    ],
  };
}
