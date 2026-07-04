import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "AI PM Platform",
  description: "AIで会議からプロジェクト管理までつなぐワークスペース",
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
