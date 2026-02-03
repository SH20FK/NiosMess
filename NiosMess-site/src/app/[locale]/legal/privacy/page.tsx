import { remark } from 'remark';
import html from 'remark-html';
import policy from "@/data/privacy-policy.md"
import {Database, ShieldUser} from "solar-icon-set";
import logo from "@/app/[locale]/_assets/logos/logo.svg";
import Image from "next/image";
import {Metadata} from "next";

export default async function PrivacyPolicy() {
    const processedContent = await remark()
        .use(html)
        .process(policy);
    const contentHtml = processedContent.toString();

    return (
        <div className="w-full text-center max-w-xl px-2 mx-auto my-16 text-neutral-200">
            <aside className="flex items-center justify-center gap-4 text-primary-400 mb-8">
                <Image src={logo} alt="NiosMess logo" />
                <ShieldUser iconStyle="Bold" color="inherit" size={64} />
                <Database iconStyle="Bold" color="inherit" size={64} />
            </aside>
            <div
                className="prose prose-invert prose-headings:font-bold prose-headings:font-display
                prose-a:text-primary-300 prose-a:underline marker:text-inherit prose-li:text-left"
                dangerouslySetInnerHTML={{ __html: contentHtml }}
            />
        </div>
    )
}

export const metadata: Metadata = {
    title: "Privacy Policy",
}
