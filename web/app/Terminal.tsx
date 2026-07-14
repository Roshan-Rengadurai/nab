"use client";

import { useState } from "react";
import { Check, Copy, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";

/** A terminal-chrome window for shell snippets and config blocks, with a copy button. */
export default function Terminal({
  title,
  copyText,
  children,
}: {
  title: string;
  /** Raw text to copy, defaults to the rendered children string when omitted. */
  copyText?: string;
  children: React.ReactNode;
}) {
  const [status, setStatus] = useState<"idle" | "copied" | "failed">("idle");

  const legacyCopy = (text: string) => {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();
    const ok = document.execCommand("copy");
    document.body.removeChild(textarea);
    return ok;
  };

  const handleCopy = async () => {
    const text = copyText ?? (typeof children === "string" ? children : "");
    if (!text) return;
    let ok = true;
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      ok = legacyCopy(text);
    }
    setStatus(ok ? "copied" : "failed");
    setTimeout(() => setStatus("idle"), 1500);
  };

  return (
    <div className="overflow-hidden rounded-xl border border-bg2 bg-bg0-hard">
      <div className="flex items-center gap-2 border-b border-bg1 bg-bg1/70 px-4 py-2.5 font-mono text-xs text-gray">
        <span className="h-3 w-3 rounded-full bg-red" />
        <span className="h-3 w-3 rounded-full bg-yellow" />
        <span className="h-3 w-3 rounded-full bg-green" />
        <span className="ml-3">{title}</span>
        <Tooltip>
          <TooltipTrigger
            render={
              <Button
                variant="ghost"
                size="icon-xs"
                onClick={handleCopy}
                className="ml-auto text-gray hover:bg-bg2 hover:text-fg0"
                aria-label={
                  status === "copied"
                    ? "Copied"
                    : status === "failed"
                      ? "Copy failed"
                      : "Copy to clipboard"
                }
              />
            }
          >
            {status === "copied" ? (
              <Check className="size-3.5 text-green" />
            ) : status === "failed" ? (
              <X className="size-3.5 text-red" />
            ) : (
              <Copy className="size-3.5" />
            )}
          </TooltipTrigger>
          <TooltipContent>
            {status === "copied"
              ? "Copied!"
              : status === "failed"
                ? "Couldn't copy"
                : "Copy"}
          </TooltipContent>
        </Tooltip>
      </div>
      <pre className="overflow-x-auto px-5 py-4 font-mono text-[13px] leading-relaxed text-fg1">
        <code>{children}</code>
      </pre>
    </div>
  );
}
