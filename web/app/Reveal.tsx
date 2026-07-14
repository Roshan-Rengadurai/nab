"use client";

import { useEffect, useRef, useState } from "react";

/** Fades + lifts its children into view the first time they scroll into the viewport. */
export default function Reveal({
  children,
  className,
  delay = 0,
}: {
  children: React.ReactNode;
  className?: string;
  delay?: number;
}) {
  const ref = useRef<HTMLDivElement>(null);
  // `armed` gates the hidden-then-in transition. It starts false so the SSR /
  // no-JS / headless render is fully visible; we only arm it client-side when
  // we can actually observe the element scrolling in. Content is never gated
  // on JS that might not run.
  const [armed, setArmed] = useState(false);
  const [shown, setShown] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    // Only animate what the user will actually scroll TO. If the block is
    // already in view at mount (above the fold), leave it visible, fading in
    // on-load content is the uniform reflex and just flickers. Arm + observe
    // only the below-fold blocks so the entrance lands as they scroll in.
    if (el.getBoundingClientRect().top < window.innerHeight * 0.9) return;
    setArmed(true);

    const io = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          setShown(true);
          io.disconnect();
        }
      },
      { rootMargin: "0px 0px -12% 0px", threshold: 0.15 },
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  return (
    <div
      ref={ref}
      className={`reveal${armed ? " reveal-armed" : ""}${
        shown ? " reveal-in" : ""
      }${className ? ` ${className}` : ""}`}
      style={delay ? { transitionDelay: `${delay}ms` } : undefined}
    >
      {children}
    </div>
  );
}
