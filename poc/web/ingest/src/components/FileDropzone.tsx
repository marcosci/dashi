import {useDropzone} from "react-dropzone";

interface Props {
  file: File | null;
  onFile: (file: File | null) => void;
  disabled?: boolean;
  maxBytes: number;
}

export function FileDropzone({file, onFile, disabled, maxBytes}: Props) {
  const {getRootProps, getInputProps, isDragActive} = useDropzone({
    multiple: false,
    disabled,
    maxSize: maxBytes,
    onDrop: (accepted) => onFile(accepted[0] ?? null),
  });

  return (
    <div
      {...getRootProps()}
      className={[
        "rounded-lg px-6 py-12 text-center transition cursor-pointer border-2 border-dashed",
        isDragActive
          ? "border-amber bg-cream"
          : "border-line bg-cream/40 hover:border-amber-light hover:bg-cream",
        disabled ? "opacity-50 pointer-events-none" : "",
      ].join(" ")}
    >
      <input {...getInputProps()} aria-label="upload-file" />
      {file ? (
        <div className="space-y-1">
          <div className="font-mono text-sm text-ink">{file.name}</div>
          <div className="text-xs text-ink-soft font-mono">
            {(file.size / (1024 * 1024)).toFixed(2)} MiB · {file.type || "application/octet-stream"}
          </div>
          <button
            type="button"
            className="mt-3 text-xs text-ink-soft hover:text-seal underline-offset-2 hover:underline"
            onClick={(e) => {
              e.stopPropagation();
              onFile(null);
            }}
          >
            remove
          </button>
        </div>
      ) : (
        <div className="space-y-2">
          <div className="text-sm text-ink">
            Drop a file here or <span className="text-amber-deep underline underline-offset-2">browse</span>
          </div>
          <div className="text-xs text-ink-soft">
            max {(maxBytes / (1024 * 1024)).toFixed(0)} MiB · GeoTIFF, Shapefile, GPKG, KML, LAZ, COPC, GeoParquet, …
          </div>
        </div>
      )}
    </div>
  );
}
