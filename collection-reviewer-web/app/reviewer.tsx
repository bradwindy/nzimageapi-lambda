'use client';

import { useState, useEffect, useCallback } from 'react';
import ImageCard from './components/ImageCard';
import CollectionDetails from './components/CollectionDetails';
import DecisionBar from './components/DecisionBar';
import ProgressNav from './components/ProgressNav';
import type { ApiCollection, LambdaImageResponse, DecisionStatus } from '@/lib/types';

interface Props {
  initialCollections: ApiCollection[];
  initialIndex: number;
}

export default function Reviewer({ initialCollections, initialIndex }: Props) {
  const [currentIndex, setCurrentIndex] = useState(initialIndex);
  const [collections, setCollections] = useState<ApiCollection[]>(initialCollections);
  const [images, setImages] = useState<LambdaImageResponse[]>([]);
  const [imagesLoading, setImagesLoading] = useState(false);
  const [imagesError, setImagesError] = useState<string | null>(null);
  const [notesDraft, setNotesDraft] = useState('');
  const [saving, setSaving] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [syncMessage, setSyncMessage] = useState<string | null>(null);
  const [isComplete, setIsComplete] = useState(false);

  const currentCollection = collections[currentIndex];

  // ── Image loading ──────────────────────────────────────────────────────────

  const loadImages = useCallback(async (collectionName: string) => {
    setImagesLoading(true);
    setImagesError(null);
    setImages([]);
    try {
      const res = await fetch(
        `/api/images?collection=${encodeURIComponent(collectionName)}&count=3`,
        { cache: 'no-store' },
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setImages(data.images ?? []);
      if ((data.returned ?? 0) === 0) {
        setImagesError('No images found for this collection.');
      }
    } catch {
      setImagesError('Failed to load images.');
    } finally {
      setImagesLoading(false);
    }
  }, []);

  // Load images whenever the collection changes
  useEffect(() => {
    if (currentCollection) {
      loadImages(currentCollection.name);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentIndex]);

  // ── Navigation ─────────────────────────────────────────────────────────────

  const navigateTo = useCallback(
    async (index: number) => {
      const clamped = Math.max(0, Math.min(index, collections.length - 1));
      setCurrentIndex(clamped);
      setNotesDraft('');
      await fetch('/api/progress', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ index: clamped }),
        cache: 'no-store',
      });
    },
    [collections.length],
  );

  // ── Decisions ──────────────────────────────────────────────────────────────

  const handleDecision = useCallback(
    async (status: DecisionStatus) => {
      setSaving(true);
      try {
        const res = await fetch('/api/decision', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            index: currentIndex,
            status,
            notes: notesDraft.trim() || undefined,
          }),
          cache: 'no-store',
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const updatedCol: ApiCollection = await res.json();

        setCollections(prev =>
          prev.map((c, i) => (i === currentIndex ? updatedCol : c)),
        );
        setNotesDraft('');

        // Advance to next collection (or complete)
        const nextIndex = currentIndex + 1;
        if (nextIndex >= collections.length) {
          await fetch('/api/progress', { method: 'DELETE', cache: 'no-store' });
          setIsComplete(true);
        } else {
          await navigateTo(nextIndex);
        }
      } finally {
        setSaving(false);
      }
    },
    [currentIndex, notesDraft, collections.length, navigateTo],
  );

  const handleSkip = useCallback(async () => {
    const nextIndex = currentIndex + 1;
    if (nextIndex >= collections.length) {
      setIsComplete(true);
    } else {
      await navigateTo(nextIndex);
    }
  }, [currentIndex, collections.length, navigateTo]);

  // ── Sync ───────────────────────────────────────────────────────────────────

  const handleSync = useCallback(async () => {
    setSyncing(true);
    setSyncMessage('Syncing with DigitalNZ API…');
    try {
      const res = await fetch('/api/sync', { method: 'POST', cache: 'no-store' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();

      setSyncMessage(
        `+${data.added.length} added, -${data.removed.length} removed, ${data.updated} updated → #${data.progressRemappedTo + 1}`,
      );

      // Re-fetch updated collections list + new progress
      const colRes = await fetch('/api/collections', { cache: 'no-store' });
      const colData = await colRes.json();
      setCollections(colData.collections);
      setCurrentIndex(colData.currentIndex);
    } catch (err) {
      setSyncMessage(`Sync failed: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setSyncing(false);
    }
  }, []);

  // ── Render ─────────────────────────────────────────────────────────────────

  if (isComplete) {
    return (
      <div className="complete">
        <h1>Review Complete</h1>
        <p>All {collections.length} collections have been processed.</p>
        <button
          className="btn-action"
          onClick={() => {
            setIsComplete(false);
            navigateTo(0);
          }}
        >
          Start Over
        </button>
      </div>
    );
  }

  if (!currentCollection) {
    return <div className="complete"><p>No collections found in the details file.</p></div>;
  }

  return (
    <div className="reviewer">
      <ProgressNav
        currentIndex={currentIndex}
        total={collections.length}
        onPrev={() => navigateTo(currentIndex - 1)}
        onNext={() => navigateTo(currentIndex + 1)}
        onJumpTo={navigateTo}
        onSync={handleSync}
        syncMessage={syncMessage}
        syncing={syncing}
      />

      <CollectionDetails collection={currentCollection} />

      <div className="images-section">
        {imagesLoading && (
          <div className="image-loading">Loading images…</div>
        )}
        {!imagesLoading && imagesError && (
          <div className="image-error">{imagesError}</div>
        )}
        {!imagesLoading && images.length > 0 && (
          <div className="image-grid">
            {images.map((img, i) => (
              <ImageCard key={i} image={img} />
            ))}
          </div>
        )}
      </div>

      <DecisionBar
        onDecision={handleDecision}
        onMore={() => loadImages(currentCollection.name)}
        onSkip={handleSkip}
        notesDraft={notesDraft}
        onNotesChange={setNotesDraft}
        saving={saving}
        loading={imagesLoading}
      />
    </div>
  );
}
