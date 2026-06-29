import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "AI PM Platform",
  description: "AI-powered meeting to project management workspace",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
