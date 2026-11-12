import { get, post } from '@/api/client'

/**
 * The backend's document flow records metadata only (audit §5.1): upload URLs point to a placeholder host
 * and no bytes are stored. We compute the real SHA-256 in the browser so the recorded hash describes the file.
 */
export async function sha256Hex(file: Blob): Promise<string> {
  const buf = await file.arrayBuffer()
  const digest = await crypto.subtle.digest('SHA-256', buf)
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('')
}
export async function registerDocument(file: File, doc_type: string): Promise<{ document_id: string; sha256: string }> {
  const sha = await sha256Hex(file)
  const created = await post<{ document_id: string }>('/documents/upload-url', { doc_type, mime_type: file.type || 'application/octet-stream', size_bytes: file.size })
  const done = await post<{ document_id: string; sha256: string }>(`/documents/${created.document_id}/complete`, { sha256: sha })
  return { document_id: done.document_id, sha256: done.sha256 }
}
export const downloadUrl = (id: string) => get<{ download_url: string }>(`/documents/${id}/download-url`)
