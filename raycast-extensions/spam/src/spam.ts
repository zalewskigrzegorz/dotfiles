import { BrowserExtension, Clipboard, showHUD } from "@raycast/api";

const TARGET_DOMAIN = "mrglaszki.com";

// Two-part public suffixes we care about (PL + common ccTLDs) so foo.sklep.com.pl
// keeps sklep.com.pl instead of collapsing to com.pl. Not the full Public Suffix
// List — just the ones that realistically show up.
const TWO_PART_TLD = /\.(co|com|org|net|gov|edu|ac|biz)\.[a-z]{2}$/;

function registrableDomain(hostname: string): string {
  const host = hostname.replace(/^www\./, "");
  const parts = host.split(".");
  const take = TWO_PART_TLD.test(host) ? 3 : 2;
  return parts.slice(-take).join(".");
}

export default async function command() {
  let tabs: BrowserExtension.Tab[];
  try {
    tabs = await BrowserExtension.getTabs();
  } catch {
    await showHUD("⚠️ Raycast Browser Extension nie odpowiada");
    return;
  }

  const tab = tabs.find((t) => t.active) ?? tabs[0];
  if (!tab?.url) {
    await showHUD("⚠️ Brak aktywnej karty przeglądarki");
    return;
  }

  let hostname: string;
  try {
    hostname = new URL(tab.url).hostname;
  } catch {
    await showHUD(`⚠️ Zły URL: ${tab.url}`);
    return;
  }

  const email = `${registrableDomain(hostname)}@${TARGET_DOMAIN}`;
  await Clipboard.paste(email); // wchodzi prosto w focus field; schowek jako bonus
  await showHUD(`📧 ${email}`);
}
