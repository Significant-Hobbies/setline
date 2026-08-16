export type Chapter = {
  name: string;
  title: string;
  copy: string;
  image: string;
  alt: string;
};
export type Faq = { question: string; answer: string };
export type LegalSection = { title: string; body: string };
export type LegalPage = { title: string; lede: string; sections: LegalSection[] };
export type SiteConfig = {
  name: string; url: string; tagline: string; headline: [string, string]; lede: string; kicker: string;
  summary: string; status: string; platforms: string[]; themeColor: string; mark: string; socialImage: string;
  tokens: { paper: string; field: string; ink: string; inkSoft: string; inkFaint: string; accent: string; accentDark: string; accentSoft: string; lanternA: string; lanternB: string; lanternC: string; blush: string; inkOnDark: string };
  colorScheme: "light" | "dark";
  hero: { image: string; alt: string; caption: string };
  gallery: { src: string; alt: string }[];
  applicationCategory: string;
  availability: "unreleased" | "testflight" | "app-store";
  appStoreUrl?: string; appStoreId?: string; betaNote: string;
  tension: { statement: string; title: string; copy: string };
  chaptersKicker: string; chaptersTitle: string; chaptersLede: string; chapters: Chapter[];
  fit: { kicker: string; title: string; yes: string; no: string };
  privacy: { kicker: string; title: string; copy: string };
  faqs: Faq[]; founder: { quote: string; credit: string; note: string }; closingTitle: [string, string];
  footerFinePrint: string; capabilities: string[]; boundaries: string[]; lastUpdated: string;
  legal: { privacy: LegalPage; support: LegalPage; terms: LegalPage; accessibility: LegalPage; testflight: LegalPage & { testing: string; notIncluded: string } };
  requiredHomeCopy: string[]; prohibitedClaims: string[];
};

