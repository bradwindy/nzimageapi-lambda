import type { ApiCollection } from '@/lib/types';

export default function CollectionDetails({ collection }: { collection: ApiCollection }) {
  const statusField = collection.fields.find(f => f.key === 'Status');
  const reviewFields = collection.fields.filter(f => f.key.startsWith('Review'));
  const otherFields = collection.fields.filter(
    f => f.key !== 'Status' && !f.key.startsWith('Review'),
  );

  return (
    <div className="collection-details">
      <h2>{collection.name}</h2>
      <div className="count">{collection.count} items</div>
      <div className="fields">
        {statusField && (
          <div className="field">
            <span className="field-key status-key">Status: </span>
            {statusField.value || '(none)'}
          </div>
        )}
        {otherFields.map((f, i) => (
          <div className="field" key={i}>
            <span className="field-key">{f.key}: </span>
            {f.value}
          </div>
        ))}
        {reviewFields.map((f, i) => (
          <div className="field review-field" key={i}>
            <span className="field-key">{f.key}: </span>
            {f.value}
          </div>
        ))}
      </div>
    </div>
  );
}
