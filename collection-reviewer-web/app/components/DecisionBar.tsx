'use client';

import type { DecisionStatus } from '@/lib/types';

interface Props {
  onDecision: (status: DecisionStatus) => void;
  onMore: () => void;
  onSkip: () => void;
  notesDraft: string;
  onNotesChange: (v: string) => void;
  saving: boolean;
  loading: boolean;
}

export default function DecisionBar({
  onDecision,
  onMore,
  onSkip,
  notesDraft,
  onNotesChange,
  saving,
  loading,
}: Props) {
  const busy = saving || loading;

  return (
    <div className="decision-bar">
      <textarea
        value={notesDraft}
        onChange={e => onNotesChange(e.target.value)}
        placeholder="Notes (optional) — will be saved with decision"
        disabled={busy}
      />
      <div className="buttons">
        <button className="btn-yes" onClick={() => onDecision('yes')} disabled={busy}>
          ✅ Yes
        </button>
        <button className="btn-no" onClick={() => onDecision('no')} disabled={busy}>
          ❌ No
        </button>
        <button className="btn-unsure" onClick={() => onDecision('unsure')} disabled={busy}>
          ⚠️ Unsure
        </button>
        <button className="btn-more" onClick={onMore} disabled={busy}>
          More images
        </button>
        <button className="btn-skip" onClick={onSkip} disabled={busy}>
          Skip
        </button>
        {saving && <span style={{ alignSelf: 'center', color: 'var(--muted)', fontSize: 12 }}>Saving…</span>}
      </div>
    </div>
  );
}