export const site: SiteConfig = {
  name: "Setline",
  url: "https://setline.significanthobbies.com",
  tagline: "Follow the plan. Record the truth.",
  headline: ["Follow your plan.", "Record the truth."],
  lede: "Setline runs your written strength, cardio and mobility programme one set at a time, and writes down what you actually did.",
  kicker: "An iPhone workout player.",
  summary: "An iOS-native training tracker that runs a written strength, cardio and mobility programme one set at a time and measures each exercise against an authored target.",
  status: "Invite-only TestFlight beta preparation",
  platforms: ["iPhone"],
  themeColor: "#f7f6f0",
  mark: "/images/brand/mark.png",
  socialImage: "/images/brand/social.png",
  tokens: {
    paper: "#ffffff", field: "#f7f6f0", ink: "#18262e", inkSoft: "rgba(24,38,46,0.72)", inkFaint: "rgba(24,38,46,0.12)",
    accent: "#b9e83f", accentDark: "#18262e", accentSoft: "#b9d8e8", lanternA: "#b9e83f", lanternB: "#b9d8e8", lanternC: "#ff614d",
    blush: "#dde1dc", inkOnDark: "#f7f6f0"
  },
  colorScheme: "light",
  hero: { image: "/images/screens/workout-player.jpg", alt: "Setline workout player showing the current set", caption: "The current set owns the screen. Record it, then rest." },
  gallery: [
    { src: "/images/screens/today.jpg", alt: "Setline Today screen with the session for this day" },
    { src: "/images/screens/workout-player.jpg", alt: "Setline recording the current set" },
    { src: "/images/screens/rest-timer.jpg", alt: "Setline rest timer after a completed set" },
    { src: "/images/screens/plan.jpg", alt: "Setline plan for the authored programme" },
    { src: "/images/screens/history.jpg", alt: "Setline history of recorded sessions" }
  ],
  applicationCategory: "HealthApplication",
  availability: "unreleased",
  betaNote: "Device-first. No account in the workout path. Invite-only testing.",
  tension: { statement: "The gym is the wrong place to decide.", title: "Build the plan once.", copy: "Setline keeps authored order, targets, and rest close at hand so you are not rewriting the session between sets." },
  chaptersKicker: "One session",
  chaptersTitle: "Play the workout you wrote.",
  chaptersLede: "Today, the player, and rest. History is the receipt.",
  chapters: [
    { name: "Today", title: "See the session.", copy: "The day resolves to the authored work. Start it without opening another document.", image: "/images/screens/today.jpg", alt: "Setline Today" },
    { name: "Player", title: "Record the set.", copy: "Target, actuals, and the completion control stay visible together. Multi-segment sets stay one set.", image: "/images/screens/workout-player.jpg", alt: "Setline player" },
    { name: "Rest", title: "Rest on the clock.", copy: "Rest is a wall-clock end time, not a suggestion. Then the next target is already there.", image: "/images/screens/rest-timer.jpg", alt: "Setline rest" }
  ],
  fit: { kicker: "An honest fit", title: "Execution. Not a coach.", yes: "Setline fits if you already have a programme and need to run it precisely, one set at a time.", no: "It does not write your programme, count calories, or live on a social feed." },
  privacy: { kicker: "Device first", title: "The workout never waits on a server.", copy: "There is no Setline account in the workout path. The training document lives on the iPhone. Optional private iCloud sync is separate from recording a set." },
  faqs: [
    { question: "Do I need an account?", answer: "No. A workout starts from local storage. There is no request in the middle of a set." },
    { question: "Will it write my programme?", answer: "No. You author the plan. Setline records explicit deviations and never silently rewrites a future session." },
    { question: "Is it on the App Store?", answer: "Not yet. This site will not show an App Store badge until a live apps.apple.com listing exists." }
  ],
  founder: { quote: "I wanted the next set written down before I had to think.", credit: "— Sarthak Agrawal, creator of Setline", note: "An independent app from Significant Hobbies." },
  closingTitle: ["Build the plan once.", "Follow it today."],
  footerFinePrint: "A workout player, not a coach. © 2026 Sarthak Agrawal.",
  capabilities: ["Today: the resolved session", "Player: planned versus actual sets", "Rest: timestamp-derived countdown", "History: recorded sessions"],
  boundaries: ["No Setline account in the workout path", "No advertising SDK", "Not a programme generator", "Not medical advice"],
  lastUpdated: "2026-08-17",
  legal: {
    privacy: { title: "Your training stays on your devices.", lede: "Setline is a device-first iPhone workout player.", sections: [
      { title: "What the app stores", body: "Setline stores your programme, templates, and recorded sessions in the app container. Signed builds may use private iCloud." },
      { title: "What we collect", body: "There is no Setline account server for workouts. The developer does not receive your sets." },
      { title: "Effective date", body: "Last updated 17 August 2026." }
    ]},
    support: { title: "Support, without a maze.", lede: "The fastest way to report a problem in the TestFlight beta.", sections: [
      { title: "Send feedback", body: "Use TestFlight’s Send Beta Feedback action. Say whether you were on Today, the player, rest, or History." }
    ]},
    terms: { title: "Simple beta terms.", lede: "Pre-release software for personal evaluation.", sections: [
      { title: "Beta software", body: "Features may change. Keep anything you cannot lose somewhere else." },
      { title: "No medical service", body: "Setline records training. It does not diagnose or prescribe." },
      { title: "Changes", body: "Last updated 17 August 2026." }
    ]},
    accessibility: { title: "Access is part of the experience.", lede: "Built with Apple’s native accessibility tools.", sections: [
      { title: "Current support", body: "VoiceOver labels, Dynamic Type, and Reduce Motion are part of the player, not a separate mode." }
    ]},
    testflight: { title: "The beta is taking shape.", lede: "We only link to Apple after the enrollment URL is verified.", testing: "Start Today’s session, record a set, confirm rest starts, and check History after relaunch.", notIncluded: "Apple Health, Watch, and automatic programme generation are not in this beta.", sections: [] }
  },
  requiredHomeCopy: ["Follow your plan", "private", "TestFlight"],
  prohibitedClaims: ["guaranteed gains", "available on the app store"]
};

export const links = {
  home: `${site.url}/`, privacy: `${site.url}/privacy/`, support: `${site.url}/support/`,
  terms: `${site.url}/terms/`, accessibility: `${site.url}/accessibility/`, testflight: `${site.url}/testflight/`
};
