// Bare domains include their subdomains; complete origins stay exact.
export function allowsSite(rules: string[], url: URL): boolean {
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) return false;
  return rules.some(rule => rule.includes('://')
    ? rule === url.origin
    : url.hostname === rule || url.hostname.endsWith(`.${rule}`));
}

export function defaultSiteUrl(rule: string): string {
  return rule.includes('://') ? rule : `https://${rule}`;
}
