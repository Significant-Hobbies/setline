import type { Metadata, Viewport } from "next";
import { headers } from "next/headers";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host =
    requestHeaders.get("x-forwarded-host") ??
    requestHeaders.get("host") ??
    "localhost:3000";
  const protocol =
    requestHeaders.get("x-forwarded-proto") ??
    (host.startsWith("localhost") ? "http" : "https");
  const origin = `${protocol}://${host}`;
  const description =
    "Build the plan once. Follow it precisely every day with guided sets, rest timing, and device-local workout history.";

  return {
    metadataBase: new URL(origin),
    title: "Setline — Workout execution tracker",
    description,
    applicationName: "Setline",
    appleWebApp: {
      capable: true,
      statusBarStyle: "default",
      title: "Setline",
    },
    icons: {
      icon: "/favicon.png",
      apple: "/icon-192.png",
    },
    openGraph: {
      title: "Setline — Workout execution tracker",
      description,
      type: "website",
      images: [
        {
          url: new URL("/og.png", origin).toString(),
          width: 1200,
          height: 630,
          alt: "Setline bench press workout attempt board",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: "Setline — Workout execution tracker",
      description,
      images: [new URL("/og.png", origin).toString()],
    },
  };
}

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  themeColor: "#f4f5ef",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
