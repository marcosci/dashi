import {useDropzone} from "react-dropzone";

interface Props {
  files: File[];
  onFiles: (files: File[]) => void;
  disabled?: boolean;
  maxBytes: number;
}

export function FileDropzone({files, onFiles, disabled, maxBytes}: Props) {
  const {getRootProps, getInputProps, isDragActive} = useDropzone({
    multiple: true,
    disabled,
    maxSize: maxBytes,
    onDrop: (accepted) => onFiles([...files, ...accepted]),
  });

  const removeOne = (idx: number, e: React.MouseEvent) => {
    e.stopPropagation();
    onFiles(files.filter((_, i) => i !== idx));
  };

  return (
    <div
      {...getRootProps()}
      className={[
        "rounded-lg px-6 py-8 text-center transition cursor-pointer border-2 border-dashed",
        isDragActive
          ? "border-amber bg-cream"
          : "border-line bg-cream/40 hover:border-amber-light hover:bg-cream",
        disabled ? "opacity-50 pointer-events-none" : "",
      ].join(" ")}
    >
      <input {...getInputProps()} aria-label="upload-file" />
      {files.length > 0 ? (
        <div className="space-y-2 text-left">
          <ul className="divide-y divide-line bg-paper rounded-md border border-line">
            {files.map((f, i) => (
              <li key={i} className="flex items-center justify-between px-3 py-2">
                <div className="font-mono text-sm text-ink truncate">{f.name}</div>
                <div className="flex items-center gap-3 shrink-0">
                  <span className="text-xs text-ink-soft font-mono">
                    {(f.size / (1024 * 1024)).toFixed(2)} MiB
                  </span>
                  <button
                    type="button"
                    className="text-xs text-ink-soft hover:text-seal"
                    onClick={(e) => removeOne(i, e)}
                  >
                    remove
                  </button>
                </div>
              </li>
            ))}
          </ul>
          <div className="text-xs text-ink-soft text-center pt-1">
            {files.length} file{files.length === 1 ? "" : "s"} · click or drop more to add
          </div>
        </div>
      ) : (
        <div className="space-y-2">
          <div className="text-sm text-ink">
            Drop file(s) here or <span className="text-amber-deep underline underline-offset-2">browse</span>
          </div>
          <div className="text-xs text-ink-soft">
            max {maxBytes >= 1024 * 1024 * 1024
              ? `${(maxBytes / (1024 * 1024 * 1024)).toFixed(0)} GiB`
              : `${(maxBytes / (1024 * 1024)).toFixed(0)} MiB`}{" "}
            per file · GeoTIFF, Shapefile, GPKG, KML, LAZ, COPC, GeoParquet, …
          </div>
        </div>
      )}
    </div>
  );
}
