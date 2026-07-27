import type { Metadata } from "next";
import { LegalPage } from "../components/LegalPage";

export const metadata: Metadata = {
  title: "Privacy notice — Setline",
  description: "How Setline stores device-only and Google-synced workout data.",
};

export default function PrivacyPage() {
  return <LegalPage kind="privacy" />;
}
