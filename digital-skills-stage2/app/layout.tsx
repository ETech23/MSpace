import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import { ServiceWorkerRegistration } from "../components/ServiceWorkerRegistration";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  display: "swap"
});

export const metadata: Metadata = {
  title: "Digital Skills Laptop Support Program - Stage 2",
  description:
    "Secure Stage 2 verification and processing fee payment for shortlisted Digital Skills Laptop Support Program applicants.",
  manifest: "/manifest.json",
  metadataBase: new URL("https://mspaceapp.com"),
  openGraph: {
    title: "Digital Skills Laptop Support Program - Stage 2",
    description:
      "Complete your Stage 2 verification and application processing fee.",
    url: "https://mspaceapp.com/stage2",
    siteName: "Mspace",
    type: "website"
  }
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#F3F8F5" },
    { media: "(prefers-color-scheme: dark)", color: "#09130F" }
  ]
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <ServiceWorkerRegistration />
        {children}
      </body>
    </html>
  );
}
