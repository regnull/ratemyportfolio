"use client";

import { useCallback, useRef, useState, type DragEvent } from "react";

type FileUploadProps = {
  files: File[];
  onFilesChange: (files: File[]) => void;
};

function uniqueFiles(existing: File[], incoming: FileList | File[]): File[] {
  const map = new Map<string, File>();
  const addFile = (file: File) => {
    const key = `${file.name}-${file.size}-${file.lastModified}`;
    if (!map.has(key)) {
      map.set(key, file);
    }
  };

  existing.forEach(addFile);

  if (incoming instanceof FileList) {
    Array.from(incoming).forEach(addFile);
  } else {
    incoming.forEach(addFile);
  }

  return Array.from(map.values());
}

export function FileUpload({ files, onFilesChange }: FileUploadProps) {
  const inputRef = useRef<HTMLInputElement | null>(null);
  const [isDragging, setIsDragging] = useState(false);

  const handleFileSelection = useCallback(
    (list: FileList | null) => {
      if (!list) return;
      const updated = uniqueFiles(files, list);
      onFilesChange(updated);
    },
    [files, onFilesChange],
  );

  const handleDrop = useCallback(
    (event: DragEvent<HTMLDivElement>) => {
      event.preventDefault();
      setIsDragging(false);
      handleFileSelection(event.dataTransfer.files);
    },
    [handleFileSelection],
  );

  const removeFile = useCallback(
    (index: number) => {
      const clone = [...files];
      clone.splice(index, 1);
      onFilesChange(clone);
    },
    [files, onFilesChange],
  );

  return (
    <div className="space-y-4">
      <label className="block text-sm font-medium text-white/80">
        Portfolio documents
      </label>
      <div
        className={`relative flex flex-col items-center justify-center rounded-2xl border-2 border-dashed px-6 py-12 text-center transition-colors ${
          isDragging
            ? "border-emerald-300/80 bg-emerald-500/10"
            : "border-white/20 bg-white/5 backdrop-blur"
        }`}
        onDragOver={(event) => {
          event.preventDefault();
          setIsDragging(true);
        }}
        onDragLeave={(event) => {
          event.preventDefault();
          setIsDragging(false);
        }}
        onDrop={handleDrop}
      >
        <div className="space-y-3">
          <p className="text-lg font-semibold text-white">
            Drag & drop your files here
          </p>
          <p className="text-sm text-white/70">
            Upload PDFs, spreadsheets, images, or text files up to 5MB each.
          </p>
        </div>
        <div className="mt-6 flex flex-wrap items-center justify-center gap-4">
          <button
            type="button"
            className="rounded-full bg-white/10 px-5 py-2 text-sm font-medium text-white transition hover:bg-white/20"
            onClick={() => inputRef.current?.click()}
          >
            Browse files
          </button>
          <p className="text-xs text-white/60">
            {files.length > 0
              ? `${files.length} file${files.length === 1 ? "" : "s"} selected`
              : "No files selected yet"}
          </p>
        </div>
        <input
          ref={inputRef}
          type="file"
          multiple
          className="hidden"
          onChange={(event) => handleFileSelection(event.target.files)}
        />
      </div>

      {files.length > 0 && (
        <ul className="space-y-3">
          {files.map((file, index) => (
            <li
              key={`${file.name}-${index}`}
              className="flex items-center justify-between rounded-xl bg-black/30 px-4 py-3 text-sm text-white/90"
            >
              <div className="flex flex-col">
                <span className="font-medium">{file.name}</span>
                <span className="text-xs text-white/60">
                  {(file.size / 1024).toFixed(1)} KB
                </span>
              </div>
              <button
                type="button"
                className="text-xs font-medium text-rose-200 transition hover:text-rose-100"
                onClick={() => removeFile(index)}
              >
                Remove
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
