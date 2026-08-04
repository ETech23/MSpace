import type { Metadata } from "next";
import { Stage1Application } from "../../components/Stage1Application";

export const metadata: Metadata = {
  title: "Digital Skills Laptop Support Program - Stage 1 Application",
  description:
    "Apply for the Digital Skills Laptop Support Program Stage 1 application and submit your details securely.",
  metadataBase: new URL("https://mspaceapp.com"),
  openGraph: {
    title: "Digital Skills Laptop Support Program - Stage 1 Application",
    description:
      "Complete the Stage 1 application to be considered for the Digital Skills Laptop Support Program.",
    url: "https://mspaceapp.com/apply",
    siteName: "Mspace",
    type: "website"
  }
};

export default function ApplyPage() {
  return <Stage1Application />;
}
