export interface CollectionField {
  key: string;
  value: string;
  lineNumber: number;
}

export interface CollectionEntry {
  name: string;
  count: string;
  lineNumber: number;
  fields: CollectionField[];
  statusLineNumber: number;
  currentStatus: string;
  endLineNumber: number;
}

export interface ParsedFile {
  lines: string[];
  collections: CollectionEntry[];
}

export type DecisionStatus = 'yes' | 'no' | 'unsure';

export const STATUS_EMOJI: Record<DecisionStatus, string> = {
  yes: '✅',
  no: '❌',
  unsure: '⚠️',
};

export interface LambdaImageResponse {
  statusCode: number;
  id?: number;
  title?: string;
  description?: string;
  thumbnail_url?: string;
  large_thumbnail_url?: string;
  object_url?: string;
  display_collection?: string;
  landing_url?: string;
  source_url?: string;
}

export interface ApiCollection {
  index: number;
  name: string;
  count: string;
  status: string;
  fields: { key: string; value: string }[];
}

export interface MergeResult {
  added: string[];
  removed: string[];
  updated: number;
  progressRemappedTo: number;
}
