"use client";

import Link from "next/link";
import type { JSX } from "react";
import { RemixIcon } from "@/components/remix-icon";
import "./docs-card.css";

// Doc card data type definition
interface DocItem {
  id: string;
  title: string;
  description: string;
}

interface DocsCardProps {
  items: DocItem[];
  basePath: string;
}

export const DocsCard = ({ items, basePath }: DocsCardProps): JSX.Element => {
  return (
    <div className="docs-card-grid">
      {items.map((item) => (
        <Link
          key={item.id}
          href={`${basePath}/${item.id}`}
          className="docs-card-link"
        >
          <div className="docs-card">
            {/* Card decorative element */}
            <div className="docs-card-decoration" />

            {/* Card content */}
            <div className="docs-card-content">
              <h3 className="docs-card-title">{item.title}</h3>
              <p className="docs-card-description">{item.description}</p>

              {/* Arrow icon - shown on hover */}
              <div className="docs-card-learn-more">
                <span>Learn more</span>
                <RemixIcon
                  name="arrow-right-line"
                  variant="none"
                  size="size-5"
                  className="docs-card-arrow"
                />
              </div>
            </div>
          </div>
        </Link>
      ))}
    </div>
  );
};

interface DocsCardGroup {
  heading: string;
  blurb: string;
  items: DocItem[];
}

interface DocsCardGroupsProps {
  groups: DocsCardGroup[];
  basePath: string;
}

// Grouped card grid — used by the docs landing page to separate
// "Start here", "Use OpenLoomi", "Build / Integrate", and "Reference".
export const DocsCardGroups = ({
  groups,
  basePath,
}: DocsCardGroupsProps): JSX.Element => {
  return (
    <div className="docs-card-groups">
      {groups.map((group) => (
        <section key={group.heading} className="docs-card-group">
          <header className="docs-card-group-header">
            <h2 className="docs-card-group-heading">{group.heading}</h2>
            <p className="docs-card-group-blurb">{group.blurb}</p>
          </header>
          <DocsCard items={group.items} basePath={basePath} />
        </section>
      ))}
    </div>
  );
};

// Default export — pre-configured OpenLoomi doc card groups used on /docs
export const OpenLoomiDocsCards = (): JSX.Element => {
  const groups: DocsCardGroup[] = [
    {
      heading: "Start here",
      blurb: "The first 10 minutes — pick the path that matches how you work.",
      items: [
        {
          id: "what-is-openloomi",
          title: "What is OpenLoomi?",
          description:
            "Open-source AI workspace that understands your intent and lives on your machine.",
        },
        {
          id: "getting-started",
          title: "Getting Started",
          description:
            "Install the desktop app, configure an AI provider, and finish your first session.",
        },
        {
          id: "plugins",
          title: "Plugins for Claude Code & Codex",
          description:
            "Use OpenLoomi from inside Claude Code or Codex CLI with a one-command setup.",
        },
      ],
    },
    {
      heading: "Use OpenLoomi",
      blurb:
        "The day-to-day surfaces — connectors, automation, chat, memory, and the Loop.",
      items: [
        {
          id: "connectors",
          title: "Connectors",
          description:
            "Wire up Gmail, Calendar, Slack, GitHub, Linear, and 1000+ apps via Composio.",
        },
        {
          id: "messaging-apps",
          title: "Messaging Apps",
          description:
            "Talk to OpenLoomi directly inside Telegram, WhatsApp, Discord, iMessage, and more.",
        },
        {
          id: "automation",
          title: "Automation",
          description:
            "Schedule jobs, react to events, and trigger cross-app flows from one place.",
        },
        {
          id: "loop",
          title: "Loop",
          description:
            "Proactive execution engine — turns scattered signals across your apps into decision cards.",
        },
        {
          id: "memory",
          title: "Memory",
          description:
            "Tiered storage, forgetting engine, and semantic search across everything OpenLoomi sees.",
        },
      ],
    },
    {
      heading: "Build / Integrate",
      blurb:
        "Plugins, runtimes, and the CLI for developers wiring OpenLoomi in.",
      items: [
        {
          id: "plugins/claude",
          title: "Claude Code Plugin",
          description:
            "Wire Claude Code into the local OpenLoomi runtime with /openloomi:* commands.",
        },
        {
          id: "plugins/codex",
          title: "Codex Plugin",
          description:
            "Use Codex as your coding surface while OpenLoomi owns memory and the runtime.",
        },
        {
          id: "skills",
          title: "Skills",
          description:
            "Built-in skills that extend what OpenLoomi can do from chat and plugins.",
        },
        {
          id: "library",
          title: "Library",
          description:
            "Upload documents and ask AI questions against the local knowledge base.",
        },
      ],
    },
    {
      heading: "Reference",
      blurb:
        "Reference material when you need exact field names, contracts, or history.",
      items: [
        {
          id: "reference",
          title: "Reference",
          description:
            "Agent runtimes, the openloomi-ctl CLI, and embedding provider configuration.",
        },
        {
          id: "use-cases",
          title: "Use Cases",
          description:
            "End-to-end stories from engineering, sales, founders, and global managers.",
        },
        {
          id: "benchmark",
          title: "Benchmarks",
          description:
            "LoCoMo, LongMemEval, and CL-bench performance data for the memory system.",
        },
        {
          id: "privacy-security",
          title: "Privacy & Security",
          description:
            "How OpenLoomi protects your data — local-first storage and credential handling.",
        },
        {
          id: "changelog",
          title: "Changelog",
          description:
            "What shipped in each release — features, fixes, and breaking changes.",
        },
      ],
    },
  ];

  return <DocsCardGroups groups={groups} basePath="/docs" />;
};
