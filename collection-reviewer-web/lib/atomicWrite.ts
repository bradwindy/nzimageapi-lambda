import fs from 'fs/promises';

// Matches Swift's String.write(toFile:atomically:encoding:) behaviour.
export async function atomicWrite(filePath: string, content: string): Promise<void> {
  const tmpPath = filePath + '.tmp';
  await fs.writeFile(tmpPath, content, 'utf-8');
  await fs.rename(tmpPath, filePath);
}
