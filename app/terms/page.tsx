import type { Metadata } from "next";
import { LegalPage } from "../components/LegalPage";

export const metadata: Metadata = {
  title: "Terms of use — Setline",
  description: "Terms for using the Setline workout execution tracker.",
};

export default function TermsPage() {
  return <LegalPage kind="terms" />;
}
