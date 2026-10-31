import { useLayoutEffect, useRef } from 'react';
import type { MarkdownLinkOccurrence } from './types/markdownBlocks';

export type LinksChangeHandler = (links: MarkdownLinkOccurrence[]) => void;

function sameLinks(
  a: ReadonlyArray<MarkdownLinkOccurrence>,
  b: ReadonlyArray<MarkdownLinkOccurrence>
): boolean {
  return (
    a.length === b.length &&
    a.every((link, index) => {
      const other = b[index]!;
      return (
        link.url === other.url &&
        link.label === other.label &&
        link.title === other.title
      );
    })
  );
}

/**
 * Reports the collected links to `onLinksChange`, shared by the native and web
 * implementations. It runs in a layout effect, so a state update the handler
 * makes lands before the frame is drawn, and only when the links differ from
 * the last report: a streaming tick that adds no link reports nothing. The
 * handler is read like an event handler; a new function does not report again.
 * `null` means the links are not known, so nothing is reported.
 */
export function useLinksChange(
  links: ReadonlyArray<MarkdownLinkOccurrence> | null,
  onLinksChange: LinksChangeHandler | undefined
): void {
  const handlerRef = useRef(onLinksChange);
  useLayoutEffect(() => {
    handlerRef.current = onLinksChange;
  });

  const reportedRef = useRef<ReadonlyArray<MarkdownLinkOccurrence>>(undefined);
  const enabled = onLinksChange != null;
  useLayoutEffect(() => {
    if (!enabled) {
      reportedRef.current = undefined;
      return;
    }
    if (links == null) return;
    const reported = reportedRef.current;
    if (reported && sameLinks(reported, links)) return;
    reportedRef.current = links;
    handlerRef.current?.([...links]);
  }, [links, enabled]);
}
