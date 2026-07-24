'use client';

import { useEffect, useRef, useState } from 'react';
import type { RealtimeChannel, RealtimePostgresChangesPayload } from '@supabase/supabase-js';
import { browserSupabase } from '@/lib/supabase-browser';

export type CollaborationStatus = 'connecting' | 'live' | 'reconnecting' | 'offline' | 'error';
export type CollaborationEvent = {
  table: string;
  eventType: 'INSERT' | 'UPDATE' | 'DELETE';
  receivedAt: string;
};

type Options = {
  spreadId: string;
  enabled?: boolean;
  onChange: (event: CollaborationEvent) => void | Promise<void>;
};

const TABLES = [
  'spreads',
  'assets',
  'asset_versions',
  'review_requests',
  'reviews',
  'review_comments',
  'approvals',
  'tasks',
  'decisions',
  'character_appearances',
] as const;

/**
 * Subscribes to committed Postgres changes. Supabase emits changes only after
 * the surrounding database transaction commits, so the UI never reconciles
 * against a partially completed workflow.
 */
export function useSpreadRealtime({ spreadId, enabled = true, onChange }: Options) {
  const [status, setStatus] = useState<CollaborationStatus>('connecting');
  const [lastEvent, setLastEvent] = useState<CollaborationEvent | null>(null);
  const callbackRef = useRef(onChange);
  const debounceRef = useRef<number | null>(null);
  const pendingEventRef = useRef<CollaborationEvent | null>(null);

  useEffect(() => { callbackRef.current = onChange; }, [onChange]);

  useEffect(() => {
    if (!enabled) {
      setStatus('offline');
      return;
    }

    let active = true;
    let channel: RealtimeChannel | null = null;

    const scheduleReconcile = (event: CollaborationEvent) => {
      pendingEventRef.current = event;
      setLastEvent(event);
      if (debounceRef.current !== null) window.clearTimeout(debounceRef.current);
      debounceRef.current = window.setTimeout(() => {
        const pending = pendingEventRef.current;
        pendingEventRef.current = null;
        if (pending && active) void callbackRef.current(pending);
      }, 180);
    };

    try {
      const supabase = browserSupabase();
      channel = supabase.channel(`spread-manager:${spreadId}`);

      for (const table of TABLES) {
        // Filtering child tables by spread is not possible when they only carry
        // asset/review foreign keys. RLS still limits delivered rows; the final
        // manager fetch performs authoritative spread scoping.
        const filter = table === 'spreads'
          ? `id=eq.${spreadId}`
          : ['assets', 'review_requests', 'tasks', 'decisions', 'character_appearances'].includes(table)
            ? `spread_id=eq.${spreadId}`
            : undefined;

        channel.on(
          'postgres_changes',
          { event: '*', schema: 'public', table, ...(filter ? { filter } : {}) },
          (payload: RealtimePostgresChangesPayload<Record<string, unknown>>) => {
            if (!active) return;
            scheduleReconcile({
              table,
              eventType: payload.eventType,
              receivedAt: new Date().toISOString(),
            });
          },
        );
      }

      channel.subscribe(subscriptionStatus => {
        if (!active) return;
        if (subscriptionStatus === 'SUBSCRIBED') setStatus('live');
        else if (subscriptionStatus === 'CHANNEL_ERROR' || subscriptionStatus === 'TIMED_OUT') setStatus('error');
        else if (subscriptionStatus === 'CLOSED') setStatus(navigator.onLine ? 'reconnecting' : 'offline');
        else setStatus('connecting');
      });
    } catch {
      setStatus('error');
    }

    const handleOnline = () => setStatus(current => current === 'live' ? current : 'reconnecting');
    const handleOffline = () => setStatus('offline');
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      active = false;
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
      if (debounceRef.current !== null) window.clearTimeout(debounceRef.current);
      if (channel) void browserSupabase().removeChannel(channel);
    };
  }, [enabled, spreadId]);

  return { status, lastEvent };
}
